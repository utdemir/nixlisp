#!/usr/bin/env python3

import sys
import glob
import json
import os.path
import subprocess
import concurrent.futures
from collections import namedtuple

TESTS_DIR = os.path.join(os.path.dirname(os.path.realpath(__file__)), "golden")

TestCase = namedtuple("TestCase", [ "fname", "expression", "expected_expression" ])
TestResult = namedtuple("TestResult", [ "test_case", "success", "expected", "actual" ])

def read_test_case(fp):
   with open(fp, "r") as f:
       contents = f.read()

   [expr, expected] = contents.rsplit("\n=", maxsplit=-1)
   expr = expr.strip("= \n")
   expected = expected.strip("= \n")

   return TestCase(fname=os.path.basename(fp), expression=expr, expected_expression=expected)

def get_test_cases():
   files = glob.glob(os.path.join(TESTS_DIR, "*.golden"))
   cases = [read_test_case(i) for i in files]
   return cases

def eval_expression(expr):
   try:
       result = subprocess.run([
         "nix-instantiate" , "--eval", "--strict", "--json", "--show-trace", "-E",
         "{ input }: (import ./.).eval {} input",
         "--argstr", "input", expr
       ], capture_output=True, timeout=1)
   except subprocess.TimeoutExpired:
      return False, "Timed out."

   if result.returncode == 0:
      output = json.loads(result.stdout)
      return True, output
   else:
      output = result.stderr.decode().splitlines()
      return False, output

def serialize_obj(obj):
   return json.dumps(obj, sort_keys=True, indent=2)

def run_test_case(case):
   success, expected = eval_expression(case.expected_expression)
   _, actual = eval_expression(case.expression)
   return TestResult(
     test_case = case,
     success = success and serialize_obj(actual) == serialize_obj(expected),
     actual = actual,
     expected = expected
   )

def indent(s, cols=2):
   return "\n".join([" " * cols + i for i in s.splitlines()])

def print_test_result(result):
    if result.success:
        print("Success:")
        print(indent(result.test_case.fname))
        print("Expression:")
        print(indent(result.test_case.expression))
        print("Result:")
        print(indent(serialize_obj(result.actual)))
    else:
        print("Failed:")
        print(indent(result.test_case.fname))
        print("When running:")
        print(indent(result.test_case.expression))
        print("Expected:")
        print(indent(serialize_obj(result.expected)))
        print("But got:")
        print(indent(serialize_obj(result.actual)))

if __name__ == '__main__':

    if len(sys.argv) == 1:
        cases = get_test_cases()

        # We test starting from the smallest test case to get simpler errors.
        cases.sort(key=lambda i: len(i.expression))

        with concurrent.futures.ProcessPoolExecutor() as executor:
            futures = [executor.submit(run_test_case, case) for case in cases]
            while futures:
                result = futures.pop(0).result()
                if result.success:
                    print(".", end="")
                    sys.stdout.flush()
                else:
                    print("X", end="")

                    # cancel the remaining futures, noting their result if possible.
                    while futures:
                        f = futures.pop()
                        if f.cancel():
                           print("?", end="")
                        else:
                           print("." if f.result().success else "x", end="")
                        sys.stdout.flush()

                    # print the first failed test case
                    print()
                    print_test_result(result)
                    exit(1)
            else:
                print()
                print(f"{len(cases)} tests successful.")
                exit(0)

    elif len(sys.argv) == 2:
        path = sys.argv[1]
        case = read_test_case(path)
        result = run_test_case(case)
        print_test_result(result)
    else:
        print(f"Usage: {sys.argv[1]} [test name].", file=sys.stderr)
