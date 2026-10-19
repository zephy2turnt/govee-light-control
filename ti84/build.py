"""Tokenize TI-BASIC sources into .8xp files for the TI-84 Plus CE.

Usage: pip install tivars && python3 build.py [NAME ...]
Builds VECTOR and PHYSICS by default (NAME.txt -> NAME.8xp).
"""

import sys

from tivars import TIProgram
from tivars.models import TI_84PCE

for name in sys.argv[1:] or ["VECTOR", "PHYSICS"]:
    with open(f"{name}.txt", encoding="utf-8") as f:
        source = f.read()

    program = TIProgram(name=name)
    # tivars spells the π token "pi"
    program.load_string(source.replace("π", "pi"), model=TI_84PCE)
    if program.string() != source:
        sys.exit(f"{name}: tokenized program does not match {name}.txt")
    program.save(f"{name}.8xp")
    print(f"wrote {name}.8xp ({len(program.data)} bytes)")
