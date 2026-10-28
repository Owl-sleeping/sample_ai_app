import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

class ActivityPrediction {
  const ActivityPrediction({
    required this.label,
    required this.confidence,
    required this.probabilities,
  });

  final String label;
  final double confidence;
  final Map<String, double> probabilities;
}

class _AccelerationPoint {
  const _AccelerationPoint(this.timeMs, this.magnitude);

  final double timeMs;
  final double magnitude;
}

class _DecisionTree {
  const _DecisionTree({
    required this.left,
    required this.right,
    required this.feature,
    required this.threshold,
    required this.values,
  });

  final List<int> left;
  final List<int> right;
  final List<int> feature;
  final List<double> threshold;
  final List<List<double>> values;

  factory _DecisionTree.fromJson(Map<String, dynamic> json) {
    return _DecisionTree(
      left: (json['left'] as List).cast<int>(),
      right: (json['right'] as List).cast<int>(),
      feature: (json['feature'] as List).cast<int>(),
      threshold: (json['threshold'] as List)
          .map((value) => (value as num).toDouble())
          .toList(growable: false),
      values: (json['values'] as List)
          .map(
            (row) => (row as List)
                .map((value) => (value as num).toDouble())
                .toList(growable: false),
          )
          .toList(growable: false),
    );
  }

  List<double> predict(List<double> features) {
    var node = 0;
    while (left[node] != right[node]) {
      final featureIndex = feature[node];
      node = features[featureIndex] <= threshold[node]
          ? left[node]
          : right[node];
    }
    return values[node];
  }
}

/// Runs the notebook's 1-second Random Forest on live acceleration samples.
/// Features are magnitude standard deviation, range, and mean absolute change.
class ActivityModel {
  ActivityModel._({
    required this.classes,
    required this.windowMs,
    required this.updateMs,
    required this.trees,
  });

  static const assetPath = 'assets/activity_model.json';

  final List<String> classes;
  final double windowMs;
  final double updateMs;
  final List<_DecisionTree> trees;

  final List<_AccelerationPoint> _points = [];
  double? _firstSampleMs;
  double? _lastPredictionMs;

  static Future<ActivityModel> load() async {
    final json =
        jsonDecode(await rootBundle.loadString(assetPath))
            as Map<String, dynamic>;
    return ActivityModel._(
      classes: (json['classes'] as List).cast<String>(),
      windowMs: (json['window_seconds'] as num).toDouble() * 1000,
      updateMs: (json['update_seconds'] as num).toDouble() * 1000,
      trees: (json['trees'] as List)
          .map((tree) => _DecisionTree.fromJson(tree as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  void reset() {
    _points.clear();
    _firstSampleMs = null;
    _lastPredictionMs = null;
  }

  ActivityPrediction? addSample({
    required double timeMs,
    required double x,
    required double y,
    required double z,
  }) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    _firstSampleMs ??= timeMs;
    _points.add(_AccelerationPoint(timeMs, magnitude));

    final oldestToKeep = timeMs - windowMs - updateMs;
    _points.removeWhere((point) => point.timeMs < oldestToKeep);

    if (timeMs - _firstSampleMs! < windowMs ||
        (_lastPredictionMs != null && timeMs - _lastPredictionMs! < updateMs)) {
      return null;
    }

    final windowStart = timeMs - windowMs;
    final window = _points
        .where((point) => point.timeMs >= windowStart)
        .toList(growable: false);
    if (window.length < 20) return null;

    final magnitudes = window.map((point) => point.magnitude).toList();
    final mean = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
    var squaredDifferenceSum = 0.0;
    var minimum = magnitudes.first;
    var maximum = magnitudes.first;
    var changeSum = 0.0;
    for (var index = 0; index < magnitudes.length; index++) {
      final value = magnitudes[index];
      squaredDifferenceSum += (value - mean) * (value - mean);
      minimum = math.min(minimum, value);
      maximum = math.max(maximum, value);
      if (index > 0) {
        changeSum += (value - magnitudes[index - 1]).abs();
      }
    }
    final features = <double>[
      math.sqrt(squaredDifferenceSum / magnitudes.length),
      maximum - minimum,
      changeSum / (magnitudes.length - 1),
    ];

    final probabilities = List<double>.filled(classes.length, 0);
    for (final tree in trees) {
      final treeProbabilities = tree.predict(features);
      for (var index = 0; index < probabilities.length; index++) {
        probabilities[index] += treeProbabilities[index];
      }
    }
    for (var index = 0; index < probabilities.length; index++) {
      probabilities[index] /= trees.length;
    }

    var bestIndex = 0;
    for (var index = 1; index < probabilities.length; index++) {
      if (probabilities[index] > probabilities[bestIndex]) {
        bestIndex = index;
      }
    }
    _lastPredictionMs = timeMs;

    return ActivityPrediction(
      label: classes[bestIndex],
      confidence: probabilities[bestIndex],
      probabilities: {
        for (var index = 0; index < classes.length; index++)
          classes[index]: probabilities[index],
      },
    );
  }
}
