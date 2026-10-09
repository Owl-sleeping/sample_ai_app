import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'web_sensor_reader_stub.dart'
    if (dart.library.js_interop) 'web_sensor_reader_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'センサー確認',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const SensorPage(),
    );
  }
}

class SensorPage extends StatefulWidget {
  const SensorPage({super.key});

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  StreamSubscription<AccelerometerEvent>? _subscription;
  StreamSubscription<WebSensorData>? _webSubscription;
  WebSensorReader? _webReader;
  double? _x;
  double? _y;
  double? _z;
  double? _alpha;
  double? _beta;
  double? _gamma;
  double? _latitude;
  double? _longitude;
  double? _accuracy;
  String? _error;
  bool _isListening = false;

  Future<void> _startListening() async {
    setState(() {
      _error = null;
      _isListening = true;
    });

    if (kIsWeb) {
      final reader = WebSensorReader();
      _webReader = reader;
      _webSubscription = reader.values.listen(
        (data) {
          if (!mounted) return;
          setState(() {
            if (data.alpha != null || data.beta != null || data.gamma != null) {
              _alpha = data.alpha;
              _beta = data.beta;
              _gamma = data.gamma;
            }
            if (data.accelerationX != null ||
                data.accelerationY != null ||
                data.accelerationZ != null) {
              _x = data.accelerationX;
              _y = data.accelerationY;
              _z = data.accelerationZ;
            }
            if (data.latitude != null ||
                data.longitude != null ||
                data.accuracy != null) {
              _latitude = data.latitude;
              _longitude = data.longitude;
              _accuracy = data.accuracy;
            }
          });
        },
        onError: (Object error) {
          if (!mounted) return;
          setState(() => _error = '位置情報を取得できませんでした: $error');
        },
      );
      try {
        reader.start().catchError((Object error) {
          if (!mounted) return;
          setState(() {
            _error = error.toString();
            _isListening = false;
          });
          _webReader?.stop();
        });
      } catch (error) {
        setState(() => _error = 'ブラウザーAPIを開始できませんでした: $error');
      }
      return;
    }

    _subscription = accelerometerEventStream().listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _x = event.x;
          _y = event.y;
          _z = event.z;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = 'センサーを読み取れませんでした: $error';
          _isListening = false;
        });
      },
      cancelOnError: true,
    );
  }

  Future<void> _stopListening() async {
    _webReader?.stop();
    _webReader = null;
    await _webSubscription?.cancel();
    _webSubscription = null;
    await _subscription?.cancel();
    _subscription = null;
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _webReader?.stop();
    _webSubscription?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(kIsWeb ? 'F12センサー確認' : '加速度センサー'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(kIsWeb ? Icons.sensors : Icons.screen_rotation, size: 48),
              const SizedBox(height: 12),
              Text(
                _isListening
                    ? kIsWeb
                        ? 'F12の値を読み取り中'
                        : 'センサーを読み取り中'
                    : '計測を開始してください',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              if (kIsWeb) ...[
                _SensorValue(label: 'X', value: _x, unit: 'm/s²'),
                _SensorValue(label: 'Y', value: _y, unit: 'm/s²'),
                _SensorValue(label: 'Z', value: _z, unit: 'm/s²'),
                const SizedBox(height: 8),
                _SensorValue(label: 'α', value: _alpha, unit: '°'),
                _SensorValue(label: 'β', value: _beta, unit: '°'),
                _SensorValue(label: 'γ', value: _gamma, unit: '°'),
                const SizedBox(height: 8),
                _SensorValue(
                  label: '緯度',
                  value: _latitude,
                  unit: '°',
                  decimals: 6,
                ),
                _SensorValue(
                  label: '経度',
                  value: _longitude,
                  unit: '°',
                  decimals: 6,
                ),
                _SensorValue(
                  label: '精度',
                  value: _accuracy,
                  unit: 'm',
                  decimals: 1,
                ),
                const SizedBox(height: 12),
                Text(
                  'F12 → Ctrl+Shift+P →「Show Sensors」→ Orientation / Location を設定',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '位置情報はブラウザーの許可が必要です。localhostで開いてください。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ] else ...[
                _SensorValue(label: 'X', value: _x, unit: 'm/s²'),
                _SensorValue(label: 'Y', value: _y, unit: 'm/s²'),
                _SensorValue(label: 'Z', value: _z, unit: 'm/s²'),
                const SizedBox(height: 12),
                Text(
                  '単位: m/s²（重力を含む値）',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _isListening ? _stopListening : _startListening,
                icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
                label: Text(_isListening ? '計測を停止' : '計測を開始'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SensorValue extends StatelessWidget {
  const _SensorValue({
    required this.label,
    required this.value,
    required this.unit,
    this.decimals = 3,
  });

  final String label;
  final double? value;
  final String unit;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text(label)),
        title: Text(
          value == null ? '--' : value!.toStringAsFixed(decimals),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        trailing: Text(unit),
      ),
    );
  }
}
