import QtQuick
import QtQuick.Controls
import QtSensors
import org.qfield
import Theme

Item {
  id: root

  property string measurementLayerName: "geology_measurements"
  property var targetMeasurementLayer: null
  property string activeMode: "planar"
  property bool measurementFrozen: false
  property bool saveButtonActive: false
  property bool compassVisible: false
  property string frozenMode: ""
  property real frozenHeading: NaN
  property real frozenTilt: NaN
  property real frozenLatitude: NaN
  property real frozenLongitude: NaN
  property real frozenElevation: NaN
  property real lastSavedLatitude: NaN
  property real lastSavedLongitude: NaN
  property real compassHeadingDeg: NaN
  property real compassCalibrationLevel: NaN
  property real rotationXDeg: NaN
  property real rotationYDeg: NaN
  property real rotationZDeg: NaN
  property real accelX: NaN
  property real accelY: NaN
  property real accelZ: NaN
  property real qfieldOrientationDeg: NaN
  property real magneticVariationDeg: NaN
  property int rotationMappingIndex: -1

  property bool hasCompassReading: false
  property bool hasRotationReading: false
  property bool hasAccelReading: false
  property string lastDebugLogPath: ""
  readonly property string pluginVersionLabel: "v0.3.62"
  readonly property string debugLogFileName: "geo_compass_debug_log.txt"

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
  readonly property color saveBg: "#d71920"
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
  readonly property bool frozenPositionReady: !isNaN(frozenLatitude) && !isNaN(frozenLongitude)
  readonly property bool livePositionReady: positionInfo
                                          && !isNaN(positionLatitude(positionInfo))
                                          && !isNaN(positionLongitude(positionInfo))
  readonly property bool saveReady: saveButtonActive

  onActiveModeChanged: requestDialPaints()

  function requestDialPaints() {
    if (planarSymbolCanvas) {
      planarSymbolCanvas.requestPaint();
    }
    if (linearSymbolCanvas) {
      linearSymbolCanvas.requestPaint();
    }
    if (planarGuideCanvas) {
      planarGuideCanvas.requestPaint();
    }
    if (headingMarkerCanvas) {
      headingMarkerCanvas.requestPaint();
    }
  }

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

  function degreesToRadians(value) {
    return value * Math.PI / 180;
  }

  function radiansToDegrees(value) {
    return value * 180 / Math.PI;
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
    try {
      const positioning = iface.positioning();
      if (!positioning) {
        return null;
      }

      return positioning.positionInformation;
    } catch (error) {
      return null;
    }
  }

  function positionNumericValue(info, valueKey, validKey) {
    if (!info) {
      return NaN;
    }

    const value = Number(memberValue(info, valueKey));
    if (isNaN(value)) {
      return NaN;
    }

    const valid = memberValue(info, validKey);
    if (valid === undefined || valid === null || Boolean(valid) || Boolean(memberValue(info, "isValid"))) {
      return value;
    }

    return NaN;
  }

  function positionLatitude(info) {
    return positionNumericValue(info, "latitude", "latitudeValid");
  }

  function positionLongitude(info) {
    return positionNumericValue(info, "longitude", "longitudeValid");
  }

  function currentElevationValue(info) {
    const position = info ? info : currentPositionInfo();
    let value = positionNumericValue(position, "elevation", "elevationValid");
    if (!isNaN(value)) {
      return value;
    }

    value = positionNumericValue(position, "altitude", "altitudeValid");
    if (!isNaN(value)) {
      return value;
    }

    return NaN;
  }

  function updatePositioningFallbacks() {
    const info = currentPositionInfo();
    let nextOrientation = NaN;
    let nextMagneticVariation = NaN;
    let nextImuHeading = NaN;
    let nextImuPitch = NaN;
    let nextImuRoll = NaN;

    if (info) {
      const imuHeading = Number(memberValue(info, "imuHeading"));
      const imuPitch = Number(memberValue(info, "imuPitch"));
      const imuRoll = Number(memberValue(info, "imuRoll"));
      if (Boolean(memberValue(info, "imuHeadingValid")) && !isNaN(imuHeading)) {
        nextImuHeading = normalizeAzimuth(imuHeading);
      }
      if (Boolean(memberValue(info, "imuPitchValid")) && !isNaN(imuPitch)) {
        nextImuPitch = imuPitch;
      }
      if (Boolean(memberValue(info, "imuRollValid")) && !isNaN(imuRoll)) {
        nextImuRoll = imuRoll;
      }

      if (memberValue(info, "orientationValid") && !isNaN(Number(memberValue(info, "orientation")))) {
        nextOrientation = normalizeAzimuth(Number(memberValue(info, "orientation")));
      } else {
        try {
          const orientation = iface.positioning().orientation;
          if (!isNaN(orientation)) {
            nextOrientation = normalizeAzimuth(orientation);
          }
        } catch (error) {
          nextOrientation = NaN;
        }
      }

      const magneticVariation = Number(memberValue(info, "magneticVariation"));
      if (!isNaN(magneticVariation)) {
        nextMagneticVariation = magneticVariation;
      }
    } else {
      try {
        const orientation = iface.positioning().orientation;
        if (!isNaN(orientation)) {
          nextOrientation = normalizeAzimuth(orientation);
        }
      } catch (error) {
        nextOrientation = NaN;
      }
    }

    qfieldOrientationDeg = isNaN(nextOrientation)
      ? NaN
      : smoothAngle(qfieldOrientationDeg, nextOrientation, 0.25);
    magneticVariationDeg = nextMagneticVariation;
    hasRotationReading = !isNaN(nextImuPitch) && !isNaN(nextImuRoll);
    rotationXDeg = hasRotationReading ? smoothScalar(rotationXDeg, nextImuPitch, 0.25) : NaN;
    rotationYDeg = hasRotationReading ? smoothScalar(rotationYDeg, nextImuRoll, 0.25) : NaN;
    rotationZDeg = isNaN(nextImuHeading) ? NaN : smoothAngle(rotationZDeg, nextImuHeading, 0.25);
  }

  function vectorLength(x, y, z) {
    return Math.sqrt(x * x + y * y + z * z);
  }

  function normalizeVector(vector) {
    const length = vectorLength(vector.x, vector.y, vector.z);
    if (length < 1e-6) {
      return null;
    }

    return {
      x: vector.x / length,
      y: vector.y / length,
      z: vector.z / length
    };
  }

  function crossProduct(a, b) {
    return {
      x: a.y * b.z - a.z * b.y,
      y: a.z * b.x - a.x * b.z,
      z: a.x * b.y - a.y * b.x
    };
  }

  function scaleVector(vector, factor) {
    return {
      x: vector.x * factor,
      y: vector.y * factor,
      z: vector.z * factor
    };
  }

  function smoothScalar(previous, next, alpha) {
    if (isNaN(next)) {
      return previous;
    }

    if (isNaN(previous)) {
      return next;
    }

    return previous + (next - previous) * alpha;
  }

  function smoothAngle(previous, next, alpha) {
    if (isNaN(next)) {
      return previous;
    }

    if (isNaN(previous)) {
      return normalizeAzimuth(next);
    }

    const delta = ((next - previous + 540) % 360) - 180;
    return normalizeAzimuth(previous + delta * alpha);
  }

  function shortestAngleDelta(a, b) {
    return ((a - b + 540) % 360) - 180;
  }

  function tiltFromAccelerometer(x, y, z) {
    return radiansToDegrees(Math.atan2(Math.sqrt(x * x + y * y), Math.abs(z)));
  }

  function azimuthFromEastNorth(east, north) {
    return normalizeAzimuth(radiansToDegrees(Math.atan2(east, north)));
  }

  function defaultRotationMappingIndex() {
    return 1;
  }

  function currentCompassHeading() {
    if (isNaN(compassHeadingDeg)) {
      return NaN;
    }

    if (!isNaN(magneticVariationDeg)) {
      return normalizeAzimuth(compassHeadingDeg + magneticVariationDeg);
    }

    return compassHeadingDeg;
  }

  function currentFallbackHeading() {
    if (!isNaN(rotationZDeg)) {
      return rotationZDeg;
    }

    const compassHeading = currentCompassHeading();
    if (!isNaN(compassHeading)) {
      return compassHeading;
    }

    if (!isNaN(qfieldOrientationDeg)) {
      return qfieldOrientationDeg;
    }

    return NaN;
  }

  function reconstructPlaneNormal(headingDeg, ax, ay, az) {
    if (isNaN(headingDeg) || isNaN(ax) || isNaN(ay) || isNaN(az)) {
      return null;
    }

    const accelLength = vectorLength(ax, ay, az);
    if (accelLength < 1e-6) {
      return null;
    }

    const upX = ax / accelLength;
    const upY = ay / accelLength;
    const upZ = az / accelLength;

    const topHorizontalLength = Math.sqrt(Math.max(0, 1 - upY * upY));
    if (topHorizontalLength < 1e-6) {
      return null;
    }

    const headingRad = degreesToRadians(headingDeg);
    const topHorizontal = {
      x: Math.sin(headingRad),
      y: Math.cos(headingRad),
      z: 0
    };
    const rightHorizontal = {
      x: Math.cos(headingRad),
      y: -Math.sin(headingRad),
      z: 0
    };

    const deviceY = {
      x: topHorizontal.x * topHorizontalLength,
      y: topHorizontal.y * topHorizontalLength,
      z: upY
    };

    const b = -(upX * upY) / topHorizontalLength;
    const aAbs = Math.sqrt(Math.max(0, 1 - upX * upX - b * b));

    const deviceX1 = {
      x: rightHorizontal.x * aAbs + topHorizontal.x * b,
      y: rightHorizontal.y * aAbs + topHorizontal.y * b,
      z: upX
    };
    const deviceX2 = {
      x: -rightHorizontal.x * aAbs + topHorizontal.x * b,
      y: -rightHorizontal.y * aAbs + topHorizontal.y * b,
      z: upX
    };

    const normal1 = normalizeVector(crossProduct(deviceX1, deviceY));
    const normal2 = normalizeVector(crossProduct(deviceX2, deviceY));
    if (!normal1 || !normal2) {
      return null;
    }

    let chosen = Math.abs(normal1.z - upZ) <= Math.abs(normal2.z - upZ) ? normal1 : normal2;
    if (chosen.z < 0) {
      chosen = scaleVector(chosen, -1);
    }

    return chosen;
  }

  function planeOrientationFromNormal(normal) {
    if (!normal) {
      return null;
    }

    const horizontalLength = Math.sqrt(normal.x * normal.x + normal.y * normal.y);
    const dipDeg = radiansToDegrees(Math.atan2(horizontalLength, Math.max(0, normal.z)));
    const dipDirectionDeg = horizontalLength < 1e-6
      ? NaN
      : azimuthFromEastNorth(normal.x, normal.y);

    return {
      dipDeg: dipDeg,
      dipDirectionDeg: dipDirectionDeg
    };
  }

  function gravityPlanarOrientation() {
    const headingDeg = currentFallbackHeading();
    const normal = reconstructPlaneNormal(headingDeg, accelX, accelY, accelZ);
    return planeOrientationFromNormal(normal);
  }

  function gravityLinearOrientation() {
    const headingDeg = currentFallbackHeading();
    if (isNaN(headingDeg) || isNaN(accelX) || isNaN(accelY) || isNaN(accelZ)) {
      return null;
    }

    return {
      trendDeg: headingDeg,
      plungeDeg: tiltFromAccelerometer(accelX, accelY, accelZ)
    };
  }

  function rotationCandidateOrientation(headingDeg, xDeg, yDeg, swapAxes, forwardSign, rightSign) {
    const forwardRadians = degreesToRadians(swapAxes ? yDeg : xDeg);
    const rightRadians = degreesToRadians(swapAxes ? xDeg : yDeg);
    const forwardSlope = forwardSign * Math.tan(forwardRadians);
    const rightSlope = rightSign * Math.tan(rightRadians);
    const combinedSlope = Math.sqrt(forwardSlope * forwardSlope + rightSlope * rightSlope);

    return {
      dipDeg: radiansToDegrees(Math.atan(combinedSlope)),
      dipDirectionDeg: combinedSlope < 1e-6
        ? NaN
        : normalizeAzimuth(headingDeg + radiansToDegrees(Math.atan2(rightSlope, forwardSlope))),
      trendDeg: forwardSlope >= 0
        ? normalizeAzimuth(headingDeg)
        : normalizeAzimuth(headingDeg + 180),
      plungeDeg: radiansToDegrees(Math.atan(Math.abs(forwardSlope)))
    };
  }

  function rotationCandidateFromIndex(index, headingDeg, xDeg, yDeg) {
    let candidateIndex = 0;
    const signs = [-1, 1];

    for (let swapIndex = 0; swapIndex < 2; ++swapIndex) {
      const swapAxes = swapIndex === 1;

      for (let forwardIndex = 0; forwardIndex < signs.length; ++forwardIndex) {
        const forwardSign = signs[forwardIndex];

        for (let rightIndex = 0; rightIndex < signs.length; ++rightIndex) {
          const rightSign = signs[rightIndex];

          if (candidateIndex === index) {
            return rotationCandidateOrientation(
              headingDeg,
              xDeg,
              yDeg,
              swapAxes,
              forwardSign,
              rightSign
            );
          }

          candidateIndex += 1;
        }
      }
    }

    return rotationCandidateOrientation(headingDeg, xDeg, yDeg, false, -1, 1);
  }

  function updateRotationMapping() {
    const headingDeg = currentFallbackHeading();
    if (isNaN(headingDeg) || isNaN(rotationXDeg) || isNaN(rotationYDeg)) {
      return;
    }

    const gravityOrientation = gravityPlanarOrientation();
    let bestIndex = rotationMappingIndex >= 0 ? rotationMappingIndex : defaultRotationMappingIndex();
    let bestScore = Number.POSITIVE_INFINITY;

    for (let candidateIndex = 0; candidateIndex < 8; ++candidateIndex) {
      const candidate = rotationCandidateFromIndex(candidateIndex, headingDeg, rotationXDeg, rotationYDeg);
      let score = 0;

      if (gravityOrientation) {
        score += Math.abs(candidate.dipDeg - gravityOrientation.dipDeg);

        if (!isNaN(candidate.dipDirectionDeg)
            && !isNaN(gravityOrientation.dipDirectionDeg)
            && candidate.dipDeg > 3
            && gravityOrientation.dipDeg > 3) {
          score += Math.abs(shortestAngleDelta(candidate.dipDirectionDeg, gravityOrientation.dipDirectionDeg)) * 0.25;
        }
      } else if (rotationMappingIndex >= 0) {
        score += candidateIndex === rotationMappingIndex ? 0 : 10;
      } else {
        score += candidateIndex === defaultRotationMappingIndex() ? 0 : 10;
      }

      if (candidateIndex === rotationMappingIndex) {
        score -= 0.5;
      }

      if (score < bestScore) {
        bestScore = score;
        bestIndex = candidateIndex;
      }
    }

    rotationMappingIndex = bestIndex;
  }

  function rotationOrientation() {
    const headingDeg = currentFallbackHeading();
    if (isNaN(headingDeg) || isNaN(rotationXDeg) || isNaN(rotationYDeg)) {
      return null;
    }

    const mappingIndex = rotationMappingIndex >= 0 ? rotationMappingIndex : defaultRotationMappingIndex();
    return rotationCandidateFromIndex(mappingIndex, headingDeg, rotationXDeg, rotationYDeg);
  }

  function currentPlanarOrientation() {
    const rotation = rotationOrientation();
    if (rotation) {
      return {
        heading: rotation.dipDirectionDeg,
        tilt: rotation.dipDeg,
        method: "QField IMU + heading"
      };
    }

    const gravity = gravityPlanarOrientation();
    if (gravity) {
      return {
        heading: gravity.dipDirectionDeg,
        tilt: gravity.dipDeg,
        method: "gravity + compass"
      };
    }

    return null;
  }

  function currentLinearOrientation() {
    const rotation = rotationOrientation();
    if (rotation) {
      return {
        heading: rotation.trendDeg,
        tilt: rotation.plungeDeg,
        method: "QField IMU + heading"
      };
    }

    const gravity = gravityLinearOrientation();
    if (gravity) {
      return {
        heading: gravity.trendDeg,
        tilt: gravity.plungeDeg,
        method: "gravity + compass"
      };
    }

    return null;
  }

  function currentMeasurementOrientation() {
    return activeMode === "planar"
      ? currentPlanarOrientation()
      : currentLinearOrientation();
  }

  function currentHeading() {
    const orientation = currentMeasurementOrientation();
    return orientation ? orientation.heading : NaN;
  }

  function currentTiltDown() {
    const orientation = currentMeasurementOrientation();
    return orientation ? orientation.tilt : NaN;
  }

  function headingSensorLabel() {
    if (!isNaN(currentCompassHeading())) {
      return isNaN(magneticVariationDeg) ? "compass" : "compass + declination";
    }

    if (!isNaN(qfieldOrientationDeg)) {
      return "qfield orientation";
    }

    return "none";
  }

  function tiltSensorLabel() {
    if (hasRotationReading) {
      return "QField IMU pitch/roll";
    }

    if (hasAccelReading) {
      return "accelerometer gravity";
    }

    return "none";
  }

  function measurementMethodLabel() {
    const orientation = currentMeasurementOrientation();
    return orientation ? orientation.method : "none";
  }

  function lockedMode() {
    return frozenMode.length > 0 ? frozenMode : activeMode;
  }

  function modeDisplayNameFor(mode) {
    return mode === "linear" ? "Linear" : "Planar";
  }

  function tiltDisplayLabelFor(mode) {
    return mode === "linear" ? "Plunge" : "Dip";
  }

  function headingDisplayLabelFor(mode) {
    return mode === "linear" ? "Trend" : "Dip Dir";
  }

  function tiltDisplayLabel() {
    return tiltDisplayLabelFor(activeMode);
  }

  function headingDisplayLabel() {
    return headingDisplayLabelFor(activeMode);
  }

  function modeSubtitleLabel() {
    return activeMode === "planar" ? "Planar capture mode" : "Linear capture mode";
  }

  function orientationSummaryLabel(mode, heading, tilt) {
    return tiltDisplayLabelFor(mode)
      + " "
      + formattedTiltInteger(tilt)
      + " / "
      + headingDisplayLabelFor(mode)
      + " "
      + formattedWholeAngle(heading);
  }

  function readoutBannerLabel() {
    return measurementFrozen
      ? "Locked " + modeDisplayNameFor(lockedMode()) + " | " + orientationSummaryLabel(lockedMode(), frozenHeading, frozenTilt)
      : modeDisplayName + " reading";
  }

  function sensorSourceSummaryLabel() {
    return "Method: " + measurementMethodLabel()
      + " | Heading: " + headingSensorLabel()
      + " | Tilt: " + tiltSensorLabel();
  }

  function sensorGuidanceLabel() {
    const modeGuidance = activeMode === "planar"
      ? "Lay the back of the phone flush on the plane."
      : "Align the phone top edge with the lineation.";

    return "Phone-first sensors: QField IMU when available, accelerometer gravity fallback. " + modeGuidance;
  }

  function formatSensorValue(valid, value) {
    if (!valid || isNaN(value)) {
      return "--";
    }

    return Math.round(value) + "\u00b0";
  }

  function formatAngleValue(value) {
    if (isNaN(value)) {
      return "--";
    }

    return Math.round(value) + "\u00b0";
  }

  function formatAxisValue(value) {
    if (isNaN(value)) {
      return "--";
    }

    return value.toFixed(2);
  }

  function sensorDebugLabel() {
    return "Compass "
      + formatAngleValue(currentCompassHeading())
      + " | IMU pitch "
      + formatAngleValue(rotationXDeg)
      + " | IMU roll "
      + formatAngleValue(rotationYDeg)
      + " | IMU heading "
      + formatAngleValue(rotationZDeg)
      + " | QField "
      + formatAngleValue(qfieldOrientationDeg);
  }

  function sensorDebugMultilineLabel() {
    return "Compass: " + formatAngleValue(currentCompassHeading())
      + "    Method: " + measurementMethodLabel()
      + "\nIMU pitch/roll/heading: " + formatAngleValue(rotationXDeg)
      + " / " + formatAngleValue(rotationYDeg)
      + " / " + formatAngleValue(rotationZDeg)
      + "\nAccel X/Y/Z: " + formatAxisValue(accelX)
      + " / " + formatAxisValue(accelY)
      + " / " + formatAxisValue(accelZ);
  }

  function freezeMeasurement() {
    appendDebugLog("freeze requested");
    const heading = liveHeading;
    const tilt = liveTilt;
    const info = currentPositionInfo();
    const latitude = positionLatitude(info);
    const longitude = positionLongitude(info);
    const hasUsablePosition = !isNaN(latitude) && !isNaN(longitude);

    if (isNaN(heading)) {
      appendDebugLog("freeze failed invalid heading");
      iface.mainWindow().displayToast("No valid heading available from the phone sensors");
      return;
    }

    if (isNaN(tilt)) {
      appendDebugLog("freeze failed invalid tilt");
      iface.mainWindow().displayToast("No valid tilt value available from the phone sensors");
      return;
    }

    if (!hasUsablePosition) {
      appendDebugLog("freeze failed missing GNSS");
      iface.mainWindow().displayToast("No valid GNSS position available to freeze");
      return;
    }

    frozenHeading = heading;
    frozenTilt = tilt;
    frozenMode = activeMode;
    frozenLatitude = latitude;
    frozenLongitude = longitude;
    frozenElevation = currentElevationValue(info);
    saveButtonActive = true;
    measurementFrozen = true;
    appendDebugLog(
      "freeze succeeded mode=" + frozenMode
        + " heading=" + debugValue(frozenHeading)
        + " tilt=" + debugValue(frozenTilt)
        + " lat=" + debugValue(frozenLatitude)
        + " lon=" + debugValue(frozenLongitude)
        + " method=" + measurementMethodLabel()
    );
    iface.mainWindow().displayToast(
      "Locked "
        + modeDisplayNameFor(frozenMode)
        + " | "
        + orientationSummaryLabel(frozenMode, frozenHeading, frozenTilt)
        + " | "
        + formatLatitude(frozenLatitude)
        + ", "
        + formatLongitude(frozenLongitude)
    );
  }

  function clearFrozenMeasurement() {
    measurementFrozen = false;
    saveButtonActive = false;
    frozenMode = "";
    frozenHeading = NaN;
    frozenTilt = NaN;
    frozenLatitude = NaN;
    frozenLongitude = NaN;
    frozenElevation = NaN;
  }

  function currentSensorTag() {
    const method = measurementMethodLabel();
    if (method === "QField IMU + heading") {
      return "qfield_imu_heading";
    }

    if (method === "gravity + compass") {
      return "qt_accel_compass";
    }

    return "qt_internal";
  }

  function layersByName(name) {
    const matches = qgisProject.mapLayersByName(name);
    return matches ? matches : [];
  }

  function layerByName(name) {
    const matches = layersByName(name);
    if (collectionLength(matches) === 0) {
      return null;
    }
    return collectionItem(matches, 0);
  }

  function memberValue(target, memberName) {
    if (!target || !memberName) {
      return undefined;
    }

    const member = target[memberName];
    if (member === undefined || member === null) {
      return member;
    }

    if (typeof member === "function") {
      try {
        return target[memberName]();
      } catch (error) {
      }
    }

    return member;
  }

  function callMember(target, memberName) {
    if (!target || !memberName) {
      return undefined;
    }

    const member = target[memberName];
    if (typeof member !== "function") {
      return undefined;
    }

    let args = [];
    for (let i = 2; i < arguments.length; ++i) {
      args.push(arguments[i]);
    }

    try {
      return member.apply(target, args);
    } catch (error) {
    }

    return undefined;
  }

  function collectionLength(collection) {
    if (!collection) {
      return 0;
    }

    const lengthValue = memberValue(collection, "length");
    const numericLength = Number(lengthValue);
    if (!isNaN(numericLength)) {
      return numericLength;
    }

    const countValue = memberValue(collection, "count");
    const numericCount = Number(countValue);
    if (!isNaN(numericCount)) {
      return numericCount;
    }

    const sizeValue = memberValue(collection, "size");
    const numericSize = Number(sizeValue);
    if (!isNaN(numericSize)) {
      return numericSize;
    }

    return 0;
  }

  function collectionItem(collection, index) {
    if (!collection || index < 0) {
      return null;
    }

    if (collection[index] !== undefined) {
      return collection[index];
    }

    if (typeof collection.at === "function") {
      try {
        return collection.at(index);
      } catch (error) {
      }
    }

    if (typeof collection.field === "function") {
      try {
        return collection.field(index);
      } catch (error) {
      }
    }

    if (typeof collection.get === "function") {
      try {
        return collection.get(index);
      } catch (error) {
      }
    }

    return null;
  }

  function layerNameValue(layer) {
    const nameValue = memberValue(layer, "name");
    if (nameValue === undefined || nameValue === null) {
      return "";
    }

    return String(nameValue);
  }

  function layerDisplayName(layer) {
    const nameValue = layerNameValue(layer);
    return nameValue.length > 0 ? nameValue : "unnamed layer";
  }

  function layerFieldsValue(layer) {
    const fieldsValue = memberValue(layer, "fields");
    return fieldsValue ? fieldsValue : [];
  }

  function stringListValue(collection) {
    if (!collection) {
      return [];
    }

    if (Array.isArray(collection)) {
      let values = [];
      for (let i = 0; i < collection.length; ++i) {
        const item = collection[i];
        if (item !== undefined && item !== null) {
          values.push(String(item));
        }
      }
      return values;
    }

    let values = [];
    const itemCount = collectionLength(collection);
    for (let i = 0; i < itemCount; ++i) {
      const item = collectionItem(collection, i);
      if (item !== undefined && item !== null) {
        values.push(String(item));
      }
    }

    return values;
  }

  function fieldNameValue(field) {
    const nameValue = memberValue(field, "name");
    if (nameValue === undefined || nameValue === null) {
      return "";
    }

    return String(nameValue);
  }

  function layerFieldNames(layer) {
    const fields = layerFieldsValue(layer);
    const namedValues = stringListValue(memberValue(fields, "names"));
    if (namedValues.length > 0) {
      return namedValues;
    }

    let values = [];
    const fieldCount = collectionLength(fields);
    for (let i = 0; i < fieldCount; ++i) {
      const currentName = fieldNameValue(collectionItem(fields, i));
      if (currentName.length > 0) {
        values.push(currentName);
      }
    }

    return values;
  }

  function resolvedFieldNameByLookup(target, requestedName, fieldNames) {
    if (!target || !requestedName) {
      return "";
    }

    const lookupMethods = ["lookupField", "indexFromName", "indexOf", "fieldNameIndex"];
    for (let i = 0; i < lookupMethods.length; ++i) {
      const lookupIndex = callMember(target, lookupMethods[i], requestedName);
      const numericIndex = Number(lookupIndex);
      if (isNaN(numericIndex) || numericIndex < 0) {
        continue;
      }

      if (numericIndex < fieldNames.length) {
        return fieldNames[numericIndex];
      }

      return requestedName;
    }

    return "";
  }

  function layerGeometryTypeValue(layer) {
    if (!layer) {
      return NaN;
    }

    const geometryTypeValue = memberValue(layer, "geometryType");
    const numericGeometryType = Number(geometryTypeValue);
    if (!isNaN(numericGeometryType)) {
      return numericGeometryType;
    }

    if (geometryTypeValue !== undefined && geometryTypeValue !== null) {
      const geometryTypeText = String(geometryTypeValue).toLowerCase();
      if (geometryTypeText.indexOf("point") !== -1) {
        return 0;
      }
      if (geometryTypeText.indexOf("line") !== -1) {
        return 1;
      }
      if (geometryTypeText.indexOf("polygon") !== -1) {
        return 2;
      }
    }

    const wkbTypeValue = memberValue(layer, "wkbType");
    if (wkbTypeValue !== undefined && wkbTypeValue !== null) {
      const wkbTypeText = String(wkbTypeValue).toLowerCase();
      if (wkbTypeText.indexOf("point") !== -1) {
        return 0;
      }
      if (wkbTypeText.indexOf("line") !== -1) {
        return 1;
      }
      if (wkbTypeText.indexOf("polygon") !== -1) {
        return 2;
      }
    }

    return NaN;
  }

  function isPointLayer(layer) {
    const geometryType = layerGeometryTypeValue(layer);
    return geometryType === 0;
  }

  function resolvedFieldName(layer, fieldName) {
    if (!fieldName || !layer) {
      return "";
    }

    const requestedName = String(fieldName);
    const requestedLower = requestedName.toLowerCase();
    const requestedCompact = requestedLower.replace(/[^a-z0-9]/g, "");
    const fieldNames = layerFieldNames(layer);
    if (fieldNames.length === 0) {
      return "";
    }

    const fields = layerFieldsValue(layer);
    const directFieldLookup = resolvedFieldNameByLookup(fields, requestedName, fieldNames);
    if (directFieldLookup.length > 0) {
      return directFieldLookup;
    }

    const directLayerLookup = resolvedFieldNameByLookup(layer, requestedName, fieldNames);
    if (directLayerLookup.length > 0) {
      return directLayerLookup;
    }

    let caseInsensitiveMatch = "";
    let compactMatch = "";

    for (let i = 0; i < fieldNames.length; ++i) {
      const currentName = fieldNames[i];
      if (currentName.length === 0) {
        continue;
      }

      if (currentName === requestedName) {
        return currentName;
      }

      if (caseInsensitiveMatch.length === 0 && currentName.toLowerCase() === requestedLower) {
        caseInsensitiveMatch = currentName;
      }

      if (compactMatch.length === 0
          && requestedCompact.length > 0
          && currentName.toLowerCase().replace(/[^a-z0-9]/g, "") === requestedCompact) {
        compactMatch = currentName;
      }
    }

    return caseInsensitiveMatch.length > 0 ? caseInsensitiveMatch : compactMatch;
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
      return "No compatible point layer was found in this project.";
    }

    if (!isPointLayer(layer)) {
      return "Layer '" + layerDisplayName(layer) + "' is not a point layer.";
    }

    if (LayerUtils.isFeatureAdditionLocked(layer)) {
      return "Layer '" + layerDisplayName(layer) + "' is not editable for adding features.";
    }

    if (missing.length > 0) {
      return "Layer '" + layerDisplayName(layer) + "' is missing required fields: " + missing.join(", ");
    }

    return "";
  }

  function findCompatibleMeasurementLayer() {
    const preferredLayers = layersByName(measurementLayerName);
    let preferredMessage = "";
    const preferredCount = collectionLength(preferredLayers);
    for (let i = 0; i < preferredCount; ++i) {
      const preferredLayer = collectionItem(preferredLayers, i);
      const currentMessage = compatibleLayerMessage(preferredLayer, missingRequiredFields(preferredLayer));
      if (currentMessage.length === 0) {
        return {
          layer: preferredLayer,
          message: ""
        };
      }

      if (preferredMessage.length === 0) {
        preferredMessage = currentMessage;
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

    if (preferredMessage.length > 0) {
      return {
        layer: null,
        message: preferredMessage
      };
    }

    return {
      layer: null,
      message: compatibleLayerMessage(null, [])
    };
  }

  function projectFilePath() {
    let path = "";

    try {
      const mainWindow = iface.mainWindow();
      const projectInfo = memberValue(mainWindow, "projectInfo");
      const projectInfoPath = memberValue(projectInfo, "filePath");
      if (projectInfoPath !== undefined && projectInfoPath !== null) {
        path = String(projectInfoPath);
      }
    } catch (error) {
      path = "";
    }

    if (path.length > 0) {
      return path;
    }

    try {
      const fileName = memberValue(qgisProject, "fileName");
      if (fileName !== undefined && fileName !== null) {
        path = String(fileName);
      }
    } catch (error) {
      path = "";
    }

    return path;
  }

  function resolvedLocalPath(relativePath) {
    let resolvedUrl = String(Qt.resolvedUrl(relativePath));
    let localPath = decodeURIComponent(resolvedUrl);

    if (localPath.indexOf("file://") === 0) {
      localPath = decodeURIComponent(localPath.substring(7));
      if (localPath.length > 2 && localPath[0] === "/" && localPath[2] === ":") {
        localPath = localPath.substring(1);
      }
    }

    return localPath;
  }

  function projectDirectoryPath() {
    const projectPath = projectFilePath();
    if (projectPath.length === 0) {
      return "";
    }

    return FileUtils.absolutePath(projectPath);
  }

  function debugLogPath() {
    const projectDir = projectDirectoryPath();
    if (projectDir.length === 0) {
      return "";
    }

    return projectDir + "/" + debugLogFileName;
  }

  function debugValue(value) {
    if (value === undefined) {
      return "undefined";
    }
    if (value === null) {
      return "null";
    }
    if (typeof value === "number") {
      return isNaN(value) ? "NaN" : value.toFixed(3);
    }
    return String(value);
  }

  function appendDebugLog(message) {
    try {
      const path = debugLogPath();
      if (path.length === 0) {
        return false;
      }

      let existing = "";
      if (FileUtils.fileExists(path)) {
        existing = FileUtils.readFileContent(path);
        if (existing.length > 40000) {
          existing = existing.substring(existing.length - 30000);
        }
      }

      const line = new Date().toISOString()
        + " | " + pluginVersionLabel
        + " | " + message
        + "\n";

      if (FileUtils.writeFileContent(path, existing + line)) {
        lastDebugLogPath = path;
        return true;
      }
    } catch (error) {
    }

    return false;
  }

  function logSensorSnapshot(reason) {
    appendDebugLog(
      reason
        + " visible=" + debugValue(compassVisible)
        + " mode=" + activeMode
        + " frozen=" + measurementFrozen
        + " method=" + measurementMethodLabel()
        + " heading=" + debugValue(liveHeading)
        + " tilt=" + debugValue(liveTilt)
        + " compass=" + debugValue(currentCompassHeading())
        + " qfieldOrientation=" + debugValue(qfieldOrientationDeg)
        + " imuPitch=" + debugValue(rotationXDeg)
        + " imuRoll=" + debugValue(rotationYDeg)
        + " imuHeading=" + debugValue(rotationZDeg)
        + " accelX=" + debugValue(accelX)
        + " accelY=" + debugValue(accelY)
        + " accelZ=" + debugValue(accelZ)
        + " lat=" + debugValue(positionLatitude(positionInfo))
        + " lon=" + debugValue(positionLongitude(positionInfo))
    );
  }

  function projectCrsAuthId() {
    let authId = "EPSG:4326";

    try {
      const crs = memberValue(qgisProject, "crs");
      const value = memberValue(crs, "authid");
      if (value !== undefined && value !== null && String(value).length > 0) {
        authId = String(value);
      }
    } catch (error) {
      authId = "EPSG:4326";
    }

    return authId;
  }

  function persistentLayerBaseName(layerName) {
    const rawName = layerName && layerName.length > 0 ? layerName : measurementLayerName;
    const sanitizedName = FileUtils.sanitizeFilePathPart(rawName);
    return sanitizedName.length > 0 ? sanitizedName : "geology_measurements";
  }

  function persistentLayerFilePath(layerName) {
    const projectDir = projectDirectoryPath();
    if (projectDir.length === 0) {
      return "";
    }

    return projectDir + "/" + persistentLayerBaseName(layerName) + ".gpkg";
  }

  function packagedTemplateLayerPath() {
    return resolvedLocalPath("measurement_layer_template.gpkg");
  }

  function loadPersistentMeasurementLayer(layerName, filePath) {
    let loadedLayer = LayerUtils.loadVectorLayer(filePath + "|layername=" + layerName, layerName, "ogr");
    if (!loadedLayer) {
      loadedLayer = LayerUtils.loadVectorLayer(filePath, layerName, "ogr");
    }

    if (!loadedLayer) {
      return {
        layer: null,
        message: "QField could not load measurement layer file '" + FileUtils.fileName(filePath) + "'."
      };
    }

    const compatibilityMessage = compatibleLayerMessage(loadedLayer, missingRequiredFields(loadedLayer));
    if (compatibilityMessage.length > 0) {
      return {
        layer: null,
        message: compatibilityMessage
      };
    }

    if (!ProjectUtils.addMapLayer(qgisProject, loadedLayer)) {
      return {
        layer: null,
        message: "QField loaded a measurement layer file but could not add it to the current project."
      };
    }

    try {
      LayerUtils.setDefaultRenderer(loadedLayer, qgisProject);
    } catch (error) {
    }

    return {
      layer: loadedLayer,
      message: ""
    };
  }

  function createPersistentMeasurementLayer() {
    const projectDir = projectDirectoryPath();
    if (projectDir.length === 0) {
      return {
        layer: null,
        message: "QField could not determine the current project directory for creating a measurement layer."
      };
    }

    let candidateName = measurementLayerName;
    let candidatePath = persistentLayerFilePath(candidateName);

    if (candidatePath.length === 0 || !FileUtils.isWithinProjectDirectory(candidatePath)) {
      return {
        layer: null,
        message: "QField could not build a safe file path for a measurement layer inside the project directory."
      };
    }

    if (FileUtils.fileExists(candidatePath)) {
      const loadedExistingLayer = loadPersistentMeasurementLayer(candidateName, candidatePath);
      if (loadedExistingLayer.layer) {
        return {
          layer: loadedExistingLayer.layer,
          message: "",
          created: false
        };
      }
    }

    let suffix = 2;
    while (layerByName(candidateName) || FileUtils.fileExists(candidatePath)) {
      candidateName = measurementLayerName + "_" + suffix;
      candidatePath = persistentLayerFilePath(candidateName);
      suffix += 1;
    }

    if (candidatePath.length === 0 || !FileUtils.isWithinProjectDirectory(candidatePath)) {
      return {
        layer: null,
        message: "QField could not build a safe file path for a new measurement layer inside the project directory."
      };
    }

    const templatePath = packagedTemplateLayerPath();
    if (!templatePath || templatePath.length === 0 || !FileUtils.fileExists(templatePath)) {
      return {
        layer: null,
        message: "QField could not find the bundled measurement layer template."
      };
    }

    const templateContent = FileUtils.readFileContent(templatePath);
    if (!templateContent || templateContent.length === 0) {
      return {
        layer: null,
        message: "QField could not read the bundled measurement layer template."
      };
    }

    if (!FileUtils.writeFileContent(candidatePath, templateContent)) {
      return {
        layer: null,
        message: "QField could not copy the measurement layer template into the project directory."
      };
    }

    const loadedLayer = loadPersistentMeasurementLayer(candidateName, candidatePath);
    if (!loadedLayer.layer) {
      return loadedLayer;
    }

    return {
      layer: loadedLayer.layer,
      message: "",
      created: true
    };
  }

  function showAlert(message) {
    appendDebugLog("alert message=" + message);
    noticeDialog.text = message;
    noticeDialog.open();
  }

  function openCompassFromMap() {
    appendDebugLog("open requested projectPath=" + projectFilePath() + " projectDir=" + projectDirectoryPath());
    const result = findCompatibleMeasurementLayer();
    appendDebugLog("layer lookup layerFound=" + Boolean(result.layer) + " message=" + result.message);

    if (!result.layer) {
      const creation = createPersistentMeasurementLayer();
      if (!creation.layer) {
        appendDebugLog("layer creation failed message=" + creation.message);
        showAlert(result.message + "\n\n" + creation.message);
        return;
      }

      targetMeasurementLayer = creation.layer;
      const createdLayerName = layerNameValue(creation.layer);
      if (createdLayerName.length > 0) {
        measurementLayerName = createdLayerName;
      }
      compassVisible = true;
      seedTypeForMode();
      requestDialPaints();
      appendDebugLog(
        "compass opened with createdOrLoadedLayer="
          + layerNameValue(creation.layer)
          + " created=" + Boolean(creation.created)
      );
      logSensorSnapshot("open snapshot");
      iface.mainWindow().displayToast(
        creation.created
          ? "Persistent measurement layer created and added to project"
          : "Measurement layer loaded from project folder"
      );
      return;
    }

    targetMeasurementLayer = result.layer;
    const resultLayerName = layerNameValue(result.layer);
    if (resultLayerName.length > 0) {
      measurementLayerName = resultLayerName;
    }
    compassVisible = true;
    seedTypeForMode();
    requestDialPaints();
    appendDebugLog("compass opened with existingLayer=" + layerNameValue(result.layer));
    logSensorSnapshot("open snapshot");
  }

  function closeCompass() {
    appendDebugLog("close requested");
    logSensorSnapshot("close snapshot");
    compassVisible = false;
    refreshMapForSavedMeasurement();
  }

  function geometryFromCoordinates(longitude, latitude) {
    if (isNaN(longitude) || isNaN(latitude)) {
      return null;
    }

    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return null;
    }

    return GeometryUtils.createGeometryFromWkt("POINT(" + longitude + " " + latitude + ")");
  }

  function currentGeometry() {
    const info = currentPositionInfo();
    const latitude = positionLatitude(info);
    const longitude = positionLongitude(info);

    if (isNaN(latitude) || isNaN(longitude)) {
      return null;
    }

    return geometryFromCoordinates(longitude, latitude);
  }

  function requestMapRefresh() {
  }

  function refreshMapForSavedMeasurement() {
    lastSavedLatitude = NaN;
    lastSavedLongitude = NaN;
  }

  function fieldExists(layer, fieldName) {
    return resolvedFieldName(layer, fieldName).length > 0;
  }

  function setAttributeIfPresent(feature, layer, fieldName, value) {
    const actualFieldName = resolvedFieldName(layer, fieldName);
    if (actualFieldName.length > 0) {
      feature.setAttribute(actualFieldName, value);
    }
  }

  function layerCommitErrorsText(layer) {
    if (!layer) {
      return "";
    }

    const errors = stringListValue(callMember(layer, "commitErrors"));
    return errors.length > 0 ? errors.join(" | ") : "";
  }

  function persistFeatureToLayer(layer, feature) {
    if (!layer || !feature) {
      appendDebugLog("persist abort missing layer or feature");
      return {
        ok: false,
        message: "Missing layer or feature while saving the measurement."
      };
    }

    const wasEditable = Boolean(callMember(layer, "isEditable"));
    appendDebugLog(
      "persist begin layer=" + targetLayerLabel(layer)
        + " wasEditable=" + wasEditable
    );
    if (!wasEditable && !callMember(layer, "startEditing")) {
      appendDebugLog("persist failed startEditing layer=" + targetLayerLabel(layer));
      return {
        ok: false,
        message: "Failed to start editing on layer " + targetLayerLabel(layer)
      };
    }
    appendDebugLog("persist editing ready layer=" + targetLayerLabel(layer));

    appendDebugLog("persist addFeature begin layer=" + targetLayerLabel(layer));
    if (!LayerUtils.addFeature(layer, feature)) {
      appendDebugLog("persist addFeature failed layer=" + targetLayerLabel(layer));
      if (!wasEditable) {
        callMember(layer, "rollBack");
        appendDebugLog("persist rollBack after addFeature failure layer=" + targetLayerLabel(layer));
      }
      return {
        ok: false,
        message: "Failed to add the measurement feature to layer " + targetLayerLabel(layer)
      };
    }
    appendDebugLog("persist addFeature ok layer=" + targetLayerLabel(layer));

    appendDebugLog(
      "persist commit begin layer=" + targetLayerLabel(layer)
        + " stopEditing=" + (!wasEditable)
    );
    if (!callMember(layer, "commitChanges", !wasEditable)) {
      const commitErrorsText = layerCommitErrorsText(layer);
      appendDebugLog("persist commit failed layer=" + targetLayerLabel(layer) + " errors=" + commitErrorsText);
      if (!wasEditable) {
        callMember(layer, "rollBack");
        appendDebugLog("persist rollBack after commit failure layer=" + targetLayerLabel(layer));
      }
      return {
        ok: false,
        message: commitErrorsText.length > 0
          ? "Failed to commit the measurement to layer " + targetLayerLabel(layer) + ": " + commitErrorsText
          : "Failed to commit the measurement to layer " + targetLayerLabel(layer)
      };
    }
    appendDebugLog("persist commit ok layer=" + targetLayerLabel(layer));

    return {
      ok: true,
      message: ""
    };
  }

  function targetLayerLabel(layer) {
    if (!layer) {
      return measurementLayerName;
    }

    const layerName = layerNameValue(layer);
    if (layerName.length > 0) {
      return layerName;
    }

    return measurementLayerName;
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
    if (!saveReady) {
      appendDebugLog("save rejected saveReady=false frozen=" + measurementFrozen);
      iface.mainWindow().displayToast(
        measurementFrozen
          ? "This locked reading has no frozen GNSS position yet"
          : "Freeze a reading before saving it"
      );
      return;
    }

    iface.mainWindow().displayToast("Saving measurement...");
    appendDebugLog("save requested kind=" + kind);
    try {
      saveMeasurementChecked(kind);
    } catch (error) {
      appendDebugLog("save exception error=" + error);
      iface.mainWindow().displayToast("Save error: " + error);
    }
  }

  function saveMeasurementChecked(kind) {
    const measurementKind = measurementFrozen && frozenMode.length > 0 ? frozenMode : kind;
    const heading = measurementFrozen ? frozenHeading : liveHeading;
    const tilt = measurementFrozen ? frozenTilt : liveTilt;
    const info = currentPositionInfo();
    const latitude = measurementFrozen
      ? frozenLatitude
      : positionLatitude(info);
    const longitude = measurementFrozen
      ? frozenLongitude
      : positionLongitude(info);
    const elevation = measurementFrozen ? frozenElevation : currentElevationValue(info);
    const geometry = geometryFromCoordinates(longitude, latitude);
    const targetLayer = targetMeasurementLayer ? targetMeasurementLayer : layerByName(measurementLayerName);
    const layerLabel = targetLayerLabel(targetLayer);

    appendDebugLog(
      "save checked kind=" + measurementKind
        + " layer=" + layerLabel
        + " heading=" + debugValue(heading)
        + " tilt=" + debugValue(tilt)
        + " lat=" + debugValue(latitude)
        + " lon=" + debugValue(longitude)
        + " elevation=" + debugValue(elevation)
        + " method=" + measurementMethodLabel()
    );

    if (!targetLayer) {
      appendDebugLog("save failed missing layer");
      iface.mainWindow().displayToast("Missing layer: " + measurementLayerName);
      return;
    }

    const compatibilityMessage = compatibleLayerMessage(targetLayer, missingRequiredFields(targetLayer));
    if (compatibilityMessage.length > 0) {
      appendDebugLog("save failed incompatible layer message=" + compatibilityMessage);
      iface.mainWindow().displayToast(compatibilityMessage);
      return;
    }

    if (!geometry) {
      appendDebugLog("save failed invalid geometry");
      iface.mainWindow().displayToast(
        measurementFrozen
          ? "No frozen GNSS position is available for this reading"
          : "No valid GNSS position available"
      );
      return;
    }

    if (isNaN(heading)) {
      appendDebugLog("save failed invalid heading");
      iface.mainWindow().displayToast("No valid heading available from the phone sensors");
      return;
    }

    if (isNaN(tilt)) {
      appendDebugLog("save failed invalid tilt");
      iface.mainWindow().displayToast("No valid tilt value available from the phone sensors");
      return;
    }

    appendDebugLog("save createBlankFeature begin layer=" + layerLabel);
    let feature = FeatureUtils.createBlankFeature(layerFieldsValue(targetLayer), geometry);
    appendDebugLog("save createBlankFeature ok layer=" + layerLabel);

    appendDebugLog("save set attributes begin layer=" + layerLabel);
    setAttributeIfPresent(feature, targetLayer, "mode", measurementKind);

    if (measurementKind === "linear") {
      setAttributeIfPresent(feature, targetLayer, "trend", heading);
      setAttributeIfPresent(feature, targetLayer, "plunge", tilt);
    } else {
      setAttributeIfPresent(feature, targetLayer, "dip_dir", heading);
      setAttributeIfPresent(feature, targetLayer, "dip_ang", tilt);
    }

    setAttributeIfPresent(feature, targetLayer, "kind", measurementKind);
    setAttributeIfPresent(feature, targetLayer, "azimuth", heading);
    setAttributeIfPresent(feature, targetLayer, "tilt", tilt);
    setAttributeIfPresent(feature, targetLayer, "sensor", currentSensorTag());
    setAttributeIfPresent(feature, targetLayer, "created_utc", new Date().toISOString());

    if (!isNaN(latitude)) {
      setAttributeIfPresent(feature, targetLayer, "latitude", latitude);
      setAttributeIfPresent(feature, targetLayer, "lat_wgs84", latitude);
    }

    if (!isNaN(longitude)) {
      setAttributeIfPresent(feature, targetLayer, "longitude", longitude);
      setAttributeIfPresent(feature, targetLayer, "lon_wgs84", longitude);
    }

    if (!isNaN(elevation)) {
      setAttributeIfPresent(feature, targetLayer, "elevation", elevation);
      setAttributeIfPresent(feature, targetLayer, "altitude", elevation);
    }
    appendDebugLog("save set attributes ok layer=" + layerLabel + " sensor=" + currentSensorTag());

    appendDebugLog("save persist begin layer=" + layerLabel);
    const persisted = persistFeatureToLayer(targetLayer, feature);
    if (!persisted.ok) {
      appendDebugLog("save failed persist message=" + persisted.message);
      iface.mainWindow().displayToast(persisted.message);
      return;
    }
    appendDebugLog("save persist ok layer=" + layerLabel);

    lastSavedLatitude = latitude;
    lastSavedLongitude = longitude;
    appendDebugLog(
      "save post-persist state lat=" + debugValue(lastSavedLatitude)
        + " lon=" + debugValue(lastSavedLongitude)
        + " frozen=" + measurementFrozen
        + " visible=" + compassVisible
    );
    clearFrozenMeasurement();
    appendDebugLog(
      "save clear frozen ok frozen=" + measurementFrozen
        + " saveReady=" + saveReady
        + " visible=" + compassVisible
    );
    appendDebugLog("save succeeded layer=" + layerLabel);
    iface.mainWindow().displayToast("Done.");
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

  function formatLatitude(value) {
    return Math.abs(value).toFixed(5) + " " + (value < 0 ? "S" : "N");
  }

  function formatLongitude(value) {
    return Math.abs(value).toFixed(5) + " " + (value < 0 ? "W" : "E");
  }

  function coordinateLabel() {
    const latitude = measurementFrozen ? frozenLatitude : positionLatitude(positionInfo);
    const longitude = measurementFrozen ? frozenLongitude : positionLongitude(positionInfo);
    const valid = measurementFrozen ? frozenPositionReady : livePositionReady;

    if (!valid) {
      return "Waiting for GNSS";
    }

    return formatLatitude(latitude) + ", " + formatLongitude(longitude);
  }

  function sensorSourceLabel() {
    return "Sources: heading " + headingSensorLabel() + " | tilt " + tiltSensorLabel();
  }

  function canSaveMeasurement() {
    return saveReady;
  }

  function saveButtonLabel() {
    if (saveReady) {
      return "Save";
    }

    if (measurementFrozen) {
      return "Need GNSS";
    }

    return "Freeze first";
  }

  function positionStatusLabel() {
    const info = positionInfo;
    let parts = [];

    if (measurementFrozen) {
      parts.push("Locked " + modeDisplayNameFor(lockedMode()));
      parts.push(orientationSummaryLabel(lockedMode(), frozenHeading, frozenTilt));
      parts.push(coordinateLabel());
      parts.push(saveReady ? "Ready to save" : "Not ready to save");
      return parts.join(" | ");
    }

    parts.push(livePositionReady ? "GNSS ready" : "GNSS unavailable");
    parts.push(isNaN(liveHeading) ? "Heading unavailable" : "Heading ready (" + headingSensorLabel() + ")");
    parts.push(isNaN(liveTilt) ? "Tilt unavailable" : "Tilt ready (" + tiltSensorLabel() + ")");
    parts.push("Live");

    return parts.join(" | ");
  }

  function freezeButtonLabel() {
    return measurementFrozen ? "Unlock reading" : "Freeze current reading";
  }

  Compass {
    id: compassSensor
    active: root.compassVisible

    onReadingChanged: {
      if (!reading) {
        return;
      }

      root.hasCompassReading = true;
      root.compassCalibrationLevel = reading.calibrationLevel;
      root.compassHeadingDeg = root.smoothAngle(
        root.compassHeadingDeg,
        root.normalizeAzimuth(reading.azimuth),
        0.25
      );
      root.updateRotationMapping();
    }
  }

  Accelerometer {
    id: accelerometerSensor
    active: root.compassVisible
    accelerationMode: Accelerometer.Gravity

    onReadingChanged: {
      if (!reading) {
        return;
      }

      root.hasAccelReading = true;
      root.accelX = root.smoothScalar(root.accelX, reading.x, 0.25);
      root.accelY = root.smoothScalar(root.accelY, reading.y, 0.25);
      root.accelZ = root.smoothScalar(root.accelZ, reading.z, 0.25);
      root.updateRotationMapping();
    }
  }

  Timer {
    interval: 200
    repeat: true
    running: root.compassVisible
    triggeredOnStart: true

    onTriggered: {
      root.updatePositioningFallbacks();
      root.updateRotationMapping();
    }
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

  Component.onCompleted: {
    seedTypeForMode();
    iface.addItemToPluginsToolbar(compassLauncher);
    requestDialPaints();
    appendDebugLog("plugin loaded projectPath=" + projectFilePath() + " projectDir=" + projectDirectoryPath());
    iface.mainWindow().displayToast("Geo compass plugin ready; log: " + debugLogFileName);
  }

  Component.onDestruction: {
    compassVisible = false;
    compassLauncher.visible = false;

    try {
      if (compassLauncher.parent) {
        compassLauncher.parent = null;
      }
    } catch (error) {
    }
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
              text: modeSubtitleLabel()
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
                text: sensorSourceLabel()
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
                  preventStealing: true
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
                  preventStealing: true
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

            Canvas {
              id: planarSymbolCanvas
              visible: activeMode === "planar"
              anchors.fill: mainDial
              rotation: isNaN(displayHeading) ? 0 : displayHeading
              antialiasing: true
              onVisibleChanged: requestPaint()
              onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = planarAccent;
                ctx.lineWidth = 7;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(width * 0.22, height * 0.56);
                ctx.lineTo(width * 0.78, height * 0.56);
                ctx.moveTo(width * 0.50, height * 0.56);
                ctx.lineTo(width * 0.50, height * 0.39);
                ctx.stroke();
              }
            }

            Canvas {
              id: linearSymbolCanvas
              visible: activeMode === "linear"
              anchors.fill: mainDial
              rotation: isNaN(displayHeading) ? 0 : displayHeading
              antialiasing: true
              onVisibleChanged: requestPaint()
              onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = linearAccent;
                ctx.lineWidth = 8;
                ctx.lineCap = "round";
                ctx.beginPath();
                ctx.moveTo(width * 0.50, height * 0.80);
                ctx.lineTo(width * 0.50, height * 0.30);
                ctx.stroke();

                ctx.fillStyle = linearAccent;
                ctx.beginPath();
                ctx.moveTo(width * 0.50, height * 0.17);
                ctx.lineTo(width * 0.60, height * 0.32);
                ctx.lineTo(width * 0.50, height * 0.28);
                ctx.lineTo(width * 0.40, height * 0.32);
                ctx.closePath();
                ctx.fill();
              }
            }

            Canvas {
              id: planarGuideCanvas
              visible: activeMode === "planar"
              anchors.fill: mainDial
              antialiasing: true
              onVisibleChanged: requestPaint()
              onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = "#b9b9b9";
                ctx.lineWidth = 1.2;
                ctx.beginPath();
                ctx.moveTo(width * 0.08, height * 0.62);
                ctx.quadraticCurveTo(width * 0.54, height * 0.96, width * 0.92, height * 0.44);
                ctx.stroke();
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

              Canvas {
                id: headingMarkerCanvas
                anchors.fill: parent
                rotation: isNaN(displayHeading) ? 0 : displayHeading
                antialiasing: true
                onPaint: {
                  const ctx = getContext("2d");
                  ctx.reset();
                  ctx.fillStyle = activeAccent;
                  ctx.beginPath();
                  ctx.moveTo(width * 0.50, 8);
                  ctx.lineTo(width * 0.57, 24);
                  ctx.lineTo(width * 0.50, 21);
                  ctx.lineTo(width * 0.43, 24);
                  ctx.closePath();
                  ctx.fill();
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
              spacing: 18

              Text {
                width: 124
                text: tiltDisplayLabel()
                color: textMuted
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
              }

              Text {
                width: 124
                text: headingDisplayLabel()
                color: textMuted
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
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
              width: parent.width - 12
              text: readoutBannerLabel()
              color: "white"
              font.pixelSize: measurementFrozen ? 16 : 21
              font.bold: true
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
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
              preventStealing: true
              onClicked: {
                if (root.measurementFrozen) {
                  root.clearFrozenMeasurement();
                  iface.mainWindow().displayToast("Live sensor readout resumed");
                } else {
                  root.freezeMeasurement();
                }
              }
            }
          }

          Rectangle {
            width: 320
            height: 60
            z: 5
            radius: 10
            color: saveReady ? saveBg : "#cfd8cf"
            border.color: saveReady ? "#9f1117" : "#aab5aa"
            border.width: 1
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
              anchors.centerIn: parent
              text: saveButtonLabel()
              color: saveReady ? saveText : "#eff3ef"
              font.pixelSize: 24
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              z: 10
              enabled: true
              preventStealing: true
              onPressed: {
                mouse.accepted = true;
                root.saveMeasurement(root.activeMode);
              }
            }
          }

          Rectangle {
            width: 320
            height: 48
            radius: 8
            color: "#7a7a7a"
            border.color: "#676767"
            border.width: 1
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
              anchors.centerIn: parent
              text: "Back to map"
              color: "white"
              font.pixelSize: 18
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              preventStealing: true
              onClicked: root.closeCompass()
            }
          }

          Text {
            width: 330
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: positionStatusLabel()
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
            text: "Plugin " + pluginVersionLabel
            color: textMuted
            font.pixelSize: 11
          }

          Rectangle {
            width: 330
            radius: 10
            color: "#efeee9"
            border.color: "#d2d0c7"
            border.width: 1
            anchors.horizontalCenter: parent.horizontalCenter
            implicitHeight: sensorDebugColumn.implicitHeight + 16

            Column {
              id: sensorDebugColumn
              width: parent.width - 20
              anchors.centerIn: parent
              spacing: 4

              Text {
                width: parent.width
                text: "Live sensor readout"
                color: textPrimary
                font.pixelSize: 15
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
              }

              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: sensorSourceSummaryLabel()
                color: textMuted
                font.pixelSize: 12
              }

              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: sensorDebugMultilineLabel()
                color: textPrimary
                font.pixelSize: 14
              }

              Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: sensorGuidanceLabel()
                color: textMuted
                font.pixelSize: 12
              }
            }
          }

          Text {
            width: 330
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Raw values: " + sensorDebugLabel()
            color: textMuted
            font.pixelSize: 11
          }
        }
      }
    }
  }
}
