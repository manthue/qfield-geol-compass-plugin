import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import org.qfield
import Theme

Item {
  id: root

  property string measurementLayerName: "geology_measurements"
  property var targetMeasurementLayer: null
  property string activeMode: "planar"
  property bool measurementFrozen: false
  property bool compassVisible: false
  property real frozenHeading: NaN
  property real frozenTilt: NaN

  property string localityText: ""
  property string typeText: ""
  property string geologyText: ""
  property string noteText: ""
  property string lastModeTypeSeed: ""

  readonly property color appBg: "#f3f3f1"
  readonly property color headerBg: "#d7d7d7"
  readonly property color panelBg: "#fcfcfb"
  readonly property color textPrimary: "#212121"
  readonly property color textMuted: "#6b6b6b"
  readonly property color dialStroke: "#202020"
  readonly property color greyLine: "#cfcfcf"
  readonly property color fieldBg: "#585858"
  readonly property color saveBg: "#a9dfbc"
  readonly property color saveText: "#ffffff"
  readonly property color modeBarBg: "#1fd2e5"
  readonly property color modeTabBg: "#f2a034"
  readonly property color planarAccent: "#ff1111"
  readonly property color linearAccent: "#1eff23"
  readonly property color activeAccent: activeMode === "planar" ? planarAccent : linearAccent
  readonly property string leftValueLabel: activeMode === "planar" ? "Dip" : "Plunge"
  readonly property string rightValueLabel: activeMode === "planar" ? "Dip Dir" : "Trend"
  readonly property string modeDisplayName: activeMode === "planar" ? "Planar" : "Linear"
  readonly property string defaultStructureType: activeMode === "planar" ? "Bedding" : "Lineation"
  readonly property string typeExampleText: activeMode === "planar"
                                           ? "Bedding, Cleavage, Joint, Fault"
                                           : "Lineation, Slickenside, Fold Axis"
  readonly property var positionInfo: currentPositionInfo()
  readonly property real liveHeading: currentHeading()
  readonly property real liveTilt: currentTiltDown()
  readonly property real displayHeading: measurementFrozen ? frozenHeading : liveHeading
  readonly property real displayTilt: measurementFrozen ? frozenTilt : liveTilt

  function normalizeAzimuth(value) {
    if (isNaN(value)) {
      return NaN;
    }

    let normalized = value % 360;
    if (normalized < 0) {
      normalized += 360;
    }
    return normalized;
  }

  function clampPositiveAngle(value) {
    if (isNaN(value)) {
      return NaN;
    }

    let angle = Math.abs(value);
    if (angle > 90) {
      angle = 180 - angle;
    }
    return Math.max(0, Math.min(90, angle));
  }

  function currentPositionInfo() {
    return iface.positioning().positionInformation;
  }

  function currentHeading() {
    const info = currentPositionInfo();

    if (info.imuHeadingValid) {
      return normalizeAzimuth(info.imuHeading);
    }

    if (!isNaN(iface.positioning().orientation)) {
      return normalizeAzimuth(iface.positioning().orientation);
    }

    return NaN;
  }

  function currentTiltDown() {
    const info = currentPositionInfo();

    if (info.imuPitchValid) {
      return clampPositiveAngle(info.imuPitch);
    }

    if (info.imuRollValid) {
      return clampPositiveAngle(info.imuRoll);
    }

    if (info.imuSteeringValid) {
      return clampPositiveAngle(info.imuSteering);
    }

    return NaN;
  }

  function tiltSensorLabel() {
    const info = currentPositionInfo();

    if (info.imuPitchValid) {
      return "pitch";
    }

    if (info.imuRollValid) {
      return "roll";
    }

    if (info.imuSteeringValid) {
      return "steering";
    }

    return "none";
  }

  function formatSensorValue(valid, value) {
    if (!valid || isNaN(value)) {
      return "--";
    }

    return Math.round(value) + "\u00b0";
  }

  function sensorDebugLabel() {
    const info = currentPositionInfo();
    const orientationValue = !isNaN(iface.positioning().orientation)
      ? Math.round(normalizeAzimuth(iface.positioning().orientation)) + "\u00b0"
      : "--";

    return "imuHeading "
      + formatSensorValue(info.imuHeadingValid, info.imuHeading)
      + " | pitch "
      + formatSensorValue(info.imuPitchValid, info.imuPitch)
      + " | roll "
      + formatSensorValue(info.imuRollValid, info.imuRoll)
      + " | steering "
      + formatSensorValue(info.imuSteeringValid, info.imuSteering)
      + " | orientation "
      + orientationValue;
  }

  function freezeMeasurement() {
    const heading = liveHeading;
    const tilt = liveTilt;

    if (isNaN(heading)) {
      iface.mainWindow().displayToast("No valid compass heading available");
      return;
    }

    if (isNaN(tilt)) {
      iface.mainWindow().displayToast("No valid tilt value available from pitch, roll, or steering sensors");
      return;
    }

    frozenHeading = heading;
    frozenTilt = tilt;
    measurementFrozen = true;
    iface.mainWindow().displayToast("Measurement locked");
  }

  function clearFrozenMeasurement() {
    measurementFrozen = false;
    frozenHeading = NaN;
    frozenTilt = NaN;
  }

  function layerByName(name) {
    const matches = qgisProject.mapLayersByName(name);
    if (!matches || matches.length === 0) {
      return null;
    }
    return matches[0];
  }

  function layerGeometryTypeValue(layer) {
    if (!layer) {
      return -1;
    }

    if (layer.geometryType === undefined || layer.geometryType === null) {
      return -1;
    }

    return Number(layer.geometryType);
  }

  function isPointLayer(layer) {
    const geometryType = layerGeometryTypeValue(layer);
    return geometryType === -1 || geometryType === 0;
  }

  function missingRequiredFields(layer) {
    const requiredFields = ["mode", "trend", "plunge", "dip_dir", "dip_ang"];
    let missing = [];

    for (let i = 0; i < requiredFields.length; ++i) {
      const fieldName = requiredFields[i];
      if (!fieldExists(layer, fieldName)) {
        missing.push(fieldName);
      }
    }

    return missing;
  }

  function compatibleLayerMessage(layer, missing) {
    if (!layer) {
      return "No compatible point layer was found. Add an editable point layer with fields mode, trend, plunge, dip_dir, and dip_ang.";
    }

    if (!isPointLayer(layer)) {
      return "Layer '" + layer.name + "' is not a point layer.";
    }

    if (LayerUtils.isFeatureAdditionLocked(layer)) {
      return "Layer '" + layer.name + "' is not editable for adding features.";
    }

    if (missing.length > 0) {
      return "Layer '" + layer.name + "' is missing required fields: " + missing.join(", ");
    }

    return "";
  }

  function findCompatibleMeasurementLayer() {
    const preferredLayer = layerByName(measurementLayerName);
    if (preferredLayer) {
      const preferredMissing = missingRequiredFields(preferredLayer);
      const preferredMessage = compatibleLayerMessage(preferredLayer, preferredMissing);
      if (preferredMessage.length === 0) {
        return {
          layer: preferredLayer,
          message: ""
        };
      }
    }

    let allLayers = null;
    try {
      allLayers = ProjectUtils.mapLayers(qgisProject);
    } catch (error) {
      allLayers = null;
    }
    if (allLayers) {
      for (let key in allLayers) {
        const layer = allLayers[key];
        const missing = missingRequiredFields(layer);
        const message = compatibleLayerMessage(layer, missing);
        if (message.length === 0) {
          return {
            layer: layer,
            message: ""
          };
        }
      }
    }

    if (preferredLayer) {
      return {
        layer: null,
        message: compatibleLayerMessage(preferredLayer, missingRequiredFields(preferredLayer))
      };
    }

    return {
      layer: null,
      message: compatibleLayerMessage(null, [])
    };
  }

  function memoryLayerUri() {
    let crsAuthId = "EPSG:4326";
    try {
      if (qgisProject && qgisProject.crs && qgisProject.crs.authid) {
        crsAuthId = qgisProject.crs.authid;
      }
    } catch (error) {
      crsAuthId = "EPSG:4326";
    }

    return "Point"
      + "?crs=" + encodeURIComponent(crsAuthId)
      + "&field=mode:string(16)"
      + "&field=trend:double"
      + "&field=plunge:double"
      + "&field=dip_dir:double"
      + "&field=dip_ang:double"
      + "&field=kind:string(16)"
      + "&field=structure:string(64)"
      + "&field=type:string(64)"
      + "&field=Geology:string(80)"
      + "&field=azimuth:double"
      + "&field=tilt:double"
      + "&field=sensor:string(32)"
      + "&field=created_utc:string(40)"
      + "&field=Locality:string(120)"
      + "&field=Comment:string(255)"
      + "&field=notes:string(255)"
      + "&field=lat_wgs84:double"
      + "&field=lon_wgs84:double"
      + "&index=yes";
  }

  function createMeasurementLayer() {
    const createdLayer = LayerUtils.loadVectorLayer(
      memoryLayerUri(),
      measurementLayerName,
      "memory"
    );

    if (!createdLayer) {
      return {
        layer: null,
        message: "QField could not create a temporary measurement layer."
      };
    }

    if (!ProjectUtils.addMapLayer(qgisProject, createdLayer)) {
      return {
        layer: null,
        message: "QField created a layer but could not add it to the current project."
      };
    }

    return {
      layer: createdLayer,
      message: ""
    };
  }

  function showAlert(message) {
    noticeDialog.text = message;
    noticeDialog.open();
  }

  function showCreateLayerPrompt(message) {
    createLayerDialog.text = message;
    createLayerDialog.open();
  }

  function openCompassFromMap() {
    const result = findCompatibleMeasurementLayer();

    if (!result.layer) {
      showCreateLayerPrompt(result.message);
      return;
    }

    targetMeasurementLayer = result.layer;
    measurementLayerName = result.layer.name;
    compassVisible = true;
    seedTypeForMode();
  }

  function closeCompass() {
    compassVisible = false;
  }

  function createLayerAndOpenCompass() {
    createLayerDialog.close();

    const creation = createMeasurementLayer();
    if (!creation.layer) {
      showAlert(creation.message);
      return;
    }

    targetMeasurementLayer = creation.layer;
    measurementLayerName = creation.layer.name;
    compassVisible = true;
    seedTypeForMode();
    iface.mainWindow().displayToast("Temporary measurement layer created");
  }

  function currentGeometry() {
    const info = currentPositionInfo();

    if (!info.isValid || !info.latitudeValid || !info.longitudeValid) {
      return null;
    }

    const pointWgs84 = GeometryUtils.point(info.longitude, info.latitude);
    const pointProject = GeometryUtils.reprojectPoint(
      pointWgs84,
      CoordinateReferenceSystemUtils.wgs84Crs(),
      qgisProject.crs
    );

    return GeometryUtils.createGeometryFromPoint(pointProject);
  }

  function fieldExists(layer, fieldName) {
    if (!fieldName || !layer || !layer.fields || !layer.fields.length) {
      return false;
    }

    for (let i = 0; i < layer.fields.length; ++i) {
      const field = layer.fields[i];
      if (field && field.name === fieldName) {
        return true;
      }
    }

    return false;
  }

  function setAttributeIfPresent(feature, layer, fieldName, value) {
    if (fieldExists(layer, fieldName)) {
      feature.setAttribute(fieldName, value);
    }
  }

  function activeStructureType() {
    const trimmed = typeText.trim();
    return trimmed.length > 0 ? trimmed : defaultStructureType;
  }

  function seedTypeForMode() {
    if (typeText.trim().length > 0 && typeText !== lastModeTypeSeed) {
      return;
    }

    typeText = defaultStructureType;
    lastModeTypeSeed = defaultStructureType;
  }

  function saveMeasurement(kind) {
    const heading = measurementFrozen ? frozenHeading : liveHeading;
    const tilt = measurementFrozen ? frozenTilt : liveTilt;
    const geometry = currentGeometry();
    const info = currentPositionInfo();
    const targetLayer = targetMeasurementLayer ? targetMeasurementLayer : layerByName(measurementLayerName);

    if (!targetLayer) {
      iface.mainWindow().displayToast("Missing layer: " + measurementLayerName);
      return;
    }

    if (!geometry) {
      iface.mainWindow().displayToast("No valid GNSS position available");
      return;
    }

    if (isNaN(heading)) {
      iface.mainWindow().displayToast("No valid compass heading available");
      return;
    }

    if (isNaN(tilt)) {
      iface.mainWindow().displayToast("No valid tilt value available from pitch, roll, or steering sensors");
      return;
    }

    let feature = FeatureUtils.createFeature(targetLayer, geometry, info);

    setAttributeIfPresent(feature, targetLayer, "mode", kind);

    if (kind === "linear") {
      setAttributeIfPresent(feature, targetLayer, "trend", heading);
      setAttributeIfPresent(feature, targetLayer, "plunge", tilt);
      setAttributeIfPresent(feature, targetLayer, "dip_dir", null);
      setAttributeIfPresent(feature, targetLayer, "dip_ang", null);
    } else {
      setAttributeIfPresent(feature, targetLayer, "dip_dir", heading);
      setAttributeIfPresent(feature, targetLayer, "dip_ang", tilt);
      setAttributeIfPresent(feature, targetLayer, "trend", null);
      setAttributeIfPresent(feature, targetLayer, "plunge", null);
    }

    setAttributeIfPresent(feature, targetLayer, "kind", kind);
    setAttributeIfPresent(feature, targetLayer, "structure", activeStructureType());
    setAttributeIfPresent(feature, targetLayer, "type", activeStructureType());
    setAttributeIfPresent(feature, targetLayer, "Geology", geologyText.trim());
    setAttributeIfPresent(feature, targetLayer, "geology", geologyText.trim());
    setAttributeIfPresent(feature, targetLayer, "azimuth", heading);
    setAttributeIfPresent(feature, targetLayer, "tilt", tilt);
    setAttributeIfPresent(feature, targetLayer, "sensor", "android_internal");
    setAttributeIfPresent(feature, targetLayer, "created_utc", new Date().toISOString());
    setAttributeIfPresent(feature, targetLayer, "locality", localityText.trim());
    setAttributeIfPresent(feature, targetLayer, "Locality", localityText.trim());
    setAttributeIfPresent(feature, targetLayer, "comment", noteText.trim());
    setAttributeIfPresent(feature, targetLayer, "Comment", noteText.trim());
    setAttributeIfPresent(feature, targetLayer, "notes", noteText.trim());

    if (info.latitudeValid) {
      setAttributeIfPresent(feature, targetLayer, "lat_wgs84", info.latitude);
    }

    if (info.longitudeValid) {
      setAttributeIfPresent(feature, targetLayer, "lon_wgs84", info.longitude);
    }

    if (!LayerUtils.addFeature(targetLayer, feature)) {
      iface.mainWindow().displayToast("Failed to save " + kind + " measurement");
      return;
    }

    clearFrozenMeasurement();
    iface.mainWindow().displayToast(kind + " measurement saved");
  }

  function formattedWholeAngle(value) {
    if (isNaN(value)) {
      return "---";
    }

    let rounded = Math.round(normalizeAzimuth(value));
    if (rounded === 360) {
      rounded = 0;
    }

    if (rounded < 10) {
      return "00" + rounded;
    }
    if (rounded < 100) {
      return "0" + rounded;
    }
    return "" + rounded;
  }

  function formattedTiltInteger(value) {
    if (isNaN(value)) {
      return "--";
    }
    return "" + Math.round(value);
  }

  function coordinateLabel() {
    const info = positionInfo;

    if (!info.isValid || !info.latitudeValid || !info.longitudeValid) {
      return "Waiting for GNSS";
    }

    return info.latitude.toFixed(5) + " N, " + info.longitude.toFixed(5) + " E";
  }

  function sensorTimestampLabel() {
    return "Updated: " + Qt.formatTime(new Date(), "hh:mm");
  }

  function positionStatusLabel() {
    const info = positionInfo;
    let parts = [];

    parts.push(info.isValid ? "GNSS ready" : "GNSS unavailable");
    parts.push(isNaN(liveHeading) ? "Compass unavailable" : "Compass ready");
    parts.push(isNaN(liveTilt) ? "Tilt unavailable" : "Tilt ready (" + tiltSensorLabel() + ")");
    parts.push(measurementFrozen ? "Locked" : "Live");

    return parts.join(" | ");
  }

  function freezeButtonLabel() {
    return measurementFrozen ? "Unlock measurement" : "Lock current measurement";
  }

  QfToolButton {
    id: compassLauncher
    visible: true
    iconSource: Theme.getThemeVectorIcon("ic_explore_white_24dp")
    iconColor: Theme.toolButtonColor
    bgcolor: Theme.toolButtonBackgroundColor
    round: true
    onClicked: root.openCompassFromMap()
  }

  Dialog {
    id: noticeDialog
    parent: iface.mainWindow().contentItem
    modal: true
    visible: false
    title: "Geo Compass"

    property string text: ""

    standardButtons: Dialog.Ok

    contentItem: Label {
      text: noticeDialog.text
      wrapMode: Text.WordWrap
      width: 280
      color: root.textPrimary
    }
  }

  Dialog {
    id: createLayerDialog
    parent: iface.mainWindow().contentItem
    modal: true
    visible: false
    title: "Create measurement layer?"

    property string text: ""

    standardButtons: Dialog.Ok | Dialog.Cancel

    onAccepted: root.createLayerAndOpenCompass()

    contentItem: Label {
      text: createLayerDialog.text + "\n\nCreate a temporary point layer in this project now?"
      wrapMode: Text.WordWrap
      width: 300
      color: root.textPrimary
    }
  }

  Component.onCompleted: {
    seedTypeForMode();
    iface.addItemToPluginsToolbar(compassLauncher);
    iface.mainWindow().displayToast("Geo compass plugin ready");
  }

  Rectangle {
    parent: iface.mainWindow().contentItem
    anchors.fill: parent
    visible: compassVisible
    z: 1000
    color: appBg

    Column {
      anchors.fill: parent
      spacing: 0

      Rectangle {
        width: parent.width
        height: 76
        color: headerBg

        Row {
          anchors.fill: parent
          anchors.leftMargin: 12
          anchors.rightMargin: 12
          spacing: 12

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u2630"
            color: "#8a8a8a"
            font.pixelSize: 28
          }

          Rectangle {
            width: 46
            height: 46
            radius: 10
            anchors.verticalCenter: parent.verticalCenter
            color: panelBg
            border.color: "#8e8e8e"
            border.width: 1

            Canvas {
              anchors.fill: parent
              onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.fillStyle = "#d51d2e";
                ctx.beginPath();
                ctx.moveTo(width * 0.16, height * 0.22);
                ctx.lineTo(width * 0.52, height * 0.12);
                ctx.lineTo(width * 0.52, height * 0.88);
                ctx.lineTo(width * 0.16, height * 0.78);
                ctx.closePath();
                ctx.fill();

                ctx.strokeStyle = "#535353";
                ctx.lineWidth = 4;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(width * 0.28, height * 0.28);
                ctx.lineTo(width * 0.67, height * 0.67);
                ctx.stroke();

                ctx.beginPath();
                ctx.moveTo(width * 0.62, height * 0.18);
                ctx.lineTo(width * 0.77, height * 0.34);
                ctx.stroke();
              }
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: -2

            Text {
              text: "Geo Compass"
              color: textPrimary
              font.pixelSize: 22
            }

            Text {
              text: activeMode === "planar" ? "Planar structures" : "Linear structures"
              color: textMuted
              font.pixelSize: 14
            }
          }

          Item {
            width: Math.max(0, parent.width - 252)
            height: 1
          }

          Rectangle {
            width: 38
            height: 38
            radius: 19
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"

            Canvas {
              anchors.fill: parent
              onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = "#8a8a8a";
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, 11, 0, Math.PI * 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, 4, 0, Math.PI * 2);
                ctx.stroke();
                ctx.beginPath();
                ctx.moveTo(width / 2, 2);
                ctx.lineTo(width / 2, 10);
                ctx.moveTo(width / 2, height - 2);
                ctx.lineTo(width / 2, height - 10);
                ctx.moveTo(2, height / 2);
                ctx.lineTo(10, height / 2);
                ctx.moveTo(width - 2, height / 2);
                ctx.lineTo(width - 10, height / 2);
                ctx.stroke();
              }
            }
          }

          Rectangle {
            width: 38
            height: 38
            radius: 19
            anchors.verticalCenter: parent.verticalCenter
            color: "#ececeb"
            border.color: "#8e8e8e"
            border.width: 1

            Text {
              anchors.centerIn: parent
              text: "\u2715"
              color: textPrimary
              font.pixelSize: 18
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.closeCompass()
            }
          }
        }
      }

      Flickable {
        width: parent.width
        height: parent.height - 76
        contentWidth: width
        contentHeight: contentColumn.height + 28
        clip: true

        Column {
          id: contentColumn
          width: parent.width
          spacing: 10
          topPadding: 14
          bottomPadding: 24

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Canvas {
              width: 40
              height: 40
              onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = "#656565";
                ctx.lineWidth = 2;
                ctx.beginPath();
                ctx.moveTo(6, 30);
                ctx.lineTo(6, 10);
                ctx.lineTo(20, 16);
                ctx.lineTo(34, 10);
                ctx.lineTo(34, 30);
                ctx.lineTo(20, 24);
                ctx.lineTo(6, 30);
                ctx.stroke();
              }
            }

            Column {
              spacing: -2

              Text {
                text: coordinateLabel()
                color: textPrimary
                font.pixelSize: 17
                font.bold: true
              }

              Text {
                text: sensorTimestampLabel()
                color: textPrimary
                font.pixelSize: 11
              }
            }
          }

          Rectangle {
            width: 308
            height: 34
            radius: 17
            color: "#5d5d5d"
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
              x: activeMode === "planar" ? 2 : width / 2
              y: 2
              width: width / 2 - 4
              height: 30
              radius: 15
              color: activeMode === "planar" ? planarAccent : linearAccent
              Behavior on x { NumberAnimation { duration: 130 } }
            }

            Row {
              anchors.fill: parent

              Item {
                width: parent.width / 2
                height: parent.height

                Text {
                  anchors.centerIn: parent
                  text: "Planar"
                  color: "white"
                  font.pixelSize: 15
                  font.bold: true
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    root.activeMode = "planar";
                    root.seedTypeForMode();
                  }
                }
              }

              Item {
                width: parent.width / 2
                height: parent.height

                Text {
                  anchors.centerIn: parent
                  text: "Linear"
                  color: "white"
                  font.pixelSize: 15
                  font.bold: true
                }

                MouseArea {
                  anchors.fill: parent
                  onClicked: {
                    root.activeMode = "linear";
                    root.seedTypeForMode();
                  }
                }
              }
            }
          }

          Item {
            width: parent.width
            height: 470

            Rectangle {
              id: mainDial
              width: 330
              height: 330
              radius: 165
              anchors.horizontalCenter: parent.horizontalCenter
              anchors.top: parent.top
              color: panelBg
              border.color: dialStroke
              border.width: 2
            }

            Repeater {
              model: 120

              Rectangle {
                width: index % 10 === 0 ? 2 : 1
                height: index % 10 === 0 ? 18 : 10
                color: dialStroke
                radius: 1
                anchors.centerIn: mainDial
                transform: [
                  Translate { y: -156 },
                  Rotation { angle: index * 3; origin.x: 0.5; origin.y: 156 }
                ]
              }
            }

            Shape {
              visible: activeMode === "planar"
              anchors.fill: mainDial
              rotation: isNaN(displayHeading) ? 0 : displayHeading

              ShapePath {
                strokeWidth: 7
                strokeColor: planarAccent
                fillColor: "transparent"
                startX: width * 0.16
                startY: height * 0.67
                PathLine { x: width * 0.84; y: height * 0.48 }
              }

              ShapePath {
                strokeWidth: 7
                strokeColor: planarAccent
                fillColor: "transparent"
                startX: width * 0.51
                startY: height * 0.53
                PathLine { x: width * 0.55; y: height * 0.68 }
              }
            }

            Shape {
              visible: activeMode === "linear"
              anchors.fill: mainDial
              rotation: isNaN(displayHeading) ? 0 : displayHeading

              ShapePath {
                strokeWidth: 8
                strokeColor: linearAccent
                fillColor: "transparent"
                startX: width * 0.50
                startY: height * 0.12
                PathLine { x: width * 0.50; y: height * 0.72 }
              }

              ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: linearAccent
                startX: width * 0.50
                startY: height * 0.82
                PathLine { x: width * 0.44; y: height * 0.70 }
                PathLine { x: width * 0.56; y: height * 0.70 }
                PathLine { x: width * 0.50; y: height * 0.82 }
              }
            }

            Shape {
              anchors.fill: mainDial

              ShapePath {
                strokeWidth: 1.2
                strokeColor: "#b9b9b9"
                fillColor: "transparent"
                startX: width * 0.08
                startY: height * 0.62
                PathQuad {
                  x: width * 0.92
                  y: height * 0.44
                  controlX: width * 0.54
                  controlY: height * 0.96
                }
              }
            }

            Shape {
              visible: activeMode === "linear"
              anchors.fill: mainDial

              ShapePath {
                strokeWidth: 1.2
                strokeColor: "#b9b9b9"
                fillColor: "transparent"
                startX: width * 0.18
                startY: height * 0.56
                PathLine { x: width * 0.44; y: height * 0.61 }
              }

              ShapePath {
                strokeWidth: 1.2
                strokeColor: "#b9b9b9"
                fillColor: "transparent"
                startX: width * 0.58
                startY: height * 0.60
                PathLine { x: width * 0.83; y: height * 0.67 }
              }
            }

            Rectangle {
              width: 110
              height: 110
              radius: 55
              color: panelBg
              border.color: dialStroke
              border.width: 2
              x: mainDial.x + 20
              y: mainDial.y + 242

              Repeater {
                model: 36

                Rectangle {
                  width: index % 9 === 0 ? 2 : 1
                  height: index % 9 === 0 ? 11 : 6
                  color: dialStroke
                  radius: 1
                  anchors.centerIn: parent
                  transform: [
                    Translate { y: -46 },
                    Rotation { angle: index * 10; origin.x: 0.5; origin.y: 46 }
                  ]
                }
              }

              Text {
                anchors.centerIn: parent
                text: formattedWholeAngle(displayHeading) + "\u00b0"
                color: textPrimary
                font.pixelSize: 26
                font.bold: false
              }

              Shape {
                anchors.fill: parent
                rotation: isNaN(displayHeading) ? 0 : displayHeading

                ShapePath {
                  strokeWidth: 0
                  fillColor: planarAccent
                  startX: width * 0.50
                  startY: 8
                  PathLine { x: width * 0.57; y: 24 }
                  PathLine { x: width * 0.50; y: 21 }
                  PathLine { x: width * 0.43; y: 24 }
                  PathLine { x: width * 0.50; y: 8 }
                }
              }
            }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              y: mainDial.y + mainDial.height + 18
              spacing: 22

              Text {
                text: formattedTiltInteger(displayTilt)
                color: "#b9b9b9"
                font.pixelSize: 34
              }

              Text {
                text: "/"
                color: textPrimary
                font.pixelSize: 34
              }

              Text {
                text: formattedWholeAngle(displayHeading)
                color: "#b9b9b9"
                font.pixelSize: 34
              }
            }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              y: mainDial.y + mainDial.height + 66
              spacing: 32

              Rectangle {
                width: 88
                height: 2
                color: greyLine
              }

              Rectangle {
                width: 88
                height: 2
                color: greyLine
              }
            }
          }

          Rectangle {
            width: 360
            height: 60
            radius: 10
            color: modeBarBg
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.bottom: parent.bottom
              width: 44
              color: modeTabBg
            }

            Text {
              anchors.centerIn: parent
              text: measurementFrozen ? "Locked " + modeDisplayName + " reading" : modeDisplayName + " measurement"
              color: "white"
              font.pixelSize: 21
              font.bold: true
            }
          }

          Rectangle {
            width: 320
            height: 56
            radius: 8
            color: fieldBg
            anchors.horizontalCenter: parent.horizontalCenter

            TextField {
              anchors.fill: parent
              anchors.leftMargin: 16
              anchors.rightMargin: 16
              placeholderText: "Locality"
              text: root.localityText
              color: "white"
              font.pixelSize: 20
              font.bold: true
              placeholderTextColor: "#d7d7d7"
              horizontalAlignment: TextInput.AlignHCenter
              verticalAlignment: TextInput.AlignVCenter
              background: Item {}
              onTextChanged: root.localityText = text
            }
          }

          Rectangle {
            width: 320
            height: 56
            radius: 8
            color: fieldBg
            anchors.horizontalCenter: parent.horizontalCenter

            TextField {
              anchors.fill: parent
              anchors.leftMargin: 16
              anchors.rightMargin: 16
              placeholderText: "Type"
              text: root.typeText
              color: "white"
              font.pixelSize: 20
              font.bold: true
              placeholderTextColor: "#d7d7d7"
              horizontalAlignment: TextInput.AlignHCenter
              verticalAlignment: TextInput.AlignVCenter
              background: Item {}
              onTextChanged: {
                root.typeText = text;
                root.lastModeTypeSeed = text;
              }
            }
          }

          Text {
            width: 320
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Examples: " + typeExampleText
            color: textMuted
            font.pixelSize: 12
          }

          Rectangle {
            width: 320
            height: 56
            radius: 8
            color: fieldBg
            anchors.horizontalCenter: parent.horizontalCenter

            TextField {
              anchors.fill: parent
              anchors.leftMargin: 16
              anchors.rightMargin: 16
              placeholderText: "Geology"
              text: root.geologyText
              color: "white"
              font.pixelSize: 20
              font.bold: true
              placeholderTextColor: "#d7d7d7"
              horizontalAlignment: TextInput.AlignHCenter
              verticalAlignment: TextInput.AlignVCenter
              background: Item {}
              onTextChanged: root.geologyText = text
            }
          }

          Rectangle {
            width: 320
            height: 56
            radius: 8
            color: fieldBg
            anchors.horizontalCenter: parent.horizontalCenter

            TextField {
              anchors.fill: parent
              anchors.leftMargin: 16
              anchors.rightMargin: 16
              placeholderText: "Comment"
              text: root.noteText
              color: "white"
              font.pixelSize: 20
              font.bold: true
              placeholderTextColor: "#d7d7d7"
              horizontalAlignment: TextInput.AlignHCenter
              verticalAlignment: TextInput.AlignVCenter
              background: Item {}
              onTextChanged: root.noteText = text
            }
          }

          Rectangle {
            width: 320
            height: 52
            radius: 8
            color: measurementFrozen ? "#88c8a0" : "#7eb693"
            border.color: "#74ba92"
            border.width: 1
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
              anchors.centerIn: parent
              text: freezeButtonLabel()
              color: saveText
              font.pixelSize: 18
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              onClicked: {
                if (root.measurementFrozen) {
                  root.clearFrozenMeasurement();
                } else {
                  root.freezeMeasurement();
                }
              }
            }
          }

          Rectangle {
            width: 320
            height: 60
            radius: 10
            color: saveBg
            border.color: "#6fd694"
            border.width: 1
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
              anchors.centerIn: parent
              text: "Save"
              color: saveText
              font.pixelSize: 24
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.saveMeasurement(root.activeMode)
            }
          }

          Text {
            width: 330
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: leftValueLabel + " / " + rightValueLabel + " | " + positionStatusLabel()
            color: textMuted
            font.pixelSize: 12
          }

          Text {
            width: 330
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Target layer: " + measurementLayerName
            color: textMuted
            font.pixelSize: 12
          }

          Text {
            width: 330
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: sensorDebugLabel()
            color: textMuted
            font.pixelSize: 11
          }
        }
      }
    }
  }
}
