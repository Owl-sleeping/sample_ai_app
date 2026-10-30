import 'dart:math' as math;

enum GpsMovementStatus { waiting, moving, stationary, inaccurate }

class GpsMovementResult {
  const GpsMovementResult({
    required this.status,
    this.speedMetersPerSecond,
    this.accuracyMeters,
  });

  final GpsMovementStatus status;
  final double? speedMetersPerSecond;
  final double? accuracyMeters;
}

class LocationMovementChecker {
  static const maxAccuracyMeters = 25.0;
  static const movingSpeedMetersPerSecond = 0.8;
  static const stationarySpeedMetersPerSecond = 0.3;

  _LocationFix? _previousFix;
  var _movingReadings = 0;
  var _stationaryReadings = 0;

  void reset() {
    _previousFix = null;
    _movingReadings = 0;
    _stationaryReadings = 0;
  }

  GpsMovementResult update({
    required double latitude,
    required double longitude,
    required double? accuracyMeters,
    required double? speedMetersPerSecond,
    required double timestampMilliseconds,
  }) {
    if (accuracyMeters == null ||
        !accuracyMeters.isFinite ||
        accuracyMeters > maxAccuracyMeters ||
        !latitude.isFinite ||
        !longitude.isFinite) {
      _previousFix = null;
      _movingReadings = 0;
      _stationaryReadings = 0;
      return GpsMovementResult(
        status: GpsMovementStatus.inaccurate,
        accuracyMeters: accuracyMeters,
      );
    }

    final previous = _previousFix;
    var measuredSpeed = speedMetersPerSecond;
    if (measuredSpeed == null || !measuredSpeed.isFinite || measuredSpeed < 0) {
      measuredSpeed = null;
      if (previous != null) {
        final elapsedSeconds =
            (timestampMilliseconds - previous.timestampMilliseconds) / 1000;
        if (elapsedSeconds > 0 && elapsedSeconds <= 30) {
          final distance = _distanceMeters(
            previous.latitude,
            previous.longitude,
            latitude,
            longitude,
          );
          final uncertaintyDistance = previous.accuracyMeters + accuracyMeters;
          if (distance > math.max(5.0, uncertaintyDistance)) {
            measuredSpeed = distance / elapsedSeconds;
          }
        }
      }
    }

    _previousFix = _LocationFix(
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      timestampMilliseconds: timestampMilliseconds,
    );

    if (measuredSpeed == null) {
      _movingReadings = 0;
      _stationaryReadings = 0;
      return GpsMovementResult(
        status: GpsMovementStatus.waiting,
        accuracyMeters: accuracyMeters,
      );
    }

    if (measuredSpeed >= movingSpeedMetersPerSecond) {
      _movingReadings++;
      _stationaryReadings = 0;
      return GpsMovementResult(
        status: _movingReadings >= 2
            ? GpsMovementStatus.moving
            : GpsMovementStatus.waiting,
        speedMetersPerSecond: measuredSpeed,
        accuracyMeters: accuracyMeters,
      );
    }

    if (measuredSpeed <= stationarySpeedMetersPerSecond) {
      _stationaryReadings++;
      _movingReadings = 0;
      return GpsMovementResult(
        status: _stationaryReadings >= 3
            ? GpsMovementStatus.stationary
            : GpsMovementStatus.waiting,
        speedMetersPerSecond: measuredSpeed,
        accuracyMeters: accuracyMeters,
      );
    }

    _movingReadings = 0;
    _stationaryReadings = 0;
    return GpsMovementResult(
      status: GpsMovementStatus.waiting,
      speedMetersPerSecond: measuredSpeed,
      accuracyMeters: accuracyMeters,
    );
  }

  double _distanceMeters(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusMeters = 6371000.0;
    final latitudeDelta = _toRadians(latitude2 - latitude1);
    final longitudeDelta = _toRadians(longitude2 - longitude1);
    final a =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(_toRadians(latitude1)) *
            math.cos(_toRadians(latitude2)) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    final boundedA = a.clamp(0.0, 1.0).toDouble();
    return earthRadiusMeters *
        2 *
        math.atan2(math.sqrt(boundedA), math.sqrt(1 - boundedA));
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
}

class _LocationFix {
  const _LocationFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestampMilliseconds,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double timestampMilliseconds;
}
