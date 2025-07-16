# csv2db

CSVファイルから物件データをデータベースに一括登録するRailsアプリケーション

## 概要

このアプリケーションは、不動産物件情報をCSVファイル形式で一括登録・更新することができるWebアプリケーションです。

## 機能

### 📁 CSVファイルアップロード
- CSV形式の物件データファイルをアップロード
- ファイル形式の自動検証（Content-Type と拡張子の二重チェック）
- 大容量ファイルの効率的な処理（1000件ずつのバッチ処理）

### 🏠 物件データ管理
- **物件の種類**: アパート、マンション、一戸建て
- **データ項目**: ユニークID、物件名、住所、部屋番号、賃料、広さ、建物の種類
- **Upsert機能**: 既存データの更新と新規データの挿入を自動判定

### ✅ データ検証とエラーハンドリング
- 建物の種類の妥当性チェック
- 必須項目の検証（一戸建て以外は部屋番号必須）
- エラーメッセージの制限表示（最大20件）
- 詳細なエラーレポート

## CSVファイル仕様

### ファイル形式
- **ファイル形式**: CSV（カンマ区切り）
- **文字エンコーディング**: UTF-8
- **ヘッダー行**: 必須

### 必須列

| 列名 | データ型 | 説明 | 必須 |
|------|----------|------|------|
| ユニークID | 数値 | 物件の一意識別子 | ○ |
| 物件名 | 文字列 | 物件の名称 | ○ |
| 住所 | 文字列 | 物件の所在地 | - |
| 部屋番号 | 文字列 | 部屋番号（一戸建て以外は必須） | △ |
| 賃料 | 数値 | 月額賃料（円） | - |
| 広さ | 数値 | 専有面積（㎡） | - |
| 建物の種類 | 文字列 | アパート/マンション/一戸建て | ○ |

### CSVサンプル

```csv
ユニークID,物件名,住所,部屋番号,賃料,広さ,建物の種類
1,サンプルアパート,東京都新宿区西新宿1-1-1,101,80000,25.5,アパート
2,高級マンション,東京都港区六本木1-1-1,502,200000,60.0,マンション
3,戸建て住宅,千葉県市川市本町1-1-1,,120000,80.0,一戸建て
```

## 使い方

### 1. CSVファイルの準備
上記の仕様に従ってCSVファイルを作成してください。

### 2. ファイルのアップロード
```
GET  /property/csv_insert   # アップロード画面の表示
POST /property/csv_insert   # CSVファイルの処理
```

### 3. 結果の確認
- 成功時: 登録・更新件数とエラー件数が表示されます
- エラー時: 具体的なエラー内容が表示されます（最大20件）

## 技術仕様

### アーキテクチャ
- **フレームワーク**: Ruby on Rails 8.0.2
- **データベース**: SQLite3
- **テスト**: RSpec

### 主要クラス

#### PropertyController
CSVアップロードとデータ処理を担当するコントローラー

**主要メソッド:**
- `csv_insert`: CSVファイルの処理とデータベースへの登録

**主要機能:**
- ファイル形式の検証
- CSVデータの解析と検証
- バッチ処理による効率的なデータ挿入
- エラーハンドリングと詳細レポート

#### Csv2db::Property
物件データを管理するActiveRecordモデル

**属性:**
```ruby
# データベース構造
create_table :properties do |t|
  t.string :name, null: false        # 物件名
  t.string :address                  # 住所
  t.string :room_number              # 部屋番号
  t.integer :rent                    # 賃料
  t.float :area                      # 広さ
  t.integer :building_type           # 建物の種類（enum）
  t.timestamps
end
```

**列挙型（Enum）:**
```ruby
enum :building_type, {
  apartment: 0,  # アパート
  house: 1,      # 一戸建て
  mansion: 2     # マンション
}
```

**検証ルール:**
```ruby
validates :name, presence: true
validates :room_number, presence: true, unless: :house?
```

### パフォーマンス最適化

#### バッチ処理
```ruby
SLICE_SIZE = 1000  # 1度に処理する件数

properties_data.each_slice(SLICE_SIZE) do |batch|
  Csv2db::Property.upsert_all(batch, unique_by: :id)
end
```

#### トランザクション処理
```ruby
Csv2db::Property.transaction do
  # 全ての処理が成功した場合のみコミット
end
```

## エラーハンドリング

### ファイル検証エラー
- 非CSVファイルのアップロード
- ファイル形式の不正

### データ検証エラー
- 必須項目の未入力
- 建物の種類の不正な値
- データ型の不整合

### システムエラー
- データベース接続エラー
- CSV解析エラー
- メモリ不足

## 開発・テスト

### テスト実行
```bash
# 全テストの実行
bundle exec rspec

# PropertyControllerのテストのみ
bundle exec rspec spec/controllers/property_controller_spec.rb

# 詳細表示
bundle exec rspec spec/controllers/property_controller_spec.rb --format documentation
```

### テストカバレッジ
- ✅ 正常ケース（有効なCSVファイル）
- ✅ 異常ケース（無効なデータ、ファイル形式エラー）
- ✅ 境界値（大容量ファイル、エラー件数制限）
- ✅ 例外処理（データベースエラー、CSV解析エラー）

### 開発環境のセットアップ
```bash
# 依存関係のインストール
bundle install

# データベースの作成とマイグレーション
rails db:create
rails db:migrate

# 開発サーバーの起動
rails server
```
