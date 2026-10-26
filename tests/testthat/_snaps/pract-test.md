# print() reports a failing run

    Code
      print(x)
    Output
      PractRand 0.96 test of a fixed source
      length= 64 kilobytes (2^16 bytes)
        Test Name                         p-value       Evaluation
        Test1                             1e-12         FAIL
        ...and 2 test result(s) without anomalies
      Failed at 64 kilobytes (2^16 bytes), time= 0.0 seconds

# print() reports a passing run that ended short

    Code
      print(x)
    Output
      PractRand 0.96 test of a fixed source
      length= 1 megabyte (2^20 bytes)
        no anomalies in 2 test result(s)
      length= 2 megabytes (2^21 bytes)
        Test Name                         p-value       Evaluation
        Test3                             0.01          unusual
        ...and 1 test result(s) without anomalies
        1 test result(s) without a p-value
      length= 3.000 megabytes (2^21.585 bytes)
        no anomalies in 1 test result(s)
      Ended early: the source ran out
      No failure, time= 0.0 seconds

# print() says when a run was interrupted

    Code
      print(x)
    Output
      PractRand 0.96 test of a fixed source
      length= 64 kilobytes (2^16 bytes)
        no anomalies in 1 test result(s)
      Ended early: interrupted
      No failure, time= 0.0 seconds

