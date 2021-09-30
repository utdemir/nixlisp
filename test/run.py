#!/usr/bin/env python3

import sys
import glob
import json
import os.path
import subprocess
import concurrent.futures
from collections import namedtuple

TESTS_DIR = os.path.dirname(os.path.realpath(__file__))

TestCase = namedtuple("TestCase", [ "expression", "expected_expression" ])
TestResult = namedtuple("TestResult", [ "test_case", "success", "expected", "actual" ])

def read_test_case(fp):
   with open(fp, "r") as f:
       contents = f.read()

   [expr, expected] = contents.rsplit("\n=", maxsplit=-1)
   expr = expr.strip("= \n")
   expected = expected.strip("= \n")

   return TestCase(expression=expr, expected_expression=expected)

def get_test_cases():
   files = glob.glob(os.path.join(TESTS_DIR, "golden/*.golden"))
   cases = [read_test_case(i) for i in files]
   return cases

def eval_expression(expr):
   result = subprocess.run([
     "nix-instantiate" , "--eval", "--strict", "--json", "-E",
     "{ input }: (import ./.).eval {} input",
     "--argstr", "input", expr
   ], capture_output=True)
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

cases = get_test_cases()
cases.sort(key=lambda i: len(i.expression))

with concurrent.futures.ProcessPoolExecutor() as executor:
    futures = [executor.submit(run_test_case, case) for case in cases]
    for f in futures:
       result = f.result()
       if not result.success:
           print()
           print("When running:")
           print(indent(result.test_case.expression))
           print("Expected:")
           print(indent(serialize_obj(result.expected)))
           print("But got:")
           print(indent(serialize_obj(result.actual)))
           executor.shutdown(cancel_futures=True)
           break
       print(".", end="")
       sys.stdout.flush()
    else:
       print()
       print("Tests successful.")
