# AquaMetric Mobile Gateway

モバイルアプリ（スマートフォン側）のインターフェース定義

## アーキテクチャ

```
┌─────────────────────────────────────────────────┐
│              Mobile Gateway Layer               │
├─────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────┐  │
│  │  BLE Sync   │  │  API Client │  │  Cache  │  │
│  │   Manager   │  │             │  │ Manager │  │
│  └─────────────┘  └─────────────┘  └─────────┘  │
│         │                │               │      │
│         ▼                ▼               ▼      │
│  ┌──────────────────────────────────────────┐   │
│  │           Data Repository                │   │
│  │   (SessionRepo, StatsRepo, UserRepo)     │   │
│  └──────────────────────────────────────────┘   │
│                      │                          │
│                      ▼                          │
│  ┌──────────────────────────────────────────┐   │
│  │              UI Layer                    │   │
│  │   (Dashboard, SessionDetail, Calendar)   │   │
│  └──────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

## 実装技術の選択肢

### Flutter（推奨）
- iOS/Android両対応
- Dart言語
- BLEサポート: `flutter_blue_plus`
- 状態管理: Riverpod

### React Native
- JavaScript/TypeScript
- BLE: `react-native-ble-plx`

### ネイティブ
- iOS: Swift + CoreBluetooth
- Android: Kotlin + BluetoothLeScanner

## ディレクトリ構造

```
mobile/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── routes.dart
│   │   └── theme.dart
│   ├── core/
│   │   ├── api/                    # バックエンドAPI通信
│   │   │   ├── api_client.dart
│   │   │   └── endpoints.dart
│   │   ├── ble/                    # BLE通信（腕時計連携）
│   │   │   ├── ble_manager.dart
│   │   │   └── device_discovery.dart
│   │   └── storage/                # ローカルキャッシュ
│   │       ├── cache_manager.dart
│   │       └── hive_adapter.dart
│   ├── data/
│   │   ├── models/                 # データモデル
│   │   │   ├── session.dart
│   │   │   ├── lap.dart
│   │   │   └── daily_stat.dart
│   │   └── repositories/           # データアクセス層
│   │       ├── session_repository.dart
│   │       └── stats_repository.dart
│   ├── features/
│   │   ├── dashboard/              # ダッシュボード画面
│   │   │   ├── dashboard_screen.dart
│   │   │   └── widgets/
│   │   ├── session/                # セッション詳細
│   │   │   ├── session_detail_screen.dart
│   │   │   └── widgets/
│   │   ├── calendar/               # カレンダー表示
│   │   │   ├── calendar_screen.dart
│   │   │   └── heatmap_widget.dart
│   │   └── sync/                   # 腕時計同期
│   │       ├── sync_screen.dart
│   │       └── sync_controller.dart
│   └── shared/
│       ├── widgets/
│       └── utils/
└── pubspec.yaml
```
