"""Run VECTOR.8xp through ti_sim and check every menu option.

Usage: python3 test_vector.py
"""

import math
import re
import unittest

from ti_sim import Sim, load

SRC = load("VECTOR.8xp")

# Menu choices
ADD, SUB, SPLIT, TOMAG, DOT, CROSS, QUIT = range(1, 8)
D2, D3 = 1, 2
POLAR, COMP = 1, 2


def run(*inputs):
    sim = Sim(SRC, list(inputs) + [QUIT]).run()
    assert not sim.inputs, f"unused inputs: {sim.inputs}"
    assert sim.mode == "Degree"
    return sim


def screen_values(snapshot):
    """Turn a result screen into {label: number}."""
    vals = {}
    for row in snapshot.split("\n"):
        row = row.strip("|")
        m = re.match(r"(.{1,9}?=)\s*(\S+)\s*$", row)
        if m:
            vals[m.group(1).strip()] = float(m.group(2).replace("⁻", "-").replace("E", "e"))
    return vals


def sph(m, t, p):
    t, p = math.radians(t), math.radians(p)
    return (m * math.sin(p) * math.cos(t), m * math.sin(p) * math.sin(t), m * math.cos(p))


def mag_dir(x, y, z=0.0):
    m = math.sqrt(x * x + y * y + z * z)
    t = math.degrees(math.atan2(y, x)) % 360 if (x or y) else 0
    p = math.degrees(math.acos(z / m)) if m else 0
    a = math.degrees(math.acos(x / m)) if m else 0
    b = math.degrees(math.acos(y / m)) if m else 0
    return m, t, p, a, b


