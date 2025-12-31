import 'dart:typed_data';
import 'dart:math';

/// ラップ（ターン）検出器
/// 加速度パターンの変化からターン・壁タッチを検出
class LapDetector {
  final double turnThreshold;
  final int minLapSamples;
  final int turnWindowSamples;
  final double samplingRate;

  LapDetector({
    this.turnThreshold = 2.5,
    this.minLapSamples = 1000, // 10秒 @ 100Hz
    this.turnWindowSamples = 150, // 1.5秒のターン検出窓
    this.samplingRate = 100.0,
  });

  /// 加速度データからラップ境界を検出
  /// Returns: ラップ境界のインデックスリスト [start1, end1/start2, end2/start3, ...]
  List<int> detect({
    required Float64List accX,
    required Float64List accY,
    required Float64List accZ,
    required List<double> timestamps,
  }) {
    if (accX.length < minLapSamples) {
      return [0, accX.length];
    }

    // 加速度の大きさ（マグニチュード）を計算
    final magnitude = _calculateMagnitude(accX, accY, accZ);

    // ターン候補を検出
    final turnCandidates = _detectTurnCandidates(magnitude);

    // ラップ境界を確定
    final boundaries = _refineBoundaries(turnCandidates, magnitude.length);

    return boundaries;
  }

  /// 3軸加速度からマグニチュードを計算
  Float64List _calculateMagnitude(
    Float64List accX,
    Float64List accY,
    Float64List accZ,
  ) {
    final n = accX.length;
    final magnitude = Float64List(n);

    for (int i = 0; i < n; i++) {
      magnitude[i] = sqrt(
        accX[i] * accX[i] + accY[i] * accY[i] + accZ[i] * accZ[i],
      );
    }

    return magnitude;
  }

  /// ターン候補位置を検出
  List<int> _detectTurnCandidates(Float64List magnitude) {
    final candidates = <int>[];
    final n = magnitude.length;

    // 移動平均でスムージング
    final smoothed = _movingAverage(magnitude, 50);

    // 局所的な分散が高い領域を検出（ターンは動きが激しい）
    final windowSize = turnWindowSamples;
    final halfWindow = windowSize ~/ 2;

    for (int i = halfWindow; i < n - halfWindow; i += halfWindow) {
      // ウィンドウ内の分散を計算
      double sum = 0.0;
      double sumSq = 0.0;
      for (int j = i - halfWindow; j < i + halfWindow; j++) {
        sum += smoothed[j];
        sumSq += smoothed[j] * smoothed[j];
      }
      final mean = sum / windowSize;
      final variance = (sumSq / windowSize) - (mean * mean);

      // 分散が閾値を超えたらターン候補
      if (variance > turnThreshold) {
        // ピーク位置を見つける
        int peakIdx = i;
        double peakVal = smoothed[i];
        for (int j = i - halfWindow; j < i + halfWindow; j++) {
          if (smoothed[j] > peakVal) {
            peakVal = smoothed[j];
            peakIdx = j;
          }
        }
        candidates.add(peakIdx);
      }
    }

    return candidates;
  }

  /// ラップ境界を確定
  List<int> _refineBoundaries(List<int> candidates, int dataLength) {
    final boundaries = <int>[0]; // 開始点

    int lastBoundary = 0;
    for (final candidate in candidates) {
      // 最小ラップ長を満たすか確認
      if (candidate - lastBoundary >= minLapSamples) {
        boundaries.add(candidate);
        lastBoundary = candidate;
      }
    }

    // 終了点を追加（まだなければ）
    if (boundaries.last != dataLength) {
      // 最後のラップが短すぎる場合は前のラップに統合
      if (dataLength - boundaries.last < minLapSamples && boundaries.length > 1) {
        boundaries.removeLast();
      }
      boundaries.add(dataLength);
    }

    return boundaries;
  }

  /// 移動平均フィルタ
  Float64List _movingAverage(Float64List data, int windowSize) {
    final n = data.length;
    final result = Float64List(n);
    final halfWindow = windowSize ~/ 2;

    for (int i = 0; i < n; i++) {
      double sum = 0.0;
      int count = 0;
      for (int j = max(0, i - halfWindow); j < min(n, i + halfWindow + 1); j++) {
        sum += data[j];
        count++;
      }
      result[i] = sum / count;
    }

    return result;
  }

  /// プール長からラップ数を推定
  int estimateLapCount({
    required double totalDuration,
    required int poolLength,
    required double averagePacePerHundred,
  }) {
    if (averagePacePerHundred <= 0) return 0;
    final estimatedDistance = (totalDuration / averagePacePerHundred) * 100;
    return (estimatedDistance / poolLength).round();
  }
}
