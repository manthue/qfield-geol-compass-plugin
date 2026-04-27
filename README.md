# Geo Compass QField Plugin

This plugin is a QField app plugin for Android field mapping. It shows live device orientation readings in QField and can save those readings as planar or linear structural observations in a GeoJSON file in the current project folder.

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
6. Tap `Save` to append the frozen GNSS position and frozen orientation to `geology_measurements.geojson`.

The save button only becomes active after a reading has been frozen successfully.

## Measurement GeoJSON

The plugin writes measurements to this file in the current QField project folder:

- `geology_measurements.geojson`

Each saved measurement is a GeoJSON point feature. Feature properties include:

- `mode` `Text`
- `trend` `Real`
- `plunge` `Real`
- `dip_dir` `Real`
- `dip_ang` `Real`
- `latitude` `Real`
- `longitude` `Real`
- `elevation` `Real`
- `sensor` `Text`
- `created_utc` `Text`
- `wkt` `Text`

For linear measurements, `mode` is set to `linear`, `trend` and `plunge` are populated, and the planar fields are left blank. For planar measurements, `mode` is set to `planar`, `dip_dir` and `dip_ang` are populated, and the linear fields are left blank.

## Installation

1. Zip the plugin files so that `main.qml` and `metadata.txt` are at the root of the zip.
2. Install the zip from the QField plugin manager, or place it in the QField plugins directory as an app plugin.
3. Open any saved QField project. Measurements are appended to `geology_measurements.geojson` next to the project file.

## Starter project

This folder now includes a starter QGIS project:

- `geo_compass_demo.qgs`

To use it as a QField project plugin, copy `main.qml` next to that project and rename the copy to:

- `geo_compass_demo.qml`

The starter project includes the map symbols used for planar and linear readings. Measurements captured by the plugin are written to `geology_measurements.geojson` in the project folder.

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
- The plugin currently saves measurements as GeoJSON point features at the current GNSS position.
- The GeoJSON file name is fixed in `main.qml` as `geology_measurements.geojson`.

## Next improvements

- support user-configurable output file and field names
- add sensor accuracy or calibration warnings
- add optional strike or right-hand-rule outputs for planes
- make the target layer selection explicit and user-configurable
