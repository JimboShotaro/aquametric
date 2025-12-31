# AquaMetric Wearable (腕時計側)

ウェアラブルデバイス（Apple Watch / WearOS）のアーキテクチャと実装ガイド

## 設計思想

腕時計は「ダム端末」として振る舞い、以下の役割に徹する：

1. **センサーデータの収集** - 100Hz で加速度・ジャイロスコープを取得
2. **データのバッファリング** - ローカルストレージに一時保存
3. **簡易UI表示** - 経過時間、おおよその距離のみ
4. **BLE転送** - セッション終了後にスマホへ一括送信

計算負荷の高い解析処理はすべてクラウド側で行う（Split-Compute戦略）

## アーキテクチャ

```
┌──────────────────────────────────────────────────┐
│              Wearable App                        │
├──────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────────┐    │
│  │  Sensor Manager │  │   Session Manager   │    │
│  │  (CoreMotion)   │  │                     │    │
│  └────────┬────────┘  └──────────┬──────────┘    │
│           │                      │               │
│           ▼                      ▼               │
│  ┌─────────────────────────────────────────┐     │
│  │           Ring Buffer (Memory)          │     │
│  │           100Hz x 12 axes               │     │
│  └────────────────────┬────────────────────┘     │
│                       │                          │
│                       ▼ (Flush every 5 sec)      │
│  ┌─────────────────────────────────────────┐     │
│  │         Local Storage (File)            │     │
│  │         Binary/Protobuf Format          │     │
│  └────────────────────┬────────────────────┘     │
│                       │                          │
│                       ▼ (On Sync Request)        │
│  ┌─────────────────────────────────────────┐     │
│  │          BLE Transfer Manager           │     │
│  │          Batch Transfer to Phone        │     │
│  └─────────────────────────────────────────┘     │
└──────────────────────────────────────────────────┘
```

## プラットフォーム別実装

### Apple Watch (watchOS)

- **言語**: Swift
- **センサーAPI**: CoreMotion
- **通信**: WatchConnectivity + CoreBluetooth

### WearOS (Android Wear)

- **言語**: Kotlin
- **センサーAPI**: Android SensorManager
- **通信**: Wearable Data Layer API + BLE

## ディレクトリ構造

```
wearable/
├── apple-watch/                    # watchOS アプリ
│   ├── AquaMetric Watch App/
│   │   ├── AquaMetricApp.swift
│   │   ├── ContentView.swift
│   │   ├── Managers/
│   │   │   ├── SensorManager.swift
│   │   │   ├── SessionManager.swift
│   │   │   ├── StorageManager.swift
│   │   │   └── BLEManager.swift
│   │   ├── Models/
│   │   │   ├── SensorData.swift
│   │   │   └── SwimSession.swift
│   │   └── Views/
│   │       ├── SessionView.swift
│   │       └── SyncView.swift
│   └── AquaMetric Watch App.xcodeproj
│
├── wear-os/                        # WearOS アプリ
│   ├── app/
│   │   └── src/main/
│   │       ├── java/com/aquametric/
│   │       │   ├── MainActivity.kt
│   │       │   ├── managers/
│   │       │   │   ├── SensorManager.kt
│   │       │   │   ├── SessionManager.kt
│   │       │   │   └── DataTransferManager.kt
│   │       │   └── models/
│   │       │       └── SensorData.kt
│   │       └── res/
│   └── build.gradle.kts
│
└── shared/                         # 共通ロジック（参照用）
    ├── proto/
    │   └── sensor_data.proto       # Protobufスキーマ
    └── docs/
        └── data_format.md
```

## バッテリー最適化

### 戦略

1. **バッチ処理**: 500サンプル（5秒分）ごとにメモリからストレージへフラッシュ
2. **UI更新頻度制限**: 画面更新は1Hz（1秒に1回）
3. **BLE転送最適化**: Protobuf形式でペイロードを1/3に圧縮
4. **センサーサンプリング調整**: 水中フェーズのみ100Hz、それ以外は10Hz

### 推定バッテリー消費

| 項目 | 消費 |
|-----|------|
| センサー記録 (100Hz) | ~15% / 時間 |
| BLE転送 | ~5% / 同期 |
| UI表示 | ~3% / 時間 |
| **合計 (1時間セッション)** | **~25%** |

## データフォーマット

### Protobuf スキーマ

```protobuf
syntax = "proto3";

message SensorSample {
  int64 timestamp = 1;    // ナノ秒
  float acc_x = 2;
  float acc_y = 3;
  float acc_z = 4;
  float gyro_x = 5;
  float gyro_y = 6;
  float gyro_z = 7;
}

message SwimSession {
  string session_id = 1;
  int64 start_time = 2;
  int64 end_time = 3;
  int32 pool_length_m = 4;
  repeated SensorSample samples = 5;
}
```
