import 'dart:typed_data';
import 'fir_filter.dart';
import 'stroke_classifier.dart';
import 'lap_detector.dart';
import 'metrics_calculator.dart';

/// 生センサーデータ
class SensorReading {
  final double timestamp;
  final double accX, accY, accZ;
  final double gyroX, gyroY, gyroZ;

  SensorReading({
    required this.timestamp,
    required this.accX,
    required this.accY,
    required this.accZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
  });

  factory SensorReading.fromMap(Map<String, dynamic> map) {
    return SensorReading(
      timestamp: (map['timestamp'] as num).toDouble(),
      accX: (map['acc_x'] as num).toDouble(),
      accY: (map['acc_y'] as num).toDouble(),
      accZ: (map['acc_z'] as num).toDouble(),
      gyroX: (map['gyro_x'] as num?)?.toDouble() ?? 0.0,
      gyroY: (map['gyro_y'] as num?)?.toDouble() ?? 0.0,
      gyroZ: (map['gyro_z'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'acc_x': accX,
      'acc_y': accY,
      'acc_z': accZ,
      'gyro_x': gyroX,
      'gyro_y': gyroY,
      'gyro_z': gyroZ,
    };
  }
}

/// ラップ解析結果
class LapResult {
  final int lapNumber;
  final StrokeType strokeType;
  final double confidence;
  final double durationSeconds;
  final int strokeCount;
  final int swolf;
  final double pacePerHundred;
  final double strokeRate;
  final int startIndex;
  final int endIndex;

  LapResult({
    required this.lapNumber,
    required this.strokeType,
    required this.confidence,
    required this.durationSeconds,
    required this.strokeCount,
    required this.swolf,
    required this.pacePerHundred,
    required this.strokeRate,
    required this.startIndex,
    required this.endIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'lap_number': lapNumber,
      'stroke_type': strokeType.english,
      'confidence': confidence,
      'duration_seconds': durationSeconds,
      'stroke_count': strokeCount,
      'swolf': swolf,
      'pace_per_100m': pacePerHundred,
      'stroke_rate': strokeRate,
    };
  }
}

/// セッション全体の解析結果
class AnalysisResult {
  final String sessionId;
  final DateTime analyzedAt;
  final int poolLength;
  final int totalLaps;
  final int totalDistance;
  final Duration totalDuration;
  final List<LapResult> laps;
  final double averageSwolf;
  final double averagePace;
  final double averageStrokeRate;
  final Map<StrokeType, int> strokeDistribution;
  final double estimatedCalories;

  AnalysisResult({
    required this.sessionId,
    required this.analyzedAt,
    required this.poolLength,
    required this.totalLaps,
    required this.totalDistance,
    required this.totalDuration,
    required this.laps,
    required this.averageSwolf,
    required this.averagePace,
    required this.averageStrokeRate,
    required this.strokeDistribution,
    required this.estimatedCalories,
  });

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'analyzed_at': analyzedAt.toIso8601String(),
      'pool_length': poolLength,
      'total_laps': totalLaps,
      'total_distance': totalDistance,
      'total_duration_seconds': totalDuration.inSeconds,
      'average_swolf': averageSwolf,
      'average_pace': averagePace,
      'average_stroke_rate': averageStrokeRate,
      'stroke_distribution': strokeDistribution.map(
        (k, v) => MapEntry(k.english, v),
      ),
      'estimated_calories': estimatedCalories,
      'laps': laps.map((l) => l.toMap()).toList(),
    };
  }
}

/// SwimBIT解析エンジン
/// センサーデータからラップ・ストローク・効率指標を算出
class AnalysisEngine {
  final SwimBITFilter _filter;
  final LapDetector _lapDetector;
  final StrokeClassifier _classifier;
  final MetricsCalculator _metricsCalc;
  final int poolLength;
  final double userWeightKg;

  AnalysisEngine({
    this.poolLength = 25,
    this.userWeightKg = 70.0,
    SwimBITFilter? filter,
    LapDetector? lapDetector,
    StrokeClassifier? classifier,
    MetricsCalculator? metricsCalc,
  })  : _filter = filter ?? SwimBITFilter(),
        _lapDetector = lapDetector ?? LapDetector(),
        _classifier = classifier ?? StrokeClassifier(),
        _metricsCalc = metricsCalc ?? MetricsCalculator();

