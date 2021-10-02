#!/usr/bin/env python3

import os
import sys
import shutil
import os.path
import tempfile
import itertools
import subprocess
from collections import namedtuple

import golden

editor = os.getenv("EDITOR")
if not editor:
  print("Missing $EDITOR", file=sys.stderr)
  exit(1)

with tempfile.TemporaryDirectory(suffix="nixlisp-golden") as tmpdir:
  tmppath = os.path.join(tmpdir, "test.golden")

  while True:
    subprocess.run([editor, tmppath])

    if not os.path.exists(tmppath):
      print("Discarded.", file=sys.stderr)
      exit(0)

    print()
    case = golden.read_test_case(tmppath)
    result = golden.run_test_case(case)
    golden.print_test_result(result)
    print()

    while True:
      r = input("[k]eep, [e]dit, [d]iscard? > ").strip()
      if r in ["k", "keep"]:
        for i in itertools.count(1):
          fname = "{:05}.golden".format(i)
          fpath = os.path.join(golden.TESTS_DIR, fname)
          if not os.path.exists(fpath): break
        shutil.move(tmppath, fpath)
        print(f"Wrote: {fpath}", file=sys.stderr)
        exit(0)
      if r in ["e", "edit"]:
        break
      if r in ["d", "discard"]:
        print("Discarded.", file=sys.stderr)
        exit(0)
