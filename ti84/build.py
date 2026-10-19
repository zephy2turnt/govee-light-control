"""Tokenize VECTOR.txt into VECTOR.8xp for the TI-84 Plus CE.

Usage: pip install tivars && python3 build.py
"""

from tivars import TIProgram
from tivars.models import TI_84PCE

with open("VECTOR.txt", encoding="utf-8") as f:
    source = f.read()

program = TIProgram(name="VECTOR")
program.load_string(source, model=TI_84PCE)
program.save("VECTOR.8xp")
print(f"wrote VECTOR.8xp ({len(program.data)} bytes)")
