# AquaMetric
# SwimBIT-based Swimming Analysis Platform

## プロジェクト概要

AquaMetricは、SwimBITアルゴリズムに基づいた水泳解析プラットフォームです。
スマートウォッチで収集したセンサーデータをクラウドで解析し、
泳法判定、ラップカウント、SWOLF効率指標などを提供します。

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                      3層アーキテクチャ                        │
├───────────────┬──────────────────┬──────────────────────────┤
│  Wearable     │    Mobile        │      Backend             │
│  (腕時計)      │   (スマホ)        │     (クラウド)            │
├───────────────┼──────────────────┼──────────────────────────┤
│ ・100Hzデータ収集 │ ・BLE同期       │ ・SwimBIT解析           │
│ ・ローカル保存   │ ・API通信        │ ・ストローク分類         │
│ ・簡易UI表示    │ ・キャッシュ      │ ・ラップ検出             │
│ ・BLE転送      │ ・可視化UI       │ ・指標計算               │
└───────────────┴──────────────────┴──────────────────────────┘
```

## ディレクトリ構造

```
aquametric/
├── backend/                    # Python バックエンド
│   ├── app/
│   │   ├── api/               # FastAPI エンドポイント
│   │   ├── core/              # SwimBITアルゴリズム実装
│   │   │   ├── preprocessor.py   # フィルタリング
│   │   │   ├── segmenter.py      # ラップ検出
│   │   │   ├── classifier.py     # 泳法分類
│   │   │   └── pipeline.py       # 解析パイプライン
│   │   ├── models.py          # ドメインモデル
│   │   └── schemas.py         # APIスキーマ
│   ├── config/
│   │   └── algorithm_config.yaml  # アルゴリズム設定
│   ├── tests/
│   └── requirements.txt
│
├── mobile/                     # Flutter/Dart モバイルアプリ
│   └── lib/
│       ├── core/
│       │   ├── api/           # バックエンドAPI通信
│       │   └── ble/           # BLE通信（腕時計連携）
│       └── data/
│           └── models/        # データモデル
│
└── wearable/                   # 腕時計アプリ
    ├── apple-watch/           # watchOS (Swift)
    ├── wear-os/               # WearOS (Kotlin)
    └── shared/
        └── proto/             # Protobufスキーマ
```

## 技術スタック

### Backend
- **言語**: Python 3.10+
- **フレームワーク**: FastAPI
- **科学計算**: NumPy, SciPy, Pandas
- **データ検証**: Pydantic

### Mobile
- **フレームワーク**: Flutter
- **言語**: Dart
- **BLE**: flutter_blue_plus
- **状態管理**: Riverpod

### Wearable
- **Apple Watch**: Swift, CoreMotion
- **WearOS**: Kotlin, SensorManager
- **データ転送**: Protobuf

## SwimBITアルゴリズム

### 主要コンポーネント

1. **前処理フィルタ** (`SwimBITFilter`)
   - 48次FIRフィルタ
   - Hamming窓
   - 3Hzカットオフ

2. **セグメンテーション** (`PitchRollSegmenter`)
   - 加速度パターンからラップ境界を検出
   - ターン/休憩区間の識別

3. **ストローク分類** (`EnergyClassifier`)
   - 軸ごとのエネルギー計算
   - Freestyle, Backstroke, Breaststroke, Butterfly を判別

4. **ストロークカウント** (`BasicStrokeCounter`)
   - ピーク検出によるストローク数計測
   - FFTベースの周波数解析

## クイックスタート

### Backend起動

```bash
cd aquametric/backend

# 仮想環境作成
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 依存関係インストール
pip install -r requirements.txt

# サーバー起動
uvicorn app.main:app --reload --port 8000
```

### テスト実行

```bash
cd aquametric/backend
python -m tests.test_pipeline
```

### API ドキュメント

サーバー起動後、以下のURLでSwagger UIにアクセス:
- http://localhost:8000/api/docs

## API エンドポイント

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/v1/sessions/upload` | センサーデータアップロード |
| GET | `/api/v1/sessions/{id}/status` | 解析ステータス確認 |
| GET | `/api/v1/sessions/{id}/analysis` | 解析結果取得 |
| GET | `/api/v1/users/stats/calendar` | カレンダー統計取得 |
| POST | `/api/v1/analysis/quick-analyze` | クイック解析 |

## 設定

`backend/config/algorithm_config.yaml` でアルゴリズムパラメータを調整:

```yaml
filter:
  order: 48
  cutoff_hz: 3.0

classifier:
  thresholds:
    butterfly_x_energy: 15.0
    backstroke_gravity_z: 5.0
```

## 開発ロードマップ

- [x] バックエンド基盤構築
- [x] SwimBITフィルタ実装
- [x] ストローク分類器実装
- [x] セグメンテーション実装
- [x] 解析パイプライン構築
- [x] API エンドポイント作成
- [x] モバイルインターフェース設計
- [x] ウェアラブルインターフェース設計
- [ ] フロントエンドUI実装
- [ ] データベース連携
- [ ] 認証・認可
- [ ] デプロイ

## ライセンス

このプロジェクトはSwimBIT研究論文に基づいています。

参考文献:
- "Swimming Style Recognition and Lane Counting Using a Smartwatch" (ISWC 2019)
- https://dl.acm.org/citation.cfm?id=3347719
