# WiggleBone Plugin for Godot Engine (4.x)

Adds jiggle physics to bones of a **Skeleton3D**. It reacts to animated or global motion as if it's connected with a rubber band to its initial position. As it reacts to acceleration instead of velocity, bones of constantly moving objects will not "lag behind" and have a more realistic behaviour.

The node inherits from **BoneAttachment3D** and can also be used as such. It overrides the bone's global pose respecting the current pose, so the bone pose still be animated.

See the [examples](https://github.com/detomon/wigglebone/tree/master/examples/wigglebone) directory for some examples.

- [Node Properties](#node-properties)
- [WiggleProperties Resource](#wiggleproperties-resource)
- [Pose Modes](#pose-modes)
- [Functions](#functions)
- [Testing in Editor](#testing-in-editor)
- [Breaking Changes from the Godot 3.x Version](#breaking-changes-from-the-godot-3x-version)

> Requires Godot 4.x. For Godot 3.x, see the [3.x branch](https://github.com/detomon/wigglebone/tree/godot-3.x).

![Editor Example](images/palm.gif)

## Node Properties

| Title | Name | Description |
|---|---|---|
| Enabled | `enabled` | Enables or disables wiggling. When disabled, the bone returns to it's current pose. |
| Properties | `properties` | Properties are stored in a separate [**WiggleProperties**](#wiggleproperties-resource) resource type. |
| Constant global force | `const_force_global` | This applies a global constant force additional to the gravity already set in [**WiggleProperties**](#wiggleproperties-resource). |
| Constant local force | `const_force_local` | This applies a constant force relative to the bone's pose. |
| Bone Name | `bone_name ` | Inherited from **BoneAttachment3D**. Selects which bone should be used. |

> Should work when `BoneAttachment3D.override_pose` is `true`. Using `BoneAttachment3D.use_external_skeleton` is not supported yet.

## WiggleProperties Resource

Properties are stored in a separate **WiggleProperties** resource type. This way, bone properties can be reused (saved) and shared between multiple bones, for example, on symetric bones.

| Title | Name | Description |
|---|---|---|
| Mode | `mode` | Two different [pose modes](#pose-modes) are supported: `Rotation` and `Dislocation`. |
| Stiffness | `stiffness` | This is the bones tendency to return to its original pose. The higher the value the stronger the pull. |
| Damping | `damping` | Reduces the bones motion. The higher the value the slower it moves in general. |
| Gravity | `gravity` | The force pulling at the tip (mode `Rotation`) or origin (mode `Dislocation`). |

### Additional Properties for Pose Mode `Rotation`

| Title | Name | Description |
|---|---|---|
| Length | `length` | This defines the bone's length. At its end is the point at which gravity and other forces are pulling. This is required as the length influences the motion. |
| Max Degrees | `max_degrees` | The maximum number of degrees the bone can rotate around it's pose. |

### Additional Properties for Pose Mode `Dislocation`

| Title | Name | Description |
|---|---|---|
| Max Distance | `max_distance` | The maximum distance the bone can move around its pose. |

## Pose Modes

Two different pose modes are supported.

### Rotation (`WiggleProperties.Mode.ROTATION`)

The bone rotates around its origin relative to the its pose. The rotation angle can be limited using **Max Degrees** (`max_degrees`). It has an upper limit of 90° due to the implementation. All values have a soft limit.

### Dislocation (`WiggleProperties.Mode.DISLOCATION`)

The bone moves around its origin relative to its pose without rotating. The distance can be limited using **Max Distance** (`max_distance`). All values have a soft limit.

## Functions

This functions can be called on the **WiggleBone** node.

### `void apply_impulse(impulse: Vector3, global := true)`

Adds a single impulse force for the next frame. If `global` is `false`, the force is relative to the bone's pose.

### `reset()`

Resets movement and resets the bone to its pose. Can be used, for example, after "teleporting" the character (moving instantaneously a long distance) to prevent overshooting.

## Testing in Editor

When a **WiggleBone** node is selected in the scene tree, a force can be applied to it by dragging its handle. The handle appears at the bone's end when `Rotation` mode is used or at the origin when `Dislocation` mode is used, respectively. Another way is to drag or rotate the **Skeleton3D** or one of its parents.

### Disabling Editor Gizmo

The editor gizmo (cone/sphere) can be hidden in the 3D viewport by disabling it in `View > Gizmos > WiggleBone`

## Breaking Changes from the Godot 3.x Version

### [**WiggleProperties**](#wiggleproperties-resource)

- `mass_center` (`Vector3`) was replaced by `length` (`float`)
- `const_force` was renamed to `const_force_global`