class VectorTests(unittest.TestCase):
    def check(self, vals, expected):
        for k, v in expected.items():
            self.assertIn(k, vals, f"{k} missing from screen {vals}")
            self.assertAlmostEqual(vals[k], v, places=6, msg=k)

    def check_2d(self, sim, x, y):
        m, t, *_ = mag_dir(x, y)
        self.check(screen_values(sim.pauses[-1]), {"X=": x, "Y=": y, "MAG=": m, "ANGLE=": t})

    def check_3d(self, sim, x, y, z):
        m, t, p, a, b = mag_dir(x, y, z)
        self.check(screen_values(sim.pauses[-1]),
                   {"X=": x, "Y=": y, "Z=": z, "MAG=": m, "θ=": t, "Φ=": p, "ANG +X=": a, "ANG +Y=": b})

    # ----- add / subtract -----
    def test_add_2d_polar(self):
        sim = run(ADD, D2, 2, POLAR, 10, 30, 5, 120)
        x = 10 * math.cos(math.radians(30)) + 5 * math.cos(math.radians(120))
        y = 10 * math.sin(math.radians(30)) + 5 * math.sin(math.radians(120))
        self.check_2d(sim, x, y)
        self.assertIn("RESULTANT (SUM)", sim.pauses[-1])

    def test_add_three_2d_components(self):
        sim = run(ADD, D2, 3, COMP, 1, 2, "⁻4", 5, 0.5, "⁻10")
        self.check_2d(sim, -2.5, -3)

    def test_add_rejects_fewer_than_two(self):
        sim = run(ADD, D2, 1, 0, 3, COMP, 1, 1, 2, 2, 3, 3)
        self.check_2d(sim, 6, 6)

    def test_add_3d_components(self):
        sim = run(ADD, D3, 2, COMP, 3, 4, 0, 1, 1, 1)
        self.check_3d(sim, 4, 5, 1)

    def test_add_3d_polar(self):
        sim = run(ADD, D3, 2, POLAR, 10, 30, 60, 4, 200, 135)
        a, b = sph(10, 30, 60), sph(4, 200, 135)
        self.check_3d(sim, *(round(i + j, 8) for i, j in zip(a, b)))

    def test_subtract_2d(self):
        sim = run(SUB, D2, COMP, 5, 5, 2, 7)
        self.check_2d(sim, 3, -2)
        self.assertIn("RESULT A-B", sim.pauses[-1])

    def test_subtract_3d_polar(self):
        sim = run(SUB, D3, POLAR, 6, 45, 90, 6, 45, 90)
        self.check_3d(sim, 0, 0, 0)  # A-A is the zero vector

    # ----- split / combine -----
    def test_split_2d(self):
        sim = run(SPLIT, D2, 20, 210)
        self.check_2d(sim, round(20 * math.cos(math.radians(210)), 8), -10)

    def test_split_2d_exact_axis(self):
        sim = run(SPLIT, D2, 7, 90)
        self.check(screen_values(sim.pauses[-1]), {"X=": 0, "Y=": 7})  # no 1E-13 noise

    def test_split_3d(self):
        sim = run(SPLIT, D3, 10, 30, 60)
        self.check_3d(sim, *(round(c, 8) for c in sph(10, 30, 60)))

    def test_to_mag_2d_negative_angle(self):
        sim = run(TOMAG, D2, 3, "⁻4")
        self.check_2d(sim, 3, -4)  # angle shown as 306.87, not -53.13
        self.assertAlmostEqual(screen_values(sim.pauses[-1])["ANGLE="], 306.8698976, places=6)

    def test_to_mag_3d(self):
        sim = run(TOMAG, D3, 1, 1, 1)
        self.check_3d(sim, 1, 1, 1)

    def test_to_mag_3d_straight_down(self):
        sim = run(TOMAG, D3, 0, 0, "⁻5")
        self.check_3d(sim, 0, 0, -5)

    # ----- dot / cross -----
    def test_dot_3d(self):
        sim = run(DOT, D3, COMP, 1, 2, 3, 4, "⁻5", 6)
        snap = sim.pauses[-1]
        self.assertAlmostEqual(screen_values(snap)["A DOT B="], 12)
        angle = float(snap.split("\n")[3].strip("| "))
        self.assertAlmostEqual(angle, 68.56244697, places=6)

    def test_dot_2d_perpendicular_polar(self):
        sim = run(DOT, D2, POLAR, 3, 0, 4, 90)
        snap = sim.pauses[-1]
        self.assertAlmostEqual(screen_values(snap)["A DOT B="], 0, places=8)
        self.assertAlmostEqual(float(snap.split("\n")[3].strip("| ")), 90, places=6)

    def test_dot_with_zero_vector(self):
        sim = run(DOT, D2, COMP, 0, 0, 1, 1)
        self.assertAlmostEqual(screen_values(sim.pauses[-1])["A DOT B="], 0)

    def test_cross(self):
        sim = run(CROSS, COMP, 1, 2, 3, 4, "⁻5", 6)
        self.check_3d(sim, 27, 6, -13)
        self.assertIn("CROSS PRODUCT A X B", sim.pauses[-1])

    def test_cross_unit_vectors(self):
        sim = run(CROSS, COMP, 1, 0, 0, 0, 1, 0)
        self.check_3d(sim, 0, 0, 1)

    def test_cross_polar(self):
        sim = run(CROSS, POLAR, 2, 0, 90, 3, 90, 90)  # 2x̂ × 3ŷ = 6ẑ
        self.check_3d(sim, 0, 0, 6)

    def test_cross_parallel_is_zero(self):
        sim = run(CROSS, COMP, 1, 2, 3, 2, 4, 6)
        self.check_3d(sim, 0, 0, 0)

    # ----- whole session -----
    def test_long_session_does_not_leak_stack(self):
        inputs = []
        for _ in range(30):
            inputs += [ADD, D3, 2, COMP, 1, 2, 3, 4, 5, 6]
            inputs += [SUB, D2, POLAR, 1, 0, 1, 90]
            inputs += [SPLIT, D3, 1, 2, 3, TOMAG, D2, 1, 1]
            inputs += [DOT, D3, POLAR, 1, 2, 3, 4, 5, 6, CROSS, COMP, 1, 2, 3, 4, 5, 6]
        sim = run(*inputs)
        self.assertEqual(len(sim.pauses), 180)
        self.assertLessEqual(sim.max_stack, 3)  # For > If-Then > If-Then
        self.assertEqual(sim.stack, [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
