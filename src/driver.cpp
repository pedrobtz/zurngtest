// The test driver: PractRand's tests, the known-good generator they are
// initialised with, and the block buffer, ported from PractRand's
// tools/TestManager.h. R feeds it bytes and asks for results; the state lives
// behind an external pointer whose finalizer deletes it.
//
// R's API can longjmp, which skips C++ destructors. So no frame that calls
// an R function holds a C++ object with a non-trivial destructor: the C++
// work happens inside try blocks on state owned by the external pointer, an
// exception's message is copied into a plain char buffer, and only then is
// R called to signal it.
#include <cmath>
#include <cstring>
#include <exception>
#include <stdexcept>
#include <string>
#include <vector>

#include "PractRand.h"
#include "PractRand/RNGs/hc256.h"
#include "PractRand/test_batteries.h"
#include "PractRand/tests.h"

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

using PractRand::TestResult;
using PractRand::Uint64;
using PractRand::Tests::ListOfTests;
using PractRand::Tests::TestBlock;

namespace {

// At most this many blocks go to the tests in one call (16 MiB).
const int MAX_CHUNK_BLOCKS = 1 << 14;

class Driver {
 public:
  Driver(int battery, bool folding, int bits, Uint64 seed, int chunk_blocks);
  ~Driver();
  void feed(const unsigned char *data, std::size_t nblocks);
  void collect();

  // Filled by collect(): one entry per test result.
  std::vector<std::string> names;
  std::vector<double> p_values;
  std::vector<const char *> evaluations;

