#!/usr/bin/env python3

import os
import sys
import os.path
import tempfile
import itertools
import subprocess
from collections import namedtuple

from golden import TESTS_DIR, eval_expression

for i in itertools.count(1):
  fname = "{:05}.golden".format(i)
  fpath = os.path.join(TESTS_DIR, fname)
  if not os.path.exists(fpath): break

editor = os.getenv("EDITOR")
if not editor:
  print("Missing $EDITOR", file=sys.stderr)
  exit(1)

subprocess.run([editor, fpath])
