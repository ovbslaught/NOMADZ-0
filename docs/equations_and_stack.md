# NOMADZ Math Equations + Full Stack

## Parametric Armor Equations

**Torso (Capsule + Fins):**
Torso Height: 1.2m, Radius: 0.4m (top), 0.3m (bottom)
Atomic fins: Parametric cylinders at 45° angles
r(θ,z) = 0.2 * cos(4θ) + lerp(0.1*z, 0.3, 0.5)  [θ=0..2π, z=0..0.3]

**Shoulders (Spheres + Plates):**
Shoulder spheres: Radius 0.25m, Position ±0.45x, 1.1y, 0z
Plate extrusion: Torus sections Outer R=0.3, Inner r=0.1, swept 120°

**Cowl/Helmet (Extruded Profile):**
Profile curve: Bezier from chin(0,0) → brow(0.2,1.2) → top(0,1.5)
Extrude 360° → UV map for visor glow
Visor: Toroidal lens (√(x²+y²)-R)^2 + z^2 = r^2  [R=0.15, r=0.05]

**NOMADZ Colors:**
Base: Cream hsl(60,10%,95%) → Brown hsl(25,20%,40%)
Accents: Neon Orange hsl(20,100%,60%) emission
Thrusters: Neon Green hsl(130,100%,60%)

## Full Stack (Hybrid)
1. Core Engine: Godot 4.3+ (procedural meshes, docking, hair toggle)
2. Mobile Runtime: Android via JStudio (Java/Kotlin)
3. Bridge: Godot Android export + AAR / method calls to DockingManager
4. Companion: MechDockManager.kt for touch + haptics
5. Sockets: 6 Marker3D hardpoints on SolCharacter; mechs need PilotDock

## Usage Notes
- Helmet toggle hides/shows mid-length messy brown hair
- Dock: alignment check → tween snap → PinJoint3D lock → particles
- Eject restores hair visibility based on helmet state
- All pure math / procedural. No external assets. Zero IP risk.
