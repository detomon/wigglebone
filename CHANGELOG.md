# Changelog

## v3.1.0 - 2026-05-13

### Changed

- Allow setting multiple bones for `DMWBWigglePositionModifier3D` and `DMWBWiggleRotationModifier3D` instead of just one
	- **Note:** The previous property `bone_name` is migrated to `bones` when opening scenes which used an older addon version. After saving, these scenes will require the new version to work properly.
- Fix typos and update class documentation

## v3.0.1 - 2026-01-30

### Fixed

- Separate gizmo functions (#18)

## v3.0.0 - 2025-11-11

### Changed

- Rewrite modifier as `SkeletonModifier3D`
- Use spring simulation instead of verlet integration

### Deprecated

- `WiggleBone` and `WiggleProperties` should not be used anymore and will be removed in a later version
