# TI-84 Plus CE physics programs

Two TI-BASIC programs for intro mechanics:

- **VECTOR**: adds, subtracts, dots and crosses vectors, and splits them into components, in 2D or 3D.
- **PHYSICS**: solvers for constant acceleration, average speed, projectiles, forces, circular motion,
  gravity and orbits, plus unit conversions.

## Install

1. Connect the calculator and open **TI Connect CE**.
2. Drag `VECTOR.8xp` and/or `PHYSICS.8xp` onto the calculator.
3. On the calculator: `prgm` → pick the program → `enter`.

To type one in by hand, use the matching `.txt` file (`→` is the `sto→` key, `⁻` is the `(-)` negative key).
After editing a `.txt` file, rebuild with `pip install tivars && python3 build.py`.

`python3 test_vector.py` and `python3 test_physics.py` run the built `.8xp` files through `ti_sim.py`,
a small simulator for the TI-BASIC commands these programs use. They check every menu option against
answers worked out in Python. The simulator is a stand-in for a real calculator, not a full emulator.

At any prompt you can type an expression instead of a number, like `.38*9.8` or `20*5280/3600`.
For scientific notation, use the `EE` key (`2nd` `,`), so 6.4×10²³ is `6.4ᴇ23`.

# VECTOR

## Menu

| Option | What it does |
|---|---|
| ADD VECTORS | Adds 2 or more vectors and shows the resultant |
| SUBTRACT A-B | Works out vector A minus vector B |
| SPLIT TO X,Y,Z | Turns a magnitude and angle(s) into components |
| X,Y,Z TO MAG/DIR | Turns components into a magnitude and direction |
| DOT PRODUCT | Works out A·B and the angle between A and B |
| CROSS PRODUCT | Works out A×B (always 3D, so enter z=0 for flat vectors), with its magnitude and direction |

After you pick an option, choose **2D** or **3D** (cross product skips this step). For add, subtract, dot and cross, also choose
whether you'll enter each vector as **magnitude + angle(s)** or as **components**.

## Angle conventions (degrees)

- **2D angle:** measured counterclockwise from the +x axis. So 90 points along +y and 180 along −x.
- **3D θ:** the angle in the xy-plane, counterclockwise from +x (the same as the 2D angle).
- **3D Φ:** the angle down from the +z axis. So 0 points straight up +z and 90 lies flat in the xy-plane.

  x = M·sin Φ·cos θ, y = M·sin Φ·sin θ, z = M·cos Φ

3D results also list **ANG +X** and **ANG +Y**, the angles between the vector and the
+x and +y axes. The angle to +z is Φ.

Compass bearings (like N30°E) need converting first. The angle from +x (east) is `90 − bearing`.

## Example

Add (3, 4, 0) and (1, 1, 1) in 3D using components. The result should be X=4, Y=5, Z=1,
MAG≈6.4807, θ≈51.34, Φ≈81.12.

Dot product of (1, 2, 3) and (4, ⁻5, 6) gives A·B = 12 and an angle of ≈ 68.56°.
Their cross product is (27, 6, ⁻13).

## Notes

- The program switches the calculator to **Degree** mode and overwrites the real
  variables A, B, D, E, F, G, H, K, M, N, O, P, S, T, U, V, W, X, Y, Z.
- Results are rounded to 8 decimal places, so tiny errors like 1E-13 show as 0.
- A zero vector has no direction, so its angles are shown as 0.

# PHYSICS

When it starts, pick **SI (g = 9.8 m/s²)** or **US (g = 32.2 ft/s²)**. Every tool except gravity/orbits
uses that g, so keep your units consistent with it. Gravity/orbits always uses SI (kg, m, s).

## Kinematics

- **Constant accel:** pick the three of X, V0, V, A, T that you know, and it finds the other two.
  Use signs for direction: pick a positive direction and keep to it, so a falling object has A = ⁻g.
  When there are two valid times (like a ball passing the same height going up and coming down),
  it shows both, marked "1 OF 2" and "2 OF 2".
- **Avg speed (legs):** total distance ÷ total time for a trip made of several legs. Give each leg as
  distance + speed or as time + speed. Average *velocity* uses net displacement instead, so a round trip
  has an average velocity of 0.

## Projectiles

Angles are in degrees above horizontal.

- **Full flight:** launch speed, angle and landing height relative to the launch point (⁻70 means it lands
  70 below). Shows vx, starting vy, air time, range, max height above launch, and the landing velocity.
  An object's shadow on the ground moves at vx.
- **At a given x:** where the object is when it has moved a horizontal distance x (e.g. reaching a wall):
  time, height, vx, vy, speed, and whether it's still rising or past the top.
- **Speed for a range:** the launch speed needed to land a given distance away on level ground.

## Forces

- **Stopping force:** mass, speed and stopping distance give the deceleration, force, g's and stopping time.
- **Block on incline:** normal force, the downhill part of gravity, and maximum static friction. Says
  whether the block stays put; if it slides, shows kinetic friction and acceleration.
- **Atwood (2 hanging):** two masses over one pulley: acceleration and tension.
- **Table + hanging:** M1 on a table with friction, pulled by M2 hanging off the edge.

## Circular motion

- **Uniform circle:** radius, mass and one of speed / period / RPM. Shows all three, plus ω,
  centripetal acceleration (also in g's) and centripetal force.
- **Conical pendulum:** rope length and angle from vertical. Shows the circle's radius, speed, period and
  tension, and the relation v = √(g L sinθ tanθ).
- **Loop-the-loop:** for a frictionless track and a start from rest: the speed at the top and the starting
  height to just stay on the track (N = 0), and to feel your full weight at the top (N = mg).

## Gravity / orbits (SI)

- **g from mass + radius:** surface gravity, also as a multiple of Earth's.
- **Radius from mass + g:** planet radius from its mass and surface gravity.
- **Circular orbit:** planet mass, planet radius and altitude give orbital speed and period.

## Unit convert

mph ↔ m/s, ft ↔ m, mi ↔ km.

## Notes

- PHYSICS switches the calculator to Degree mode and overwrites real variables A to Z.
- Problems that ask you to derive a formula, explain, or estimate still need working out on paper.
  Use these tools to check your numbers.
- Check whether calculator programs are allowed on your exams before relying on them there.
