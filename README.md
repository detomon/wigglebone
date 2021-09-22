# WiggleBone Plugin for Godot Engine

Add jiggle physics to your **Skeleton**. The node is used like a **BoneAttachment** but influences the bones custom pose to react to (animated or global) motion of the **Skeleton**.

> Scaled **Skeletons** or their **MeshInstances** may not work as intended as global values are used for calculation.

## Properties

Properties are stored in a separate **WiggleProperties** resource type. This way, bone properties can be reused and shared between multiple bones.

### Mass Center

The mass center is attached to the bone end and determines how motion and gravity influences the motion. As there is no way to get the bone length automatically, this point has to be set manually. Usually its along the Y-axis of the bone.

### Gravity

The force pulling at the mass center. This can be any force but is usually used for gravity. This value has no real unit; make it bigger to pull more :)

### Stiffness

This is the bones tendency to return to its original pose. The higher the value the stronger the pull.

### Damping

Reduces the bones motion. The higher the value the slower it moves.

### Mode

Two different modes are supported:

`Rotation`

The bone rotates around its origin as if some mass is attached to its end. The rotation angle can be limited with `Max Degrees` to a certain value but has an upper limit of 90° relative to the original pose due to the implementation.

`Dislocation`

The bone moves relative to its origin as if some mass is attached to its end but without rotating. The distance can be limited to a certain value with `Max Distance`

## Bone Attachment

The **WiggleBone** node inherits its transformation from the bones pose (without wiggle) and acts the same way as a **BoneAttachment**. One of its **Spatial** children can also inherit the full transformation (including wiggle) using the `Attachment` property.

When using the `Attachment` property, be aware that the calculation runs in `_physics_process` because it's more stable. When the attachment position doesn't line up with the expected bone position when animations are used, make sure `AnimationPlayer` run with `Process Mode`: `Physics`.
