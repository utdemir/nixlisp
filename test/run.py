#!/usr/bin/env python3

import glob
import json
import os.path
import subprocess
from collections import namedtuple

TESTS_DIR = os.path.dirname(os.path.realpath(__file__))

TestCase = namedtuple("TestCase", [ "expression", "expected" ])
TestResult = namedtuple("TestResult", [ "test_case", "success", "actual" ])

def read_test_case(fp):
   with open(fp, "r") as f:
       contents = f.read()

   [expr, expected] = contents.rsplit("\n=", maxsplit=-1)
   expr = expr.strip("= \n")
   expected = eval_expression(expected.strip("= \n"))

   return TestCase(expression=expr, expected=expected)

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
      return output
   else:
      output = result.stderr.decode().splitlines()
      return output

def serialize_obj(obj):
   return json.dumps(obj, sort_keys=True, indent=2)

def run_test_case(case):
   actual = eval_expression(case.expression)
   return TestResult(
     test_case = case,
     success = serialize_obj(actual) == serialize_obj(case.expected),
     actual = actual
   )

def indent(s, cols=2):
   return "\n".join([" " * cols + i for i in s.splitlines()])

for case in sorted(get_test_cases(), key=lambda i: len(i.expression)):
   result = run_test_case(case)
   if not result.success:
       print("When running:")
       print(indent(result.test_case.expression))
       print("Expected:")
       print(indent(serialize_obj(result.test_case.expected)))
       print("But got:")
       print(indent(serialize_obj(result.actual)))
       break
else:
   print("Tests successful.")
