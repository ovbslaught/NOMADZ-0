using Godot;
using System;
using System.Collections.Generic;

/// <summary>
/// Renders the same mesh and skeleton as the parent MeshInstance3D, but with different layers and material.
/// This is useful for rendering the same mesh on multiple viewports which can then be used in post-processing.
/// 
/// NOTE: When the game is running, UpdateInstance must be called manually after changing the parent MeshInstance3D's Mesh resource.
/// </summary>
[Tool]
public partial class GhostMesh : Node3D
{
    // How often to check if the parent mesh has been changed when running in the editor
    const float EditorParentMeshChangedCheckInterval = 0.5f;

    // Define node warning messages
    static readonly string WrongParentWarning = @"Parent node is not a MeshInstance3D node!
The GhostMesh node creates a duplicate of the parent MeshInstance3D node's mesh. Please make this a child of a MeshInstance3D node that has a mesh assigned.";
    static readonly string ParentNoMeshWarning = @"Parent MeshInstance3D node does not have a mesh assigned!
The GhostMesh node creates a duplicate of the parent MeshInstance3D node's mesh. Please assign a mesh to the parent node.";
    static readonly string NoMaterialWarning = @"No material assigned! GhostMesh will not render anything without a material.";

    // Allow material and render layers for the ghost mesh to be set in the editor
    // Setters automatically update the rendering server instance when these properties are changed
    Material _material;
    [Export]
    public Material Material
    {
        get => _material;
        set
        {
            _material = value;
            UpdateConfigurationWarnings();
            UpdateInstanceMaterial();
        }
    }
    uint _layers = 1;
    [Export(PropertyHint.Layers3DRender)] public uint Layers
    {
        get => _layers;
        set
        {
            _layers = value;
            UpdateInstanceLayers();
        }
    }

    // RID of the rendering server instance
    Rid instanceRid;

    // Used to check for changes to the parent mesh when running in the editor
    Mesh parentMesh;
    Tween parentMeshChangedCheckTween;

    public override void _EnterTree()
    {
        SetNotifyTransform(true); // Receive transform changed notifications so that the rendering server instance can be updated

        UpdateInstance(); // Update rendering server instance

        if (Engine.IsEditorHint())
        {
            // Update node warnings
            UpdateConfigurationWarnings();

            // When running in the editor, periodically check if the parent mesh has changed
            if (parentMeshChangedCheckTween != null)
                parentMeshChangedCheckTween.Kill();
            parentMeshChangedCheckTween = CreateTween();
            parentMeshChangedCheckTween.SetLoops();
            parentMeshChangedCheckTween.TweenInterval(EditorParentMeshChangedCheckInterval);
            parentMeshChangedCheckTween.TweenCallback(Callable.From(DoParentMeshChangedCheck));
        }
    }

    public override void _ExitTree()
    {
        // Clean up rendering server instance
        if (instanceRid.IsValid)
        {
            RenderingServer.FreeRid(instanceRid);
            instanceRid = default;
        }
    }

    public override void _Notification(int what)
    {
        // Receive notifications to update the transform and visibility of the rendering server instance to match the node
        if (what == NotificationTransformChanged)
        {
            UpdateInstanceTransform();
            return;
        }
        if (what == NotificationVisibilityChanged)
        {
            RenderingServer.InstanceSetVisible(instanceRid, IsVisibleInTree());
            return;
        }
    }

    public override string[] _GetConfigurationWarnings()
    {
        var warnings = new List<string>();
        if (GetParent() is MeshInstance3D parentMeshInstance3D)
        {
            if (parentMeshInstance3D.Mesh == null)
            {
                warnings.Add(ParentNoMeshWarning);
            }
        }
        else
        {
            warnings.Add(WrongParentWarning);
        }
        if (_material == null)
        {
            warnings.Add(NoMaterialWarning);
        }
        return warnings.ToArray();
    }

    /// <summary>
    /// Updates the rendering server instance.
    /// 
    /// If the parent MeshInstance3D's Mesh resource is changed while the game is running, this must be called or the GhostMesh will continue to render the old parent mesh.
    /// </summary>
    public void UpdateInstance()
    {
        // Remove any previous instance of the ghost mesh
        if (instanceRid.IsValid)
        {
            RenderingServer.FreeRid(instanceRid);
            instanceRid = default;
        }

        // Check that the parent node is a MeshInstance3D with a Mesh assigned
        if (GetParent() is MeshInstance3D parentMeshInstance3D
            && parentMeshInstance3D.Mesh != null)
        {
            // Keep reference to parent mesh to check when this changes in the editor tool
            parentMesh = parentMeshInstance3D.Mesh;

            // Create the ghost mesh in the rendering server
            instanceRid = RenderingServer.InstanceCreate();
            RenderingServer.InstanceSetScenario(instanceRid, GetWorld3D().Scenario); // Add the ghost mesh to the world
            var parentMeshRid = parentMeshInstance3D.Mesh.GetRid();
            RenderingServer.InstanceSetBase(instanceRid, parentMeshRid); // Ghost mesh uses the same mesh as the underlying MeshInstance3D
            RenderingServer.InstanceSetLayerMask(instanceRid, _layers);
            if (_material != null)
                RenderingServer.InstanceGeometrySetMaterialOverride(instanceRid, _material.GetRid());

            // If the parent mesh has skeletal animation, use this as well
            var parentSkinReference = parentMeshInstance3D.GetSkinReference();
            if (parentSkinReference != null)
            {
                var parentSkeletonRid = parentSkinReference.GetSkeleton();
                RenderingServer.InstanceAttachSkeleton(instanceRid, parentSkeletonRid);
            }

            // Update the transform of the ghost mesh in the rendering server based on this node's transform
            UpdateInstanceTransform();
        }
        else
        {
            parentMesh = null;
        }
    }

    void UpdateInstanceLayers()
    {
        if (instanceRid.IsValid)
        {
            RenderingServer.InstanceSetLayerMask(instanceRid, _layers);
        }
    }

    void UpdateInstanceMaterial()
    {
        if (instanceRid.IsValid)
        {
            Rid materialRid = _material != null ? _material.GetRid() : default;
            RenderingServer.InstanceGeometrySetMaterialOverride(instanceRid, materialRid);
        }
    }

    void UpdateInstanceTransform()
    {
        if (instanceRid.IsValid)
        {
            RenderingServer.InstanceSetTransform(instanceRid, GlobalTransform);
        }
    }

    /// <summary>
    /// Only runs in the editor. Use UpdateInstance to update while the game is running.
    /// </summary>
    void DoParentMeshChangedCheck()
    {
        if (GetParent() is MeshInstance3D parentMeshInstance3D
            && !ReferenceEquals(parentMesh, parentMeshInstance3D.Mesh))
        {
            GD.Print("Ghost Mesh - parent mesh changed");
            UpdateConfigurationWarnings();
            UpdateInstance();
        }
    }
}
