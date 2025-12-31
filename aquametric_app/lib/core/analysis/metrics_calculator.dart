import 'dart:typed_data';
import 'dart:math';

/// 水泳メトリクス計算器
/// ストロークカウント、SWOLF、ペースなどを計算
class MetricsCalculator {
  final double samplingRate;
  final double minPeakDistance;
  final double peakHeightThreshold;

  MetricsCalculator({
    this.samplingRate = 100.0,
    this.minPeakDistance = 0.5, // 最小ストローク間隔（秒）
    this.peakHeightThreshold = 0.3, // ピーク検出閾値（標準偏差の倍数）
  });

  /// ストローク数をカウント（ピーク検出ベース）
  int countStrokes(Float64List axisData) {
    if (axisData.length < 10) return 0;

    // ピーク検出
    final peaks = _detectPeaks(axisData);

    return peaks.length;
  }

  /// ピーク検出
  List<int> _detectPeaks(Float64List data) {
    final peaks = <int>[];
    final n = data.length;

    // 統計量を計算
    final mean = data.reduce((a, b) => a + b) / n;
    double variance = 0.0;
    for (final value in data) {
      variance += (value - mean) * (value - mean);
    }
    final stdDev = sqrt(variance / n);

    // 閾値
    final threshold = mean + stdDev * peakHeightThreshold;
    final minSamples = (minPeakDistance * samplingRate).round();

    int lastPeakIdx = -minSamples;

    for (int i = 1; i < n - 1; i++) {
      // 局所的最大値かつ閾値超え
      if (data[i] > data[i - 1] &&
          data[i] > data[i + 1] &&
          data[i] > threshold &&
          i - lastPeakIdx >= minSamples) {
        peaks.add(i);
        lastPeakIdx = i;
      }
    }

    return peaks;
  }

  /// FFTベースのストロークレート推定（ストローク/分）
  double estimateStrokeRate(Float64List axisData) {
    if (axisData.length < 256) return 0.0;

    // 簡易的なFFT代替: 自己相関関数でピッチを検出
    final autocorr = _autocorrelation(axisData);

    // 最初のピーク（DC成分の次）を探す
    final minLag = (samplingRate * 0.3).round(); // 0.3秒以上
    final maxLag = (samplingRate * 2.0).round(); // 2秒以下

    int peakLag = minLag;
    double peakVal = autocorr[minLag];

    for (int lag = minLag; lag < min(maxLag, autocorr.length); lag++) {
      if (autocorr[lag] > peakVal) {
        peakVal = autocorr[lag];
        peakLag = lag;
      }
    }

    // ストロークレート（回/分）に変換
    final strokePeriod = peakLag / samplingRate;
    return 60.0 / strokePeriod;
  }

  /// 自己相関関数
  Float64List _autocorrelation(Float64List data) {
    final n = data.length;
    final result = Float64List(n);

    // 平均を引く
    final mean = data.reduce((a, b) => a + b) / n;
    final centered = Float64List(n);
    for (int i = 0; i < n; i++) {
      centered[i] = data[i] - mean;
    }

    // 自己相関計算
    for (int lag = 0; lag < n; lag++) {
      double sum = 0.0;
      for (int i = 0; i < n - lag; i++) {
        sum += centered[i] * centered[i + lag];
      }
      result[lag] = sum / (n - lag);
    }

    // 正規化
    if (result[0] > 0) {
      for (int i = 0; i < n; i++) {
        result[i] /= result[0];
      }
    }

    return result;
  }

  /// SWOLF計算
  /// SWOLF = 時間（秒） + ストローク数
  int calculateSwolf({
    required double durationSeconds,
    required int strokeCount,
  }) {
    return (durationSeconds + strokeCount).round();
  }

  /// ペース計算（100mあたりの秒数）
  double calculatePace({
    required double durationSeconds,
    required int distance,
  }) {
    if (distance <= 0) return 0.0;
    return (durationSeconds / distance) * 100;
  }

  /// 効率スコア（0-100）
  /// SWOLFを基準にした相対的な効率
  double calculateEfficiencyScore({
    required int swolf,
    required int poolLength,
  }) {
    // 参考値: 25mプールでSWOLF 30が優秀、50が平均、70が初心者
    // 50mプールは2倍
    final baseSwolf = poolLength == 50 ? 60.0 : 30.0;
    final maxSwolf = poolLength == 50 ? 140.0 : 70.0;

    if (swolf <= baseSwolf) return 100.0;
    if (swolf >= maxSwolf) return 0.0;

    return 100.0 * (maxSwolf - swolf) / (maxSwolf - baseSwolf);
  }

  /// カロリー消費推定（kcal）
  /// 泳法と時間に基づく概算
  double estimateCalories({
    required String strokeType,
    required double durationMinutes,
    required double weightKg,
  }) {
    // MET値（代謝当量）
    final metValues = {
      'freestyle': 8.0,
      'backstroke': 7.0,
      'breaststroke': 7.0,
      'butterfly': 11.0,
      'unknown': 7.0,
      'rest': 2.0,
    };

    final met = metValues[strokeType.toLowerCase()] ?? 7.0;

    // カロリー = MET × 体重(kg) × 時間(時間)
    return met * weightKg * (durationMinutes / 60);
  }
}
