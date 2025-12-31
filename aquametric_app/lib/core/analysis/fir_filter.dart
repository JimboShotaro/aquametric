import 'dart:math';
import 'dart:typed_data';

/// SwimBIT仕様に基づく48次FIRローパスフィルタ
/// カットオフ周波数: 3Hz, サンプリングレート: 100Hz
class SwimBITFilter {
  final int order;
  final double cutoffHz;
  final double samplingRate;
  late Float64List _coefficients;

  SwimBITFilter({
    this.order = 48,
    this.cutoffHz = 3.0,
    this.samplingRate = 100.0,
  }) {
    _coefficients = _designHammingFIR();
  }

  /// ハミング窓FIRフィルタ係数の設計
  Float64List _designHammingFIR() {
    final numTaps = order + 1;
    final coeffs = Float64List(numTaps);
    final nyquist = samplingRate / 2;
    final normalizedCutoff = cutoffHz / nyquist;
    final omega = pi * normalizedCutoff;

    for (int n = 0; n < numTaps; n++) {
      final m = n - order / 2;

      // Sinc関数
      double sinc;
      if (m == 0) {
        sinc = 2 * normalizedCutoff;
      } else {
        sinc = sin(2 * omega * m) / (pi * m);
      }

      // ハミング窓
      final hamming = 0.54 - 0.46 * cos(2 * pi * n / order);

      coeffs[n] = sinc * hamming;
    }

    // 正規化
    final sum = coeffs.reduce((a, b) => a + b);
    for (int i = 0; i < numTaps; i++) {
      coeffs[i] /= sum;
    }

    return coeffs;
  }

  /// フィルタ係数を取得（テスト用）
  Float64List get coefficients => _coefficients;

  /// 1次元信号にFIRフィルタを適用
  Float64List apply(Float64List signal) {
    final n = signal.length;
    final numTaps = _coefficients.length;
    final output = Float64List(n);
    final halfTaps = numTaps ~/ 2;

    for (int i = 0; i < n; i++) {
      double sum = 0.0;
      for (int j = 0; j < numTaps; j++) {
        final idx = i - j + halfTaps;
        if (idx >= 0 && idx < n) {
          sum += _coefficients[j] * signal[idx];
        }
      }
      output[i] = sum;
    }

    return output;
  }

  /// 3軸データにフィルタを適用
  List<Float64List> applyToAxes(List<Float64List> axes) {
    return axes.map((axis) => apply(axis)).toList();
  }

  /// ゼロ位相フィルタリング（往復フィルタ）
  /// 位相遅れを解消するために、順方向と逆方向の両方でフィルタを適用
  Float64List applyZeroPhase(Float64List signal) {
    // 順方向フィルタ
    final forward = apply(signal);

    // 信号を反転
    final reversed = Float64List(forward.length);
    for (int i = 0; i < forward.length; i++) {
      reversed[i] = forward[forward.length - 1 - i];
    }

    // 逆方向フィルタ
    final backward = apply(reversed);

    // 再度反転して元の順序に戻す
    final output = Float64List(backward.length);
    for (int i = 0; i < backward.length; i++) {
      output[i] = backward[backward.length - 1 - i];
    }

    return output;
  }
}
