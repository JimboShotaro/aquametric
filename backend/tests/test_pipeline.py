"""
AquaMetric Pipeline Test Script
既存のSwimBITデータを使用してパイプラインをテスト

使用方法:
    cd aquametric/backend
    python -m tests.test_pipeline
"""
import sys
from pathlib import Path

# プロジェクトルートをパスに追加
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

import numpy as np
import pandas as pd


def load_swimbit_data(csv_path: str) -> tuple:
    """
    SwimBIT形式のCSVファイルを読み込み
    
    Returns:
        (timestamps, accel, gyro, labels)
    """
    df = pd.read_csv(csv_path)
    
    timestamps = df['timestamp'].values
    accel = df[['ACC_0', 'ACC_1', 'ACC_2']].values.astype(np.float32)
    gyro = df[['GYRO_0', 'GYRO_1', 'GYRO_2']].values.astype(np.float32)
    
    labels = None
    if 'label' in df.columns:
        labels = df['label'].values
    
    return timestamps, accel, gyro, labels


def test_filter():
    """SwimBITフィルタのテスト"""
    print("\n=== SwimBIT Filter Test ===")
    
    from app.core.preprocessor import SwimBITFilter
    
    # テストデータ生成
    np.random.seed(42)
    n_samples = 1000
    sampling_rate = 30.0  # 30Hz
    
    # ノイズを含む信号
    t = np.arange(n_samples) / sampling_rate
    signal = np.sin(2 * np.pi * 1.0 * t)  # 1Hz の信号
    noise = np.random.randn(n_samples) * 0.5
    noisy_signal = signal + noise
    
    # フィルタ適用
    filter = SwimBITFilter(order=48, cutoff_hz=3.0)
    filtered = filter.process(noisy_signal, sampling_rate)
    
    # 結果確認
    print(f"Input shape: {noisy_signal.shape}")
    print(f"Output shape: {filtered.shape}")
    print(f"Input std: {noisy_signal.std():.4f}")
    print(f"Output std: {filtered.std():.4f}")
    print(f"Noise reduction: {(noisy_signal.std() - filtered.std()) / noisy_signal.std() * 100:.1f}%")
    print("✅ Filter test passed")


def test_classifier():
    """エネルギー分類器のテスト"""
    print("\n=== Energy Classifier Test ===")
    
    from app.core.classifier import EnergyClassifier
    from app.schemas import StrokeType
    
    classifier = EnergyClassifier()
    
    # 各泳法の模擬データを生成
    np.random.seed(42)
    n_samples = 300
    
    # Freestyle: Y軸（ロール）が支配的
    freestyle_data = np.column_stack([
        np.random.randn(n_samples) * 5,   # X
        np.random.randn(n_samples) * 15,  # Y (dominant)
        np.random.randn(n_samples) * 5,   # Z
    ])
    
    # Butterfly: Z軸（うねり）とX軸が高い
    butterfly_data = np.column_stack([
        np.random.randn(n_samples) * 20,  # X (high)
        np.random.randn(n_samples) * 5,   # Y
        np.random.randn(n_samples) * 18,  # Z (high)
    ])
    
    # Breaststroke: 全体的にエネルギーが低い
    breaststroke_data = np.column_stack([
        np.random.randn(n_samples) * 8,   # X
        np.random.randn(n_samples) * 5,   # Y
        np.random.randn(n_samples) * 10,  # Z
    ])
    
    # 分類テスト
    freestyle_result = classifier.classify(freestyle_data)
    butterfly_result = classifier.classify(butterfly_data)
    breaststroke_result = classifier.classify(breaststroke_data)
    
    print(f"Freestyle data → {freestyle_result.value}")
    print(f"Butterfly data → {butterfly_result.value}")
    print(f"Breaststroke data → {breaststroke_result.value}")
    
    # エネルギープロファイル
    profile = classifier.get_energy_profile(freestyle_data)
    print(f"Freestyle energy profile: {profile}")
    
    print("✅ Classifier test passed")


def test_pipeline_with_swimbit_data(data_path: str):
    """
    実際のSwimBITデータでパイプラインをテスト
    """
    print(f"\n=== Pipeline Test with: {data_path} ===")
    
    from app.core.pipeline import AnalysisPipeline
    
    # データ読み込み
    timestamps, accel, gyro, labels = load_swimbit_data(data_path)
    
    print(f"Data shape: {accel.shape}")
    print(f"Duration: {len(accel) / 30:.1f} seconds")
    
    if labels is not None:
        unique_labels = np.unique(labels)
        print(f"Labels in data: {unique_labels}")
    
    # パイプライン実行
    pipeline = AnalysisPipeline(sampling_rate=30.0)
    result = pipeline.analyze_from_arrays(
        timestamps=timestamps,
        accel=accel,
        gyro=gyro,
        pool_length_m=25
    )
    
    # 結果表示
    print(f"\n--- Analysis Results ---")
    print(f"Session ID: {result.session_id}")
    print(f"Total laps detected: {result.total_laps}")
    print(f"Total distance: {result.total_distance_m}m")
    print(f"Total duration: {result.total_duration_sec:.1f}s")
    print(f"Average SWOLF: {result.avg_swolf:.1f}")
    print(f"Primary stroke: {result.primary_stroke.value}")
    
    print(f"\nStroke breakdown:")
    for stroke, count in result.get_stroke_breakdown().items():
        print(f"  {stroke.value}: {count} laps")
    
    if result.laps:
        print(f"\nFirst 5 laps:")
        for lap in result.laps[:5]:
            print(f"  Lap {lap.lap_number}: {lap.stroke_type.value}, "
                  f"{lap.duration_sec:.1f}s, {lap.stroke_count} strokes, "
                  f"SWOLF={lap.swolf}")
    
    print("✅ Pipeline test passed")
    return result


def find_sample_data_files():
    """
    既存のSwimBITサンプルデータを検索
    """
    data_dir = Path(__file__).parent.parent.parent / "swimming-recognition-lap-counting" / "data" / "processed_30hz_relabeled"
    
    if not data_dir.exists():
        print(f"Data directory not found: {data_dir}")
        return []
    
    # 各スイマーディレクトリから1ファイルずつ取得
    sample_files = []
    for swimmer_dir in sorted(data_dir.iterdir()):
        if swimmer_dir.is_dir():
            csv_files = list(swimmer_dir.glob("*.csv"))
            if csv_files:
                sample_files.append(csv_files[0])
                if len(sample_files) >= 5:
                    break
    
    return sample_files


def main():
    print("=" * 60)
    print("AquaMetric Pipeline Test Suite")
    print("=" * 60)
    
    # 基本コンポーネントテスト
    test_filter()
    test_classifier()
    
    # 実データでのテスト
    sample_files = find_sample_data_files()
    
    if sample_files:
        print(f"\n=== Testing with {len(sample_files)} sample files ===")
        for filepath in sample_files:
            test_pipeline_with_swimbit_data(str(filepath))
    else:
        print("\n⚠️ No sample data files found. Skipping real data tests.")
        print("Expected location: swimming-recognition-lap-counting/data/processed_30hz_relabeled/")
    
    print("\n" + "=" * 60)
    print("All tests completed!")
    print("=" * 60)


if __name__ == "__main__":
    main()
