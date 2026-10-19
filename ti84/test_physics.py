"""Run PHYSICS.8xp through ti_sim and check every tool.

Usage: python3 test_physics.py
"""

import math
import re
import unittest

from ti_sim import Sim, load

SRC = load("PHYSICS.8xp")

SI, US = 1, 2
KIN, PROJ, FORCE, CIRC, GRAV, UNIT, QUIT = range(1, 8)
# kinematics menu, then "YOU KNOW..." pages
CONST, AVG, KBACK = 1, 2, 3
V0AT, V0VA, V0VT, XV0A, XV0V, XV0T, MORE = range(1, 8)
XVA, XVT, XAT, VAT = 1, 2, 3, 4


def run(*inputs):
    sim = Sim(SRC, list(inputs)).run()
    assert not sim.inputs, f"unused inputs: {sim.inputs}"
    assert sim.mode == "Degree"
    assert sim.stack == [], sim.stack
    return sim


def vals(snapshot):
    out = {}
    for row in snapshot.split("\n"):
        m = re.match(r"(.+?=)\s*(\S+)\s*$", row.strip("|"))
        if m:
            try:
                out[m.group(1).strip()] = float(m.group(2).replace("⁻", "-").replace("E", "e"))
            except ValueError:
                pass  # a text line that happens to contain "="
    return out


def kin(si, menu_path, inputs, back):
    """Run one constant-acceleration case and return the result screens."""
    return run(si, KIN, CONST, *menu_path, *inputs, *back, KBACK, QUIT).pauses[1:]


