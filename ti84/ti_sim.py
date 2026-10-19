"""Minimal TI-84 Plus CE TI-BASIC simulator for testing VECTOR.8xp.

Supports only the commands VECTOR uses, and fails loudly on anything else.
Control flow follows the real calculator's behaviour: blocks share one stack,
and Goto does not pop it, so leaked block entries show up as stack growth.
"""

import math
import re

from tivars import TIProgram

ROWS, COLS = 10, 26
MAX_MENU_ITEMS = 7


class TIError(Exception):
    pass


def fmt_num(x):
    """Format a number like the home screen in Float mode (10 significant digits)."""
    if isinstance(x, bool):
        x = int(x)
    if x == 0:
        return "0"
    s = f"{x:.10g}"
    if "e" in s:
        mant, exp = s.split("e")
        s = f"{mant}E{int(exp)}"
    return s.replace("-", "⁻")


class Sim:
    def __init__(self, source, inputs):
        self.lines = source.split("\n")
        self.inputs = list(inputs)
        self.vars = {c: 0.0 for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZθ"}
        self.stack = []
        self.max_stack = 0
        self.screen = [" " * COLS for _ in range(ROWS)]
        self.cursor = 0
        self.pauses = []
        self.menus = []
        self.mode = None
        self.labels = {}
        for i, line in enumerate(self.lines):
            m = re.fullmatch(r"Lbl ([A-Z0-9θ]{1,2})", line)
            if m:
                if m.group(1) in self.labels:
                    raise TIError(f"duplicate label {m.group(1)}")
                self.labels[m.group(1)] = i
            elif line.startswith("Lbl"):
                raise TIError(f"bad label line {i + 1}: {line!r}")

    # ---------- screen ----------
    def clr(self):
        self.screen = [" " * COLS for _ in range(ROWS)]
        self.cursor = 0

    def put(self, row, col, text):
        r, c = row - 1, col - 1
        if not (0 <= r < ROWS and 0 <= c < COLS):
            raise TIError(f"ERR:DOMAIN Output({row},{col})")
        for ch in text:
            line = self.screen[r]
            self.screen[r] = line[:c] + ch + line[c + 1:]
            c += 1
            if c == COLS:
                c, r = 0, r + 1
                if r == ROWS:
                    break

    def disp_line(self, text, right=False):
        if len(text) > COLS:
            text = text[:COLS - 1] + "…"  # the calculator truncates long Disp lines too
        if self.cursor == ROWS:
            self.screen = self.screen[1:] + [" " * COLS]
            self.cursor = ROWS - 1
        self.screen[self.cursor] = text.rjust(COLS) if right else text.ljust(COLS)
        self.cursor += 1

    def snapshot(self):
        return "\n".join("|" + l + "|" for l in self.screen)

    # ---------- expressions ----------
    def to_py(self, e):
        opens = e.count("(") - e.count(")")
        if opens < 0:
            raise TIError(f"ERR:SYNTAX unbalanced parens: {e!r}")
        e += ")" * opens
        reps = [
            ("cos⁻¹(", "_acos("), ("sin⁻¹(", "_asin("),
            ("cos(", "_cos("), ("sin(", "_sin("),
            ("√(", "_sqrt("), ("R►Pθ(", "_rpt("), ("R►Pr(", "_rpr("),
            ("iPart(", "_ipart("), ("round(", "_round("),
            ("min(", "_min("), ("max(", "_max("),
            ("²", "**2"), ("⁻", "-"), ("≠", "!="), ("≥", ">="), ("≤", "<="),
            ("θ", "_theta"),
        ]
        table = dict(reps)
        e = re.sub("|".join(re.escape(a) for a, _ in reps), lambda m: table[m.group(0)], e)
        e = re.sub(r"(?<![<>!=])=(?!=)", "==", e)
        if re.search(r"[A-Z][A-Z(]|\)[A-Z0-9(]|[0-9][A-Z(]", re.sub(r"_\w+\(", "(", e)):
            raise TIError(f"implicit multiplication not supported by sim: {e!r}")
        return e

    def ev(self, e):
        d = math.degrees
        env = {
            "_cos": lambda x: math.cos(math.radians(x)),
            "_sin": lambda x: math.sin(math.radians(x)),
            "_acos": lambda x: self._dom(-1 <= x <= 1, d(math.acos(x)) if -1 <= x <= 1 else 0),
            "_asin": lambda x: d(math.asin(x)),
            "_sqrt": lambda x: self._dom(x >= 0, math.sqrt(x) if x >= 0 else 0),
            "_rpt": lambda x, y: d(math.atan2(y, x)),
            "_rpr": lambda x, y: math.hypot(x, y),
            "_ipart": lambda x: float(math.trunc(x)),
            "_round": lambda x, n=9: round(x, int(n)),
            "_min": min, "_max": max,
            "_theta": self.vars["θ"],
        }
        env.update({k: v for k, v in self.vars.items() if k != "θ"})
        try:
            v = eval(self.to_py(e), {"__builtins__": {}}, env)
        except ZeroDivisionError:
            raise TIError(f"ERR:DIVIDE BY 0 in {e!r}")
        except SyntaxError:
            raise TIError(f"ERR:SYNTAX in {e!r}")
        return float(v)

    @staticmethod
    def _dom(ok, v):
        if not ok:
            raise TIError("ERR:DOMAIN")
        return v

    # ---------- parsing helpers ----------
    @staticmethod
    def split_args(s):
        out, depth, cur, instr = [], 0, "", False
        for ch in s:
            if ch == '"':
                instr = not instr
            if not instr and ch == "(":
                depth += 1
            if not instr and ch == ")":
                depth -= 1
            if ch == "," and depth == 0 and not instr:
                out.append(cur)
                cur = ""
            else:
                cur += ch
        out.append(cur)
        return out

    @staticmethod
    def string_lit(s):
        if not s.startswith('"'):
            return None
        body = s[1:]
        if body.endswith('"'):
            body = body[:-1]
        if '"' in body:
            raise TIError(f"bad string {s!r}")
        return body

    def skip_block(self, pc, stop_at_else):
        """From line after a false Then (or an Else), find matching Else/End."""
        depth = 0
        while pc < len(self.lines):
            line = self.lines[pc]
            if line == "Then" or line.startswith("For(") or line.startswith("Repeat ") or line.startswith("While "):
                depth += 1
            elif line == "End":
                if depth == 0:
                    return pc + 1
                depth -= 1
            elif line == "Else" and depth == 0 and stop_at_else:
                return pc + 1
            pc += 1
        raise TIError("ERR:SYNTAX missing End")

    def skip_single(self, pc):
        """Skip the one statement after a false single-line If."""
        line = self.lines[pc]
        if line == "Then":
            raise AssertionError
        if line.startswith("For(") or line.startswith("Repeat ") or line.startswith("While "):
            # a real calc would skip just this line too, which breaks nesting
            raise TIError(f"block opener after single-line If at line {pc + 1}")
        return pc + 1

    # ---------- run ----------
    def next_input(self, what):
        if not self.inputs:
            raise TIError(f"ran out of scripted input at {what}")
        return self.inputs.pop(0)

    def run(self, max_steps=200000):
        pc, steps = 0, 0
        while pc < len(self.lines):
            steps += 1
            if steps > max_steps:
                raise TIError("too many steps (infinite loop?)")
            self.max_stack = max(self.max_stack, len(self.stack))
            line = self.lines[pc]
            pc = self.step(pc, line)
            if pc is None:
                break
        return self

    def step(self, pc, line):
        L = line
        if L in ("", ):
            return pc + 1
        if L in ("Degree", "Radian"):
            self.mode = L
            return pc + 1
        if L == "Float":
            return pc + 1
        if L == "ClrHome":
            self.clr()
            return pc + 1
        if L.startswith("Pause"):
            if L.strip() != "Pause":
                raise TIError(f"unsupported Pause form {L!r}")
            self.pauses.append(self.snapshot())
            return pc + 1
        if L.startswith("Lbl "):
            return pc + 1
        if L.startswith("Goto "):
            lab = L[5:]
            if lab not in self.labels:
                raise TIError(f"ERR:LABEL {lab}")
            return self.labels[lab] + 1
        if L.startswith("Menu("):
            args = self.split_args(L[5:].rstrip(")"))
            title = self.string_lit(args[0])
            items = args[1:]
            if len(items) % 2 or not 1 <= len(items) // 2 <= MAX_MENU_ITEMS:
                raise TIError(f"ERR:ARGUMENT Menu {L!r}")
            opts = [(self.string_lit(items[i]), items[i + 1]) for i in range(0, len(items), 2)]
            for text, lab in opts:
                if text is None or lab not in self.labels:
                    raise TIError(f"bad Menu option {text!r},{lab!r}")
                if len(text) > 24:
                    raise TIError(f"menu text too long {text!r}")
            choice = self.next_input(f"Menu {title}")
            self.menus.append((title, [t for t, _ in opts], choice))
            return self.labels[opts[int(choice) - 1][1]] + 1
        if L.startswith("Input "):
            args = self.split_args(L[6:])
            prompt = self.string_lit(args[0])
            var = args[1]
            if var not in self.vars:
                raise TIError(f"bad Input var {var!r}")
            val = self.next_input(f"Input {prompt}")
            self.disp_line(f"{prompt}{val}")
            self.vars[var] = self.ev(str(val))
            return pc + 1
        if L.startswith("Disp "):
            for a in self.split_args(L[5:]):
                s = self.string_lit(a)
                if s is not None:
                    if len(s) > COLS:
                        raise TIError(f"Disp string over {COLS} chars: {s!r}")
                    self.disp_line(s)
                else:
                    self.disp_line(fmt_num(self.ev(a)), right=True)
            return pc + 1
        if L.startswith("Output("):
            args = self.split_args(L[7:].rstrip(")") if L.endswith(")") else L[7:])
            r, c = int(self.ev(args[0])), int(self.ev(args[1]))
            s = self.string_lit(args[2])
            text = s if s is not None else fmt_num(self.ev(args[2]))
            if c - 1 + len(text) > COLS:
                raise TIError(f"Output wraps past column {COLS}: row {r} {text!r}")
            self.put(r, c, text)
            return pc + 1
        if L.startswith("If "):
            cond = self.ev(L[3:])
            if pc + 1 < len(self.lines) and self.lines[pc + 1] == "Then":
                if cond:
                    self.stack.append(("If",))
                    return pc + 2
                nxt = self.skip_block(pc + 2, stop_at_else=True)
                if self.lines[nxt - 1] == "Else":
                    self.stack.append(("If",))
                return nxt
            return pc + 1 if cond else self.skip_single(pc + 1)
        if L == "Else":
            # reached the end of a true Then-part: skip to End
            if not self.stack or self.stack[-1][0] != "If":
                raise TIError(f"Else without If at line {pc + 1}")
            self.stack.pop()
            return self.skip_block(pc + 1, stop_at_else=False)
        if L.startswith("For("):
            args = self.split_args(L[4:].rstrip(")") if L.endswith(")") else L[4:])
            var = args[0]
            start, stop = self.ev(args[1]), self.ev(args[2])
            self.vars[var] = start
            if start > stop:
                return self.skip_block(pc + 1, stop_at_else=False)
            self.stack.append(("For", pc, var, stop))
            return pc + 1
        if L.startswith("Repeat "):
            self.stack.append(("Repeat", pc))
            return pc + 1
        if L == "End":
            if not self.stack:
                raise TIError(f"ERR:SYNTAX End without block at line {pc + 1}")
            top = self.stack[-1]
            if top[0] == "If":
                self.stack.pop()
                return pc + 1
            if top[0] == "For":
                _, fpc, var, stop = top
                self.vars[var] += 1
                if self.vars[var] <= stop:
                    return fpc + 1
                self.stack.pop()
                return pc + 1
            if top[0] == "Repeat":
                cond = self.ev(self.lines[top[1]][7:])
                if cond:
                    self.stack.pop()
                    return pc + 1
                return top[1] + 1
        if "→" in L:
            expr, var = L.rsplit("→", 1)
            if var not in self.vars:
                raise TIError(f"bad store target {var!r}")
            self.vars[var] = self.ev(expr)
            return pc + 1
        raise TIError(f"unsupported line {pc + 1}: {L!r}")


def load(path):
    return TIProgram.open(path).string()
