import 'dart:async';

class WebSensorData {
  const WebSensorData({
    this.alpha,
    this.beta,
    this.gamma,
    this.accelerationX,
    this.accelerationY,
    this.accelerationZ,
    this.interval,
    this.elapsedMs,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.speedMetersPerSecond,
    this.positionTimestampMs,
  });

  final double? alpha;
  final double? beta;
  final double? gamma;
  final double? accelerationX;
  final double? accelerationY;
  final double? accelerationZ;
  final double? interval;
  final double? elapsedMs;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? speedMetersPerSecond;
  final double? positionTimestampMs;
}

class WebSensorReader {
  Stream<WebSensorData> get values => const Stream.empty();

  Future<void> start() async {}

  void stop() {}
}

void downloadSensorCsv(String contents, String filename) {}
