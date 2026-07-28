# NOMADZ-0: Godot 4.7 Node Wiring Guide

Follow this strictly from top to bottom once you open the project in the Godot 4.7 Editor.

## 1. Project Settings & Inputs
1. Go to **Project -> Project Settings -> Input Map**.
2. Add these exact actions and map them to your Gamepad:
   - `move_left`, `move_right`, `move_forward`, `move_backward` (Left Stick)
   - `camera_left`, `camera_right`, `camera_up`, `camera_down` (Right Stick)
   - `jump` (Joypad Button 0 - B on Switch)
   - `dash` (Joypad Button 10 - Right Shoulder)
   - `fire_primary` (Joypad Button 2 - Y on Switch)
   - `fire_secondary` (Joypad Button 3 - X on Switch)
   - `fire_special` (Joypad Axis 5 - Right Trigger)
3. Go to the **Autoload** tab. Verify these are listed (if not, add them from `res://scripts/systems/`):
   - `Director`
   - `VultureMonitor`
   - `EchoRunRecorder`

## 2. Assemble the Player (`res://scenes/player/Player.tscn`)
1. Create a New Scene with a **CharacterBody3D** root. Name it `Player`.
2. Attach `res://scripts/core/PlayerController.gd` to it.
3. Go to the **Node** tab (next to Inspector) -> **Groups**. Add `player` to the groups.
4. Add these child nodes to `Player`:
   - **CollisionShape3D** (Set shape to Capsule)
   - **RayCast3D** (Name it `GroundRay`. Set Target Position to `y: -1.5`)
   - **Node** (Name it `CombatManager`. Attach `res://scripts/core/CombatManager.gd`)
   - **Node3D** (Name it `Pivot`)
     - Add a **Camera3D** as a child of `Pivot`.

## 3. Assemble the Enemy (`res://scenes/npcs/EnemyBase.tscn`)
*Note: Ensure the LimboAI plugin is installed from the AssetLib.*
1. Create a New Scene with a **CharacterBody3D** root. Name it `EnemyBase`.
2. Attach `res://scripts/ai/EnemyAIAdapter.gd` to it.
3. Add these child nodes:
   - **CollisionShape3D** (Set shape to Capsule)
   - **MeshInstance3D** (Set mesh to Capsule, create a New StandardMaterial3D)
   - **BTPlayer** (LimboAI Node)
4. Click `BTPlayer`, open the LimboAI tab at the bottom, draw the tree (Condition: Target exists -> Action: MoveTo), and save it. Assign the saved tree to the `BTPlayer` inspector.

## 4. Assemble the World (`res://scenes/main/MainScene.tscn`)
1. Create a New Scene with a **Node3D** root. Name it `MainScene`.
2. Add these child nodes:
   - **DirectionalLight3D** (Turn on Shadows)
   - **WorldEnvironment** (Add a New Environment -> Procedural Sky)
   - **CSGBox3D** (Name it `Floor`. Make it big: 50x1x50. Turn on "Use Collision" in inspector so you don't fall through).
   - **Node3D** (Name it `EnemySpawner`. Attach `res://scripts/ai/LimboSpawner.gd`. Assign `EnemyBase.tscn` to the Inspector slot).
3. Click the Chainlink icon (Instantiate Child Scene) and drop your `Player.tscn` into the world. Move the player up so they don't clip into the floor.

## 5. Activate the Tri-Render Shader
1. In `MainScene`, add a **CanvasLayer** node. Name it `RetroFX`.
2. Add a **ColorRect** as a child. 
3. Select `ColorRect`, click **Layout -> Full Rect** at the top viewport menu.
4. In Inspector, go to **Material -> New ShaderMaterial**.
5. Drag `res://shaders/TriRender.gdshader` into the Shader property. (Tweak Pixel Size to your liking).

## 6. Run the Simulation
1. Outside of Godot, open a terminal and run your python daemon: `python scripts/python/gossip.py`
2. In Godot, press **F5** to play `MainScene.tscn`.
3. Pick up your controller. Move, flip, slash. Watch the Python terminal log the AI Director's telemetry.
