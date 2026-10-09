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
    this.latitude,
    this.longitude,
    this.accuracy,
  });

  final double? alpha;
  final double? beta;
  final double? gamma;
  final double? accelerationX;
  final double? accelerationY;
  final double? accelerationZ;
  final double? interval;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
}

class WebSensorReader {
  Stream<WebSensorData> get values => const Stream.empty();

  Future<void> start() async {}

  void stop() {}
}
