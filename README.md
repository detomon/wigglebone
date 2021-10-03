# WiggleBone Plugin for Godot Engine

Add jiggle physics to your **Skeleton**. The node is used like a **BoneAttachment** but influences the bones custom pose to react to (animated or global) motion of the **Skeleton**.

> Scaled **Skeletons** or their **MeshInstances** may not work as intended as global values are used for calculation.

## Bone Properties

Properties are stored in a separate **WiggleProperties** resource type. This way, bone properties can be reused and shared between multiple bones.

### Mass Center

The mass center is attached to the bone's end and determines how motion and gravity influences the motion. As there is no way to get the bone length automatically, this point has to be set manually. Usually its along the Y-axis of the bone.

### Gravity

The force pulling at the mass center. This can be any force but is usually used for gravity.

### Stiffness

This is the bones tendency to return to its original pose. The higher the value the stronger the pull.

### Damping

Reduces the bones motion. The higher the value the slower it moves in general.

### Mode

Two different deformation modes are supported:

`Rotation`

The bone rotates around its origin. The rotation angle can be limited with `Max Degrees` to a certain value but has an upper limit of 90° relative to the original pose.

`Dislocation`

The bone moves relative to its origin but without rotating. The distance can be limited to a certain value with `Max Distance`


## Bone Attachment

The **WiggleBone** node inherits its transformation from the bone's pose (without wiggle) and acts the same way as a **BoneAttachment**. One of its **Spatial** children can also inherit the full transformation (including wiggle) using the `Attachment` property.

## Testing in Editor

A force can be applied to the bone to test the properties in the editor by dragging its handle. The handle appears at the bone's end when `Rotation` mode is used or at the root when `Dislocation` mode is used, respectively. Another way is to move or rotate the **Skeleton** or one of its parents directly.
