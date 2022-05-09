# WiggleBone Plugin for Godot Engine

Adds jiggle physics to bones of a **Skeleton**. It reacts to animated or global motion as if it's connected with a rubber band to its initial position. As it reacts to acceleration instead of velocity, bones of constantly moving objects will not "lag behind" and have a more realistic behaviour.

The node inherits from **BoneAttachment** and can also be used as such. It uses the bone's custom pose property to apply the wiggle motion, so the bone pose can still be animated.

See the [example](https://github.com/detomon/wigglebone/tree/master/examples/wigglebone) directory for some examples.

![Editor Example](images/editor.gif)

## Node Properties

Title | Name | Description
---|---|---
Enabled | `enabled` | Enables or disables wiggling. When disabled, the bone returns to it's current pose.
Properties | `properties` | Properties are stored in a separate [**WiggleProperties**](#wiggleproperties-resource) resource type.
Constant Force | `const_force` | This applies a global constant force additional to the gravity already set in [**WiggleProperties**](#wiggleproperties-resource).
Constant Local Force | `const_force_local` | This applies a global constant force additional to the gravity already set in [**WiggleProperties**](#wiggleproperties-resource) but relative to the bone's pose.
Bone Name | `bone_name ` | Inherited from **BoneAttachment**. Selects which bone should be used.

## WiggleProperties Resource

Properties are stored in a separate **WiggleProperties** resource type. This way, bone properties can be reused (saved) and shared between multiple bones, for example, on symetric bones.

Title | Name | Description
---|---|---
Mode | `mode` | Two different [pose modes](#pose-modes) are supported: `Rotation` and `Dislocation`.
Stiffness | `stiffness` | This is the bones tendency to return to its original pose. The higher the value the stronger the pull.
Damping | `damping` | Reduces the bones motion. The higher the value the slower it moves in general.
Gravity | `gravity` | The force pulling at the tip or origin.

### Additional properties when using pose mode `Rotation`

Title | Name | Description
---|---|---
Mass Center | `mass_center` | Tihs defines the bone's center of mass and is the point at which gravity and forces are pulling at. As there is no way to get the bone length automatically, this point has to be set manually (usually along its Y-axis).
Max Degrees | `max_degrees` | The maximum number of degrees the bone can rotate around it's pose.

### Additional properties when using pose mode `Dislocation`

Title | Name | Description
---|---|---
Max Distance | `max_distance` | The maximum distance the bone can move around it pose.

## Pose Modes

Two different pose modes are supported.

### Rotation (`WiggleProperties.Mode.ROTATION`)

The bone rotates around its origin relative to the its pose. The rotation angle can be limited using **Max Degrees** (`max_degrees`). It has an upper limit of 90° due to the implementation. All values have a soft limit.

### Dislocation (`WiggleProperties.Mode.DISLOCATION`)

The bone moves around its origin relative to its pose but without rotating. The distance can be limited using **Max Distance** (`max_distance`). All values have a soft limit.

## Functions

This functions can be called on the **WiggleBone** node.

### `apply_impulse(impulse: Vector3, global: = true)`

Adds a single impulse force for the next frame. If `global` is `false`, the force is relative to the bone's pose.

### `reset()`

Resets all forces. Can be used, for example, after "teleporting" the character (moving instantaneously a long distance) to prevent overshooting.

## Testing in Editor

When a bone is selected in the scene tree, a force can be applied to it by dragging its handle. The handle appears at the bone's end when `Rotation` mode is used or at the origin when `Dislocation` mode is used, respectively. Another way is to drag or rotate the **Skeleton** or one of its parents.
