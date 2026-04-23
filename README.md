# Geo Compass QField Plugin

This plugin is a QField app plugin for Android field mapping. It shows live device orientation readings in QField and can save those readings as planar or linear structural observations in an existing vector layer.

Historical packaged Geo Compass builds are kept in the release assets.

## Important platform note

QField on Android does not run Python QGIS plugins. The current official extension mechanism is QML/JavaScript plugins for QField:

- [QField plugin overview](https://docs.qfield.org/how-to/advanced-how-tos/plugins/)
- [QField API documentation](https://api.qfield.org/)

This repository therefore uses a `main.qml` plugin instead of a Python desktop plugin.

## Sensor readout and capture model

The live display is intentionally a field sensor tool. It now prefers direct Qt phone sensors, using the rotation sensor plus compass when available and falling back to gravity-mode accelerometer plus heading when needed.

The plugin treats the phone orientation as follows:

- `linear` measurement:
  - `trend`: phone heading in degrees `0..360`
  - `plunge`: positive downward tilt in degrees `0..90`
- `planar` measurement:
  - `dip_dir`: phone heading in degrees `0..360`
  - `dip_ang`: positive downward tilt in degrees `0..90`

For planar measurements, the plugin derives dip and dip direction from the phone plane rather than simply treating the phone heading as down-dip. For linear measurements, it treats the phone top edge as the measured line direction. When the rotation sensor is unavailable, it falls back to gravity-mode accelerometer plus heading.

This assumes the phone is aligned with the feature during measurement:

- for a lineation, point the phone in the trend direction and tilt it down along the plunge
- for a plane, align the phone down dip so the phone heading represents dip direction and the tilt represents dip angle

## Field workflow

The plugin is designed for a simple in-field sequence:

1. Wait for GNSS, heading, and tilt to become valid.
2. Choose `Planar` or `Linear`.
3. Align the phone with the structure.
4. Tap `Freeze current reading` to freeze the readout.
5. Optionally enter a locality, structure `type`, geology, and comment.
6. Tap `Save` to write a point feature at the frozen GNSS position and frozen orientation.

The save button only becomes active after a reading has been frozen successfully.

## Required layers

Load this existing point shapefile or equivalent editable vector layer into the QGIS project before opening it in QField.

### Shared measurement layer

Layer name:

- `geology_measurements`

Recommended shapefile fields:

- `mode` `Text`
- `trend` `Real`
- `plunge` `Real`
- `dip_dir` `Real`
- `dip_ang` `Real`
- `kind` `Text`
- `structure` `Text`
- `type` `Text`
- `Geology` `Text`
- `azimuth` `Real`
- `tilt` `Real`
- `sensor` `Text`
- `created_utc` `Text`
  or shapefile-safe `createdutc`
- `Locality` `Text`
- `Comment` `Text`
- `notes` `Text`
- `lat_wgs84` `Real`
- `lon_wgs84` `Real`

For linear measurements, `mode` is set to `linear`, `trend` and `plunge` are populated, and the planar fields are cleared. For planar measurements, `mode` is set to `planar`, `dip_dir` and `dip_ang` are populated, and the linear fields are cleared.

The `type` field is the geological structure class within the chosen mode. Typical values are:

- planar: `Bedding`, `Cleavage`, `Joint`, `Fault`
- linear: `Lineation`, `Slickenside`, `Fold Axis`

The value entered in the form is written to both `type` and `structure` when those fields exist.

The locality and free-text note fields are written to `Locality` and `Comment` when those fields exist. The plugin also accepts lowercase `locality` and `comment` field names for compatibility.

Lithology can be entered in the form and is written to `Geology` when that field exists. The plugin also accepts lowercase `geology`.

Only the geometry and whichever of these fields exist in the target layer are written. This means the plugin can also work with slimmer schemas, as long as the layer exists and is editable.

## Shapefile note

Shapefiles work, but they are not ideal for mobile data capture because of field-name and type limits. If your workflow allows it, a GeoPackage is more robust. If you must use shapefiles, keep field names short and pre-create the files in QGIS.

## Installation

1. Zip the plugin files so that `main.qml` and `metadata.txt` are at the root of the zip.
2. Install the zip from the QField plugin manager, or place it in the QField plugins directory as an app plugin.
3. Open a project that contains an editable point layer named `geology_measurements`.

## Starter project

This folder now includes a starter QGIS project:

- `geo_compass_demo.qgs`

To use it as a QField project plugin, copy `main.qml` next to that project and rename the copy to:

- `geo_compass_demo.qml`

The starter project now includes a ready-made `geology_measurements` GeoPackage layer and map symbols for planar and linear readings.

## Current capabilities

- live GNSS coordinate display
- live heading and tilt display with phone-sensor source labels
- explicit hold or unlock workflow before saving
- planar and linear measurement modes
- FieldMove-inspired measurement-first mobile layout
- optional locality, structure type, geology, and comment capture
- defensive attribute writing so optional fields can be omitted

## Current limitations

- This has not yet been device-tested in this workspace.
- Sensor behavior depends on the Android device and how QField exposes IMU values on that device.
- The live readout is still a device-sensor solution and should not be treated as survey-grade orientation without field validation.
- The plugin currently saves measurements as point features at the current GNSS position.
- The layer name is still fixed in `main.qml` as `geology_measurements`.

## Next improvements

- support user-configurable layer names and field names
- add sensor accuracy or calibration warnings
- add optional strike or right-hand-rule outputs for planes
- make the target layer selection explicit and user-configurable
