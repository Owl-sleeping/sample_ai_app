import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'activity_model.dart';
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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openPage(BuildContext context, SensorPageMode mode) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SensorPage(mode: mode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('センサーアプリ')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                '計測または行動予測を選択してください',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.sensors, size: 36),
                  title: const Text('加速度を計測する'),
                  subtitle: const Text('センサー値を表示し、CSVに記録します'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openPage(context, SensorPageMode.measurement),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.directions_run, size: 36),
                  title: const Text('行動を予測する'),
                  subtitle: const Text('静止・歩行・走行をリアルタイム表示します（試験中）'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openPage(context, SensorPageMode.prediction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum SensorPageMode { measurement, prediction }

class SensorPage extends StatefulWidget {
  const SensorPage({super.key, required this.mode});

  final SensorPageMode mode;

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  bool get _isPredictionMode => widget.mode == SensorPageMode.prediction;

  late final Future<ActivityModel> _activityModelFuture = ActivityModel.load();
  final Stopwatch _classificationClock = Stopwatch();
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
  ActivityModel? _activityModel;
  ActivityPrediction? _activityPrediction;
  String? _error;
  bool _isListening = false;
  final List<AccelerationSample> _samples = [];
  DateTime? _recordingStartedAt;
  double? _firstEventElapsedMs;

  Future<void> _startListening() async {
    if (_isPredictionMode) {
      late final ActivityModel model;
      try {
        model = await _activityModelFuture;
      } catch (error) {
        if (!mounted) return;
        setState(() => _error = '行動判定モデルを読み込めませんでした: $error');
        return;
      }

      _activityModel = model;
      model.reset();
    } else {
      _activityModel = null;
    }

    _classificationClock
      ..reset()
      ..start();
    setState(() {
      _error = null;
      _isListening = true;
      _activityPrediction = null;
      _samples.clear();
      _recordingStartedAt = DateTime.now();
      _firstEventElapsedMs = null;
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
            if (data.accelerationX != null || data.accelerationY != null || data.accelerationZ != null) {
              _x = data.accelerationX;
              _y = data.accelerationY;
              _z = data.accelerationZ;

              if (data.accelerationX != null && data.accelerationY != null && data.accelerationZ != null) {
                final elapsedMs = data.elapsedMs;
                _firstEventElapsedMs ??= elapsedMs;
                if (_isPredictionMode) {
                  final prediction = _activityModel?.addSample(
                    timeMs: _classificationClock.elapsedMicroseconds / 1000.0,
                    x: data.accelerationX!,
                    y: data.accelerationY!,
                    z: data.accelerationZ!,
                  );
                  if (prediction != null) _activityPrediction = prediction;
                } else {
                  _samples.add(AccelerationSample(
                    timestamp: DateTime.now().toIso8601String(),
                    elapsedMs: elapsedMs != null && _firstEventElapsedMs != null
                        ? elapsedMs - _firstEventElapsedMs!
                        : 0,
                    intervalMs: data.interval ?? 0,
                    x: data.accelerationX!,
                    y: data.accelerationY!,
                    z: data.accelerationZ!,
                  ));
                }
              }
            }
            if (data.latitude != null || data.longitude != null || data.accuracy != null) {
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
          _classificationClock.stop();
          _webReader?.stop();
        });
      } catch (error) {
        setState(() {
          _error = 'APIを開始できませんでした: $error';
          _isListening = false;
        });
        _classificationClock.stop();
        reader.stop();
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
          if (_isPredictionMode) {
            final prediction = _activityModel?.addSample(
              timeMs: _classificationClock.elapsedMicroseconds / 1000.0,
              x: event.x,
              y: event.y,
              z: event.z,
            );
            if (prediction != null) _activityPrediction = prediction;
          }
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = 'センサーを読み取れませんでした: $error';
          _isListening = false;
        });
        _classificationClock.stop();
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
    _classificationClock.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
  }

  Future<void> _resetMeasurement() async {
    await _stopListening();
    if (!mounted) return;
    setState(() {
      _samples.clear();
      _activityModel?.reset();
      _activityPrediction = null;
      _recordingStartedAt = null;
      _firstEventElapsedMs = null;
      _x = null;
      _y = null;
      _z = null;
      _alpha = null;
      _beta = null;
      _gamma = null;
      _latitude = null;
      _longitude = null;
      _accuracy = null;
      _error = null;
    });
  }

  Future<void> _downloadCsv() async {
    if (_samples.isEmpty) return;

    final startedAt = _recordingStartedAt ?? DateTime.now();
    final defaultFilename = 'acceleration_${startedAt.year}'
        '${startedAt.month.toString().padLeft(2, '0')}'
        '${startedAt.day.toString().padLeft(2, '0')}_'
        '${startedAt.hour.toString().padLeft(2, '0')}'
        '${startedAt.minute.toString().padLeft(2, '0')}'
        '${startedAt.second.toString().padLeft(2, '0')}';
    final filenameController = TextEditingController(text: defaultFilename);
    final enteredFilename = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CSVファイル名'),
        content: TextField(
          controller: filenameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'ファイル名',
            suffixText: '.csv',
            hintText: '例: walking_01',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(filenameController.text),
            child: const Text('ダウンロード'),
          ),
        ],
      ),
    );
    filenameController.dispose();
    if (enteredFilename == null) return;

    var filename = enteredFilename.trim();
    if (filename.toLowerCase().endsWith('.csv')) {
      filename = filename.substring(0, filename.length - 4);
    }
    filename = filename
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'[. ]+$'), '')
        .trim();
    if (filename.isEmpty) filename = defaultFilename;

    final lines = <String>[
      'timestamp_local,elapsed_ms,event_interval_ms,x_m_s2,y_m_s2,z_m_s2',
      ..._samples.map((sample) => [
            sample.timestamp,
            sample.elapsedMs.toStringAsFixed(3),
            sample.intervalMs.toStringAsFixed(3),
            sample.x.toStringAsFixed(6),
            sample.y.toStringAsFixed(6),
            sample.z.toStringAsFixed(6),
          ].join(',')),
    ];
    downloadSensorCsv('\uFEFF${lines.join('\r\n')}\r\n', '$filename.csv');
  }

  @override
  void dispose() {
    _classificationClock.stop();
    _webReader?.stop();
    _webSubscription?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isPredictionMode ? '行動予測（試験中）' : '加速度の計測',
        ),
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
                        ? _isPredictionMode
                            ? 'センサー値を読み取り、行動を判定中'
                            : 'F12でセンサー値を読み取り中'
                        : 'センサー値を読み取り中'
                    : _isPredictionMode
                        ? '予測を開始してください'
                        : '計測を開始してください',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              if (_isPredictionMode) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          '現在の行動',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _activityPrediction?.label ??
                              (_isListening ? '判定データを収集中…' : '未計測'),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        if (_activityPrediction != null)
                          Text(
                            'モデルの投票割合 ${(_activityPrediction!.confidence * 100).toStringAsFixed(0)}%',
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '1秒窓を0.25秒ごとに更新',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                _SensorValue(label: 'X', value: _x, unit: 'm/s²'),
                _SensorValue(label: 'Y', value: _y, unit: 'm/s²'),
                _SensorValue(label: 'Z', value: _z, unit: 'm/s²'),
              ] else if (kIsWeb) ...[
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
                  'F12 → Ctrl+Shift+P →「Show Sensors」で Orientation / Location を設定',
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
                  '単位はm/s²です（重力を含む値）',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (!_isPredictionMode && kIsWeb && _samples.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('記録サンプル数: ${_samples.length}'),
                Text(
                  'イベント間隔: ${_samples.last.intervalMs.toStringAsFixed(1)} ms',
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _downloadCsv,
                  icon: const Icon(Icons.download),
                  label: const Text('CSVをダウンロード'),
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
                label: Text(
                  _isListening
                      ? '停止'
                      : _isPredictionMode
                          ? '行動予測を開始'
                          : '計測を開始',
                ),
              ),
              if (!_isPredictionMode && kIsWeb && _samples.isNotEmpty) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _resetMeasurement,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('計測をリセット'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AccelerationSample {
  const AccelerationSample({
    required this.timestamp,
    required this.elapsedMs,
    required this.intervalMs,
    required this.x,
    required this.y,
    required this.z,
  });

  final String timestamp;
  final double elapsedMs;
  final double intervalMs;
  final double x;
  final double y;
  final double z;
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