class PhysicsTests(unittest.TestCase):
    def close(self, a, b, places=6):
        self.assertAlmostEqual(a, b, delta=10 ** -places * max(1, abs(b)))

    def check_kinematics(self, screen, known):
        v = vals(screen)
        x, u, vf, a, t = v["X="], v["V0="], v["V="], v["A="], v["T="]
        self.close(vf, u + a * t)
        self.close(x, u * t + a * t * t / 2)
        for k, want in known.items():
            self.close(v[k], want)
        return v

    # ----- constant acceleration: every "you know" combination -----
    def test_every_combination_is_consistent(self):
        u, a, t = 3.0, -2.0, 5.0
        vf, x = u + a * t, u * t + a * t * t / 2
        cases = [
            ([V0AT], [u, a, t], {"V0=": u, "A=": a, "T=": t}),
            ([V0VA], [u, vf, a], {"V0=": u, "V=": vf, "A=": a}),
            ([V0VT], [u, vf, t], {"V0=": u, "V=": vf, "T=": t}),
            ([XV0V], [x, u, vf], {"X=": x, "V0=": u, "V=": vf}),
            ([XV0T], [x, u, t], {"X=": x, "V0=": u, "T=": t}),
            ([MORE, XVT], [x, vf, t], {"X=": x, "V=": vf, "T=": t}),
            ([MORE, XAT], [x, a, t], {"X=": x, "A=": a, "T=": t}),
            ([MORE, VAT], [vf, a, t], {"V=": vf, "A=": a, "T=": t}),
        ]
        for path, inputs, known in cases:
            with self.subTest(path=path):
                (screen,) = kin(SI, path, inputs, [])
                v = self.check_kinematics(screen, known)
                self.close(v["T="], t)
                self.close(v["X="], x)

    def test_stone_off_cliff_single_answer(self):
        # thrown down at 2.3 m/s from 250 m: only the positive time is shown
        (screen,) = kin(SI, [XV0A], [-250, "⁻2.3", "⁻9.8"], [])
        v = self.check_kinematics(screen, {"X=": -250, "V0=": -2.3, "A=": -9.8})
        self.close(v["T="], (-2.3 + math.sqrt(2.3 ** 2 + 2 * 9.8 * 250)) / 9.8)
        self.assertNotIn("OF 2", screen)

    def test_two_answers_going_up_then_down(self):
        screens = kin(SI, [XV0A], [10, 20, "⁻9.8"], [])
        self.assertEqual(len(screens), 2)
        t1, t2 = sorted(((20 - s * math.sqrt(400 - 196)) / 9.8) for s in (1, -1))
        v1 = self.check_kinematics(screens[0], {"X=": 10})
        v2 = self.check_kinematics(screens[1], {"X=": 10})
        self.close(v1["T="], t1)
        self.close(v2["T="], t2)
        self.assertIn("(1 OF 2)", screens[0])
        self.assertIn("(2 OF 2)", screens[1])
        self.close(v1["V="], -v2["V="])

    def test_x_v_a_case(self):
        screens = kin(SI, [MORE, XVA], [-250, "⁻70", "⁻9.8"], [])
        for s in screens:
            self.check_kinematics(s, {"X=": -250, "V=": -70, "A=": -9.8})
            self.assertGreaterEqual(vals(s)["T="], 0)

    def test_zero_acceleration_quadratic_case(self):
        (screen,) = kin(SI, [XV0A], [12, 4, 0], [])
        self.check_kinematics(screen, {"T=": 3, "V=": 4})

    def test_divide_by_zero_message(self):
        sim = run(SI, KIN, CONST, V0VA, 1, 2, 0, QUIT)
        self.assertIn("CANNOT SOLVE", sim.pauses[-1])

    def test_never_reaches_height(self):
        sim = run(SI, KIN, CONST, XV0A, 100, 10, "⁻9.8", QUIT)
        self.assertIn("NO REAL ANSWER", sim.pauses[-1])

    # ----- average speed -----
    def test_average_speed_equal_distances(self):
        sim = run(SI, KIN, AVG, 1, 2, 60, 50, 40, 50, KBACK, QUIT)
        self.close(vals(sim.pauses[-1])["AVG SPD="], 48)

    def test_average_speed_equal_times(self):
        sim = run(SI, KIN, AVG, 2, 0, 2, 60, 1, 40, 1, KBACK, QUIT)
        self.close(vals(sim.pauses[-1])["AVG SPD="], 50)

    # ----- projectiles -----
    def proj(self, si, choice, *inputs):
        return vals(run(si, PROJ, choice, *inputs, 4, QUIT).pauses[-1])

    def test_full_flight_level(self):
        v = self.proj(SI, 1, 25, 40, 0)
        vy = 25 * math.sin(math.radians(40))
        vx = 25 * math.cos(math.radians(40))
        t = 2 * vy / 9.8
        self.close(v["AIR TIME="], t)
        self.close(v["RANGE="], vx * t)
        self.close(v["MAX HT="], vy ** 2 / 19.6)
        self.close(v["SPD END="], 25)
        self.close(v["ANG END="], -40)

    def test_full_flight_off_a_ledge_us_units(self):
        v = self.proj(US, 1, 20 * 5280 / 3600, 0, "⁻70")
        t = math.sqrt(2 * 70 / 32.2)
        self.close(v["AIR TIME="], t)
        self.close(v["RANGE="], 20 * 5280 / 3600 * t)
        self.close(v["MAX HT="], 0)

    def test_at_given_x(self):
        sim = run(SI, PROJ, 2, 25, 40, 22, 4, QUIT)
        v = vals(sim.pauses[-1])
        vx, vy0 = 25 * math.cos(math.radians(40)), 25 * math.sin(math.radians(40))
        t = 22 / vx
        self.close(v["TIME="], t)
        self.close(v["HEIGHT="], vy0 * t - 4.9 * t * t)
        self.close(v["VY="], vy0 - 9.8 * t)
        self.assertIn("STILL RISING" if vy0 - 9.8 * t > 0 else "FALLING", sim.pauses[-1])

    def test_speed_for_range_us(self):
        v = self.proj(US, 3, 25, 20)
        v0 = math.sqrt(25 * 32.2 / math.sin(math.radians(40)))
        self.close(v["V0="], v0)
        self.close(v["VX="], v0 * math.cos(math.radians(20)))

    # ----- forces -----
    def force(self, choice, *inputs):
        sim = run(SI, FORCE, choice, *inputs, 5, QUIT)
        return sim.pauses[-1], vals(sim.pauses[-1])

    def test_stopping_force(self):
        _, v = self.force(1, 100, 27, 1)
        self.close(v["DECEL="], 364.5)
        self.close(v["FORCE="], 36450)
        self.close(v["IN G="], 364.5 / 9.8)
        self.close(v["STOP T="], 2 / 27)

    def test_incline_stays(self):
        s, v = self.force(2, 10, 20, 0.5, 0.3)
        self.assertIn("STAYS PUT", s)
        self.close(v["FRICTION="], 98 * math.sin(math.radians(20)))

    def test_incline_slides(self):
        s, v = self.force(2, 10, 40, 0.5, 0.3)
        self.assertIn("SLIDES", s)
        c, sn = math.cos(math.radians(40)), math.sin(math.radians(40))
        self.close(v["NORMAL="], 98 * c)
        self.close(v["ACCEL="], 9.8 * (sn - 0.3 * c))

    def test_atwood(self):
        _, v = self.force(3, 2, 3)
        self.close(v["ACCEL="], 9.8 / 5)
        self.close(v["TENSION="], 2 * 2 * 3 * 9.8 / 5)

    def test_table_hanging(self):
        s, v = self.force(4, 10, 2, 0.4, 0.3)
        self.assertIn("STAYS PUT", s)
        self.close(v["TENSION="], 19.6)
        s, v = self.force(4, 10, 5, 0.4, 0.3)
        a = 9.8 * (5 - 3) / 15
        self.close(v["ACCEL="], a)
        self.close(v["TENSION="], 5 * (9.8 - a))

    # ----- circular motion -----
    def test_uniform_circle_all_inputs(self):
        r, m, spd = 4, 2, 6
        period = 2 * math.pi * r / spd
        for know, given in [(1, spd), (2, period), (3, 60 / period)]:
            with self.subTest(know=know):
                v = vals(run(SI, CIRC, 1, know, r, m, given, 4, QUIT).pauses[-1])
                self.close(v["SPEED="], spd)
                self.close(v["PERIOD="], period)
                self.close(v["CENT ACC="], 9)
                self.close(v["CENT F="], 18)

    def test_conical_pendulum(self):
        v = vals(run(SI, CIRC, 2, 5, 30, 60, 4, QUIT).pauses[-1])
        r = 5 * math.sin(math.radians(30))
        spd = math.sqrt(9.8 * r * math.tan(math.radians(30)))
        self.close(v["RADIUS="], r)
        self.close(v["SPEED="], spd)
        self.close(v["PERIOD="], 2 * math.pi * r / spd)
        self.close(v["TENSION="], 588 / math.cos(math.radians(30)))

    def test_loop(self):
        sim = run(SI, CIRC, 3, 2, 4, QUIT)
        snap = sim.pauses[-1]
        rows = [vals(line) for line in snap.split("\n")]
        tops = [r["V TOP="] for r in rows if "V TOP=" in r]
        hts = [r["START HT="] for r in rows if "START HT=" in r]
        self.close(tops[0], math.sqrt(19.6))
        self.close(tops[1], math.sqrt(39.2))
        self.assertEqual(hts, [5, 6])
        self.close(vals(snap)["V BOTTOM="], math.sqrt(6 * 9.8 * 2))

    # ----- gravity -----
    def test_earth_surface_g(self):
        v = vals(run(SI, GRAV, 1, "5.97ᴇ24", "6.371ᴇ6", 4, QUIT).pauses[-1])
        self.close(v["g="], 6.674e-11 * 5.97e24 / 6.371e6 ** 2)

    def test_mars_radius_and_orbit(self):
        v = vals(run(SI, GRAV, 2, "6.4ᴇ23", ".38*9.8", 4, QUIT).pauses[-1])
        r = math.sqrt(6.674e-11 * 6.4e23 / (0.38 * 9.8))
        self.close(v["R (M)="], r)
        v = vals(run(SI, GRAV, 3, "6.4ᴇ23", r, r, 4, QUIT).pauses[-1])
        spd = math.sqrt(6.674e-11 * 6.4e23 / (2 * r))
        self.close(v["SPEED="], spd, places=5)
        self.close(v["PERIOD S="], 2 * math.pi * 2 * r / spd, places=5)
        self.close(v["PERIOD H="], 2 * math.pi * 2 * r / spd / 3600, places=5)

    # ----- units -----
    def test_unit_conversions(self):
        for choice, value, want in [(1, 20, 8.9408), (2, 10, 22.36936292), (3, 25, 7.62),
                                    (4, 1, 3.280839895), (5, 100, 160.9344), (6, 100, 62.13711922)]:
            with self.subTest(choice=choice):
                snap = run(SI, UNIT, choice, value, 7, QUIT).pauses[-1]
                shown = float(snap.split("\n")[2].strip("| "))
                self.close(shown, want, places=8)

    # ----- whole session -----
    def test_long_session_does_not_leak_stack(self):
        inputs = [SI]
        for _ in range(20):
            inputs += [KIN, CONST, XV0A, 10, 20, "⁻9.8", CONST, V0AT, 1, 2, 3, AVG, 1, 2, 1, 1, 2, 2, KBACK]
            inputs += [PROJ, 1, 10, 45, 0, 2, 10, 45, 5, 3, 10, 45, 4]
            inputs += [FORCE, 1, 1, 1, 1, 2, 1, 10, 1, 1, 3, 1, 2, 4, 1, 1, 1, 1, 5]
            inputs += [CIRC, 1, 1, 1, 1, 1, 2, 1, 10, 1, 3, 1, 4]
            inputs += [GRAV, 1, 1, 1, 2, 1, 1, 3, 1, 1, 1, 4, UNIT, 1, 1, 7]
            inputs += [KIN, CONST, V0VA, 1, 1, 0]  # error screen returns to main menu
        sim = run(*inputs, QUIT)
        self.assertLessEqual(sim.max_stack, 2)  # For > If-Then in AVG SPEED


if __name__ == "__main__":
    unittest.main(verbosity=2)
