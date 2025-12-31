import 'dart:typed_data';

/// 泳法の種類
enum StrokeType {
  freestyle('クロール', 'Freestyle'),
  backstroke('背泳ぎ', 'Backstroke'),
  breaststroke('平泳ぎ', 'Breaststroke'),
  butterfly('バタフライ', 'Butterfly'),
  unknown('不明', 'Unknown'),
  rest('休憩', 'Rest');

  final String japanese;
  final String english;

  const StrokeType(this.japanese, this.english);

  @override
  String toString() => english;
}

/// SwimBITエネルギーベースのストローク分類器
class StrokeClassifier {
  final double butterflyThreshold;
  final double backstrokeGravityThreshold;
  final double restEnergyThreshold;

  StrokeClassifier({
    this.butterflyThreshold = 15.0,
    this.backstrokeGravityThreshold = 5.0,
    this.restEnergyThreshold = 2.0,
  });

  /// エネルギー計算: E = Σ|x[i] - mean| / N
  double calculateEnergy(Float64List data) {
    if (data.isEmpty) return 0.0;

    final mean = data.reduce((a, b) => a + b) / data.length;
    double energy = 0.0;
    for (final value in data) {
      energy += (value - mean).abs();
    }
    return energy / data.length;
  }

  /// 平均値計算
  double calculateMean(Float64List data) {
    if (data.isEmpty) return 0.0;
    return data.reduce((a, b) => a + b) / data.length;
  }

  /// 分散計算
  double calculateVariance(Float64List data) {
    if (data.isEmpty) return 0.0;
    final mean = calculateMean(data);
    double variance = 0.0;
    for (final value in data) {
      variance += (value - mean) * (value - mean);
    }
    return variance / data.length;
  }

  /// 1ラップ分のデータから泳法を判定
  StrokeType classify({
    required Float64List accX,
    required Float64List accY,
    required Float64List accZ,
  }) {
    if (accX.isEmpty || accY.isEmpty || accZ.isEmpty) {
      return StrokeType.unknown;
    }

    final energyX = calculateEnergy(accX);
    final energyY = calculateEnergy(accY);
    final energyZ = calculateEnergy(accZ);
    final meanZ = calculateMean(accZ);
    final totalEnergy = energyX + energyY + energyZ;

    // 0. 休憩判定: 全体のエネルギーが低い
    if (totalEnergy < restEnergyThreshold) {
      return StrokeType.rest;
    }

    // 1. 背泳ぎ判定: 重力ベクトルの向き（手の甲が下向き）
    if (meanZ > backstrokeGravityThreshold) {
      return StrokeType.backstroke;
    }

    // 2. クロール判定: Y軸（ロール）エネルギーが支配的
    if (energyY > energyX && energyY > energyZ) {
      return StrokeType.freestyle;
    }

    // 3. バタフライ vs 平泳ぎ: シンメトリック泳法
    if (energyZ > energyY) {
      // バタフライはX軸（進行方向）の加速度変化が大きい
      if (energyX > butterflyThreshold) {
        return StrokeType.butterfly;
      } else {
        return StrokeType.breaststroke;
      }
    }

    return StrokeType.unknown;
  }

  /// 分類結果と信頼度を返す
  ClassificationResult classifyWithConfidence({
    required Float64List accX,
    required Float64List accY,
    required Float64List accZ,
  }) {
    final strokeType = classify(accX: accX, accY: accY, accZ: accZ);

    final energyX = calculateEnergy(accX);
    final energyY = calculateEnergy(accY);
    final energyZ = calculateEnergy(accZ);
    final totalEnergy = energyX + energyY + energyZ;

    // 信頼度計算（エネルギー分布の偏りに基づく）
    double confidence;
    if (totalEnergy < 0.1) {
      confidence = 0.0;
    } else {
      final maxEnergy = [energyX, energyY, energyZ].reduce((a, b) => a > b ? a : b);
      confidence = (maxEnergy / totalEnergy).clamp(0.0, 1.0);
    }

    return ClassificationResult(
      strokeType: strokeType,
      confidence: confidence,
      energyX: energyX,
      energyY: energyY,
      energyZ: energyZ,
    );
  }
}

/// 分類結果（信頼度付き）
class ClassificationResult {
  final StrokeType strokeType;
  final double confidence;
  final double energyX;
  final double energyY;
  final double energyZ;

  ClassificationResult({
    required this.strokeType,
    required this.confidence,
    required this.energyX,
    required this.energyY,
    required this.energyZ,
  });

  @override
  String toString() =>
      'ClassificationResult(${strokeType.english}, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}