 private:
  PractRand::RNGs::Polymorphic::hc256 known_good;
  ListOfTests tests;
  std::vector<TestBlock> buffer;
  int chunk_blocks;
  int blocks_to_repeat;
  int prefix_blocks;
  int main_blocks;
};

typedef ListOfTests (*BatteryFn)();

// `chunk_blocks`, at most MAX_CHUNK_BLOCKS, is the most blocks one call to
// the tests takes, and sizes the buffer.
Driver::Driver(int battery, bool folding, int bits, Uint64 seed, int chunk_blocks)
    : known_good(seed), chunk_blocks(chunk_blocks), prefix_blocks(0), main_blocks(0) {
  BatteryFn base = battery == 2
                       ? PractRand::Tests::Batteries::get_expanded_core_tests
                       : PractRand::Tests::Batteries::get_core_tests;
  tests = folding ? PractRand::Tests::Batteries::apply_standard_foldings(
                        bits, base)
                  : base();
  blocks_to_repeat = 0;
  for (std::size_t i = 0; i < tests.tests.size(); i++) {
    tests.tests[i]->init(&known_good);
    int repeat = tests.tests[i]->get_blocks_to_repeat();
    if (repeat > blocks_to_repeat) blocks_to_repeat = repeat;
  }
  buffer.resize(chunk_blocks + blocks_to_repeat);
}

Driver::~Driver() {
  for (std::size_t i = 0; i < tests.tests.size(); i++) {
    tests.tests[i]->deinit();
    delete tests.tests[i];
  }
}

// TestManager::prep_blocks() and test(): keep the last blocks_to_repeat
// blocks in front of each new chunk, since tests may read back into them.
void Driver::feed(const unsigned char *data, std::size_t nblocks) {
  while (nblocks > 0) {
    int keep = blocks_to_repeat;
    if (keep > prefix_blocks + main_blocks) keep = prefix_blocks + main_blocks;
    if (keep > 0) {
      std::memmove(&buffer[0], &buffer[prefix_blocks + main_blocks - keep],
                   TestBlock::SIZE * keep);
    }
    prefix_blocks = keep;
    main_blocks = nblocks > std::size_t(chunk_blocks) ? chunk_blocks
                                                      : int(nblocks);
    std::memcpy(&buffer[prefix_blocks], data, TestBlock::SIZE * main_blocks);
    for (std::size_t i = 0; i < tests.tests.size(); i++) {
      tests.tests[i]->test_blocks(&buffer[prefix_blocks], main_blocks);
    }
    data += std::size_t(TestBlock::SIZE) * main_blocks;
    nblocks -= main_blocks;
  }
}

// RNG_test's evaluation of one result, from its normalised weight: the
// labels and thresholds are PractRand's, unchanged.
const char *evaluate(const TestResult &result, double weight) {
  double suspicion = std::fabs(result.get_suspicion());
  double score = (suspicion + std::log2(weight)) * (std::log(2.0) / std::log(10.0));
  if (score > 999) return "FAIL !!!!!!!!";
  if (score > 325) return "FAIL !!!!!!!";
  if (score > 165) return "FAIL !!!!!!";
  if (score > 85) return "FAIL !!!!!";
  if (score > 45) return "FAIL !!!!";
  if (score > 25) return "FAIL !!!";
  if (score > 17) return "FAIL !!";
  if (score > 12) return "FAIL !";
  if (score > 8.5) return "FAIL";
  if (score > 6.0) return "VERY SUSPICIOUS";
  if (score > 4.0) return "very suspicious";
  if (score > 3.0) return "suspicious";
  if (score > 2.0) return "mildly suspicious";
  if (score > 1.0) return "unusual";
  if (score > 0.0) return "normalish";
  return "normal";
}

void Driver::collect() {
  std::vector<TestResult> results;
  for (std::size_t i = 0; i < tests.tests.size(); i++) {
    tests.tests[i]->get_results(results);
  }
  // RNG_test exits on a result with no valid p-value or weight. PractRand
  // 0.96's expanded battery gives NaN p-values from its NS3 tests even on
  // good input, so such a result is reported with no p-value and no
  // evaluation instead, and left out of the weights the others are
  // normalised by. Every valid result is evaluated as RNG_test does.
  std::vector<bool> valid(results.size());
  double total_weight = 0;
  for (std::size_t i = 0; i < results.size(); i++) {
    double weight = results[i].get_weight();
    double p = results[i].get_pvalue();
    valid[i] = weight > 0 && !std::isinf(weight) && p >= 0 && p <= 1;
    if (valid[i]) total_weight += weight;
  }
  names.clear();
  p_values.clear();
  evaluations.clear();
  for (std::size_t i = 0; i < results.size(); i++) {
    names.push_back(results[i].name);
    if (valid[i]) {
      // Near 0 or 1 the p-value PractRand stores loses precision that its
      // suspicion keeps; RNG_test prints those p-values from the suspicion,
      // and so does this.
      double p = results[i].get_pvalue();
      if (results[i].type != TestResult::TYPE_PASSFAIL && (p < 0.01 || p > 0.99)) {
        double q = TestResult::suspicion_to_pvalue(results[i].get_suspicion());
        if (q >= 0 && q <= 1) p = q;
      }
      p_values.push_back(p);
      evaluations.push_back(
          evaluate(results[i], results[i].get_weight() / total_weight));
    } else {
      p_values.push_back(NA_REAL);
      evaluations.push_back(NULL);
    }
  }
}

const std::size_t MESSAGE_SIZE = 512;

void copy_message(char *message, const char *what) {
  std::strncpy(message, what, MESSAGE_SIZE - 1);
  message[MESSAGE_SIZE - 1] = '\0';
}

// Signals zurngtest_internal_error through the package's R helper. Called
// only from frames that hold no C++ objects.
void signal_internal_error(const char *message) {
  SEXP ns = PROTECT(R_FindNamespace(PROTECT(Rf_mkString("zurngtest"))));
  SEXP msg = PROTECT(Rf_mkString(message));
  SEXP cls = PROTECT(Rf_mkString("zurngtest_internal_error"));
  SEXP call = PROTECT(Rf_lang3(Rf_install("zurngtest_abort"), msg, cls));
  Rf_eval(call, ns);
  UNPROTECT(5);
}

void finalize_driver(SEXP ptr) {
  Driver *driver = static_cast<Driver *>(R_ExternalPtrAddr(ptr));
  if (driver) {
    delete driver;
    R_ClearExternalPtr(ptr);
  }
}

Driver *get_driver(SEXP ptr, char *message) {
  if (TYPEOF(ptr) != EXTPTRSXP || R_ExternalPtrAddr(ptr) == NULL) {
    copy_message(message, "not a live zurngtest driver");
    return NULL;
  }
  return static_cast<Driver *>(R_ExternalPtrAddr(ptr));
}

}  // namespace

