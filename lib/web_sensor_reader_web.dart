import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('DeviceMotionEvent.requestPermission')
external JSPromise<JSString> _requestDeviceMotionPermission();

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
  final StreamController<WebSensorData> _values =
      StreamController<WebSensorData>.broadcast();

  web.EventListener? _orientationListener;
  web.EventListener? _motionListener;
  web.PositionCallback? _positionListener;
  web.PositionErrorCallback? _positionErrorListener;
  int? _positionWatchId;

  Stream<WebSensorData> get values => _values.stream;

  Future<void> start() async {
    if (!web.window.isSecureContext) {
      throw StateError('Sensor access requires HTTPS. Open this app using an HTTPS URL.');
    }

    final userAgent = web.window.navigator.userAgent.toLowerCase();
    final platform = web.window.navigator.platform.toLowerCase();
    final isAppleMobile = userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod') ||
        (platform == 'macintel' && web.window.navigator.maxTouchPoints > 1);
    if (isAppleMobile) {
      final permission = await _requestDeviceMotionPermission().toDart;
      if (permission.toDart != 'granted') {
        throw StateError('Motion sensor permission was not granted.');
      }
    }

    _orientationListener = ((web.Event event) {
      final orientation = event as web.DeviceOrientationEvent;
      _values.add(WebSensorData(
        alpha: orientation.alpha,
        beta: orientation.beta,
        gamma: orientation.gamma,
      ));
    }).toJS;
    web.window.addEventListener('deviceorientation', _orientationListener);

    _motionListener = ((web.Event event) {
      final motion = event as web.DeviceMotionEvent;
      final acceleration =
          motion.accelerationIncludingGravity ?? motion.acceleration;
      if (acceleration == null) return;
      _values.add(WebSensorData(
        accelerationX: acceleration.x,
        accelerationY: acceleration.y,
        accelerationZ: acceleration.z,
        interval: motion.interval,
      ));
    }).toJS;
    web.window.addEventListener('devicemotion', _motionListener);

    _positionListener = ((web.GeolocationPosition position) {
      final coordinates = position.coords;
      _values.add(WebSensorData(
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
        accuracy: coordinates.accuracy,
      ));
    }).toJS;
    _positionErrorListener = ((web.GeolocationPositionError error) {
      _values.addError(Exception(error.message));
    }).toJS;

    _positionWatchId = web.window.navigator.geolocation.watchPosition(
      _positionListener!,
      _positionErrorListener,
      web.PositionOptions(
        enableHighAccuracy: false,
        maximumAge: 0,
        timeout: 10000,
      ),
    );
  }

  void stop() {
    final motionListener = _motionListener;
    if (motionListener != null) {
      web.window.removeEventListener('devicemotion', motionListener);
      _motionListener = null;
    }

    final listener = _orientationListener;
    if (listener != null) {
      web.window.removeEventListener('deviceorientation', listener);
      _orientationListener = null;
    }

    final watchId = _positionWatchId;
    if (watchId != null) {
      web.window.navigator.geolocation.clearWatch(watchId);
      _positionWatchId = null;
    }
    _positionListener = null;
    _positionErrorListener = null;
  }
}
