#if TOOLS
using Godot;
using System;

/// <summary>
/// Adds the GhostMesh script as a custom node.
/// </summary>
[Tool]
public partial class GhostMeshPlugin : EditorPlugin
{
	public override void _EnterTree()
	{
		// Initialization of the plugin goes here.
		var script = GD.Load<Script>("res://addons/ghost_mesh_node/GhostMesh.cs");
		var texture = GD.Load<Texture2D>("res://addons/ghost_mesh_node/GhostMesh.svg");
		AddCustomType("GhostMesh", "Node3D", script, texture);
	}

	public override void _ExitTree()
	{
		// Clean-up of the plugin goes here.
		RemoveCustomType("GhostMesh");
	}
}
#endif
