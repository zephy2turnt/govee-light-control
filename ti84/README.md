# VECTOR: vector calculator for the TI-84 Plus CE

A TI-BASIC program that adds, subtracts, dots and crosses vectors and splits them into components, in **2D or 3D**.

## Install

1. Connect the calculator and open **TI Connect CE**.
2. Drag `VECTOR.8xp` onto the calculator.
3. On the calculator: `prgm` → `VECTOR` → `enter`.

To type it in by hand, use `VECTOR.txt` (`→` is the `sto→` key, `⁻` is the `(-)` negative key).
After editing `VECTOR.txt`, rebuild with `pip install tivars && python3 build.py`.

`python3 test_vector.py` runs the built `.8xp` through `ti_sim.py`, a small simulator for the TI-BASIC
commands this program uses, and checks every menu option against answers worked out in Python.
It's a stand-in for a real calculator, not a full emulator.

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