extern "C" {

SEXP zrt_driver_new(SEXP battery, SEXP folding, SEXP bits, SEXP seed,
                    SEXP max_bytes) {
  char message[MESSAGE_SIZE] = "";
  int battery_index = Rf_asInteger(battery);
  int fold = Rf_asLogical(folding);
  int word_bits = Rf_asInteger(bits);
  double seed_value = Rf_asReal(seed);
  double max_blocks = Rf_asReal(max_bytes) / double(TestBlock::SIZE);
  int chunk_blocks = max_blocks >= MAX_CHUNK_BLOCKS ? MAX_CHUNK_BLOCKS
                     : max_blocks >= 1            ? int(max_blocks)
                                                  : 1;
  SEXP ptr = PROTECT(R_MakeExternalPtr(NULL, R_NilValue, R_NilValue));
  R_RegisterCFinalizerEx(ptr, finalize_driver, TRUE);
  // The constructor throws only std::bad_alloc, which no test can provoke
  // portably; catch (...) here and below is a backstop, since PractRand
  // throws only std::runtime_error (0001-no-stdio.patch).
  try {
    R_SetExternalPtrAddr(
        ptr, new Driver(battery_index, fold == 1, word_bits, Uint64(seed_value),
                        chunk_blocks));
  } catch (const std::exception &e) {
    copy_message(message, e.what());
  } catch (...) {
    copy_message(message, "unknown C++ exception");
  }
  if (message[0]) signal_internal_error(message);
  UNPROTECT(1);
  return ptr;
}

// Deletes the driver now; the finalizer then finds nothing to do.
SEXP zrt_driver_free(SEXP ptr) {
  if (TYPEOF(ptr) == EXTPTRSXP) finalize_driver(ptr);
  return R_NilValue;
}

SEXP zrt_driver_feed(SEXP ptr, SEXP data) {
  char message[MESSAGE_SIZE] = "";
  Driver *driver = get_driver(ptr, message);
  const unsigned char *bytes = NULL;
  std::size_t nbytes = 0;
  if (driver) {
    if (TYPEOF(data) == RAWSXP) {
      bytes = RAW(data);
      nbytes = XLENGTH(data);
    } else if (TYPEOF(data) == INTSXP) {
      bytes = reinterpret_cast<const unsigned char *>(INTEGER(data));
      nbytes = XLENGTH(data) * sizeof(int);
    } else {
      copy_message(message, "data must be a raw or integer vector");
    }
  }
  if (!message[0] && nbytes % TestBlock::SIZE != 0) {
    copy_message(message, "data must be whole 1024-byte blocks");
  }
  // PractRand's tests can call issue_error() while testing, on a broken
  // internal invariant or a failed allocation; no input is known to reach
  // one in 0.96, so the tests reach R's handling of this error with a
  // stand-in (test-pract-test.R).
  if (!message[0]) {
    try {
      driver->feed(bytes, nbytes / TestBlock::SIZE);
    } catch (const std::exception &e) {
      copy_message(message, e.what());
    } catch (...) {
      copy_message(message, "unknown C++ exception");
    }
  }
  if (message[0]) signal_internal_error(message);
  return R_NilValue;
}

SEXP zrt_driver_results(SEXP ptr) {
  char message[MESSAGE_SIZE] = "";
  Driver *driver = get_driver(ptr, message);
  if (driver) {
    try {
      driver->collect();
    } catch (const std::exception &e) {
      copy_message(message, e.what());
    } catch (...) {
      copy_message(message, "unknown C++ exception");
    }
  }
  if (message[0]) {
    signal_internal_error(message);  // does not return
    return R_NilValue;
  }

  R_xlen_t n = R_xlen_t(driver->names.size());
  SEXP test = PROTECT(Rf_allocVector(STRSXP, n));
  SEXP p_value = PROTECT(Rf_allocVector(REALSXP, n));
  SEXP evaluation = PROTECT(Rf_allocVector(STRSXP, n));
  for (R_xlen_t i = 0; i < n; i++) {
    SET_STRING_ELT(test, i, Rf_mkCharCE(driver->names[i].c_str(), CE_UTF8));
    REAL(p_value)[i] = driver->p_values[i];
    SET_STRING_ELT(evaluation, i,
                   driver->evaluations[i] ? Rf_mkChar(driver->evaluations[i])
                                          : NA_STRING);
  }
  SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
  SET_VECTOR_ELT(out, 0, test);
  SET_VECTOR_ELT(out, 1, p_value);
  SET_VECTOR_ELT(out, 2, evaluation);
  SEXP names = PROTECT(Rf_allocVector(STRSXP, 3));
  SET_STRING_ELT(names, 0, Rf_mkChar("test"));
  SET_STRING_ELT(names, 1, Rf_mkChar("p_value"));
  SET_STRING_ELT(names, 2, Rf_mkChar("evaluation"));
  Rf_setAttrib(out, R_NamesSymbol, names);
  UNPROTECT(5);
  return out;
}

// Reaches PractRand's error path, for the test that it arrives in R as
// zurngtest_internal_error.
SEXP zrt_issue_error_for_tests(void) {
  char message[MESSAGE_SIZE] = "";
  try {
    PractRand::issue_error("issue_error() reached from zrt_issue_error_for_tests");
  } catch (const std::exception &e) {
    copy_message(message, e.what());
  }
  if (message[0]) signal_internal_error(message);
  return R_NilValue;
}

}  // extern "C"