  /// メイン解析処理
  Future<AnalysisResult> analyze({
    required String sessionId,
    required List<SensorReading> rawData,
  }) async {
    if (rawData.isEmpty) {
      throw ArgumentError('Empty sensor data');
    }

    // 1. データを軸ごとに分離
    final accX = Float64List.fromList(rawData.map((r) => r.accX).toList());
    final accY = Float64List.fromList(rawData.map((r) => r.accY).toList());
    final accZ = Float64List.fromList(rawData.map((r) => r.accZ).toList());
    final timestamps = rawData.map((r) => r.timestamp).toList();

    // 2. フィルタリング（ゼロ位相フィルタ）
    final filteredX = _filter.applyZeroPhase(accX);
    final filteredY = _filter.applyZeroPhase(accY);
    final filteredZ = _filter.applyZeroPhase(accZ);

    // 3. ラップ検出
    final lapBoundaries = _lapDetector.detect(
      accX: filteredX,
      accY: filteredY,
      accZ: filteredZ,
      timestamps: timestamps,
    );

    // 4. 各ラップを解析
    final laps = <LapResult>[];
    final strokeDistribution = <StrokeType, int>{};

    for (int i = 0; i < lapBoundaries.length - 1; i++) {
      final start = lapBoundaries[i];
      final end = lapBoundaries[i + 1];

      if (end <= start) continue;

      // ラップデータを抽出
      final lapAccX = Float64List.sublistView(filteredX, start, end);
      final lapAccY = Float64List.sublistView(filteredY, start, end);
      final lapAccZ = Float64List.sublistView(filteredZ, start, end);

      // ストローク分類（信頼度付き）
      final classResult = _classifier.classifyWithConfidence(
        accX: lapAccX,
        accY: lapAccY,
        accZ: lapAccZ,
      );

      // ストロークカウント
      final strokeCount = _metricsCalc.countStrokes(lapAccY);

      // ストロークレート
      final strokeRate = _metricsCalc.estimateStrokeRate(lapAccY);

      // 時間計算
      final duration = timestamps[end - 1] - timestamps[start];

      // SWOLF計算
      final swolf = _metricsCalc.calculateSwolf(
        durationSeconds: duration,
        strokeCount: strokeCount,
      );

      // ペース計算 (100mあたりの秒数)
      final pacePerHundred = _metricsCalc.calculatePace(
        durationSeconds: duration,
        distance: poolLength,
      );

      laps.add(LapResult(
        lapNumber: i + 1,
        strokeType: classResult.strokeType,
        confidence: classResult.confidence,
        durationSeconds: duration,
        strokeCount: strokeCount,
        swolf: swolf,
        pacePerHundred: pacePerHundred,
        strokeRate: strokeRate,
        startIndex: start,
        endIndex: end,
      ));

      // 泳法分布を集計
      strokeDistribution[classResult.strokeType] =
          (strokeDistribution[classResult.strokeType] ?? 0) + 1;
    }

    // 5. サマリー統計を計算
    final totalDuration = Duration(
      milliseconds: ((timestamps.last - timestamps.first) * 1000).round(),
    );

    final swimmingLaps =
        laps.where((l) => l.strokeType != StrokeType.rest).toList();

    final averageSwolf = swimmingLaps.isEmpty
        ? 0.0
        : swimmingLaps.map((l) => l.swolf).reduce((a, b) => a + b) /
            swimmingLaps.length;

    final averagePace = swimmingLaps.isEmpty
        ? 0.0
        : swimmingLaps.map((l) => l.pacePerHundred).reduce((a, b) => a + b) /
            swimmingLaps.length;

    final averageStrokeRate = swimmingLaps.isEmpty
        ? 0.0
        : swimmingLaps.map((l) => l.strokeRate).reduce((a, b) => a + b) /
            swimmingLaps.length;

    // カロリー推定
    double totalCalories = 0.0;
    for (final lap in laps) {
      totalCalories += _metricsCalc.estimateCalories(
        strokeType: lap.strokeType.english,
        durationMinutes: lap.durationSeconds / 60,
        weightKg: userWeightKg,
      );
    }

    return AnalysisResult(
      sessionId: sessionId,
      analyzedAt: DateTime.now(),
      poolLength: poolLength,
      totalLaps: swimmingLaps.length,
      totalDistance: swimmingLaps.length * poolLength,
      totalDuration: totalDuration,
      laps: laps,
      averageSwolf: averageSwolf,
      averagePace: averagePace,
      averageStrokeRate: averageStrokeRate,
      strokeDistribution: strokeDistribution,
      estimatedCalories: totalCalories,
    );
  }
}
