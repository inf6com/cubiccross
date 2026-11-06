# CubicCross Sound Design Spec

Status: Draft v2

Last Updated: 2026-04-13

---

## 1. 基本原則

### 1.1 スクランブル = 作曲

`CubicCross` において、スクランブルとは作曲行為です。

- キューブを回転させる行為 = 音符・音色・リズムを楽譜に書く行為
- スクランブルの結果として得られる色配置 = その瞬間の音色編成
- スクランブルのスワイプ速度 = そのステップのテンポ（一定ではない）
- SCAT 記号をタイルに仕込む行為 = ボーカルフレーズを譜面に書く行為
- Red Special コントロールの状態 = その瞬間の音響特性

### 1.2 リバース = 演奏

HotSpace を1回押すことで、スクランブル全体が自動リバースし、作曲した楽曲が演奏されます。

- HotSpace は演奏開始ボタンである。1回押すだけでよい
- リバースは全ステップ自動で進む。ユーザーが毎回押す必要はない
- リバースの順序: stepN → stepN-1 → ... → step1
- この逆順再生で問題ない
- 各ステップの間隔はスクランブル時のスワイプ速度から決まる

### 1.3 6×6×6 の意味

- 全状態数: 約 1.95 × 10¹¹⁶
- God's Number: 未証明（推定 70〜100 手）
- すべてのスクランブルは事実上ユニークな楽曲である
- スクランブルの深さは楽曲の長さと複雑さに正直に比例する
- 3×3×3 の「20手飽和」は発生しない

---

## 2. 構造定義

### 2.1 カラータイルの意味

- `color tile = timbre`（音色）
- `row = pitch`（音程）
- `1 column = 1 sound event`（1回の統合サウンド推論単位）
- `white = silence`（無音。発音しない）

### 2.2 Red Special コントロールの意味

スクランブル時の各コントロール状態が、そのステップの音色条件として記録される。

| コントロール | 音への意味 |
|---|---|
| PS1 / PS2 / PS3 | 発音源構成・倍音構成・音の厚み |
| PhS1 / PhS2 / PhS3 | 干渉特性・中域の抜け |
| tone | 明るさ・高域バランス |
| volume | 発音強度 |
| fret | 基本音域・演奏ポジション |
| tremoloAngle | ピッチカーブ・揺れ・和音全体への同時作用 |

### 2.3 SCAT の意味

SCAT は演奏可能なボーカル音色層です。

- 文章読み上げではない
- 特定人物の再現ではなく、dramatic rock vocal motif を持つボーカル楽器層
- 音節・音高・長さ・アクセント・発声アタック・フレージングを持つ
- タイルに SCAT 記号を仕込む = その列でボーカルが鳴る
- ユーザーによる声質チューニング（明るさ・荒さ・ブレス感）を将来的に持つ

現行 SCAT 記号体系:

```
"Day-oh", "Dey", "Wey-oh", "Ay-oh", "E-oh",
"Bah", "Bap", "Flash", "Shoo", "Doo",
"Da", "Ba", "La", "Lala", "Wa", "Za", "Scoo"
```

---

## 3. タイミングアーキテクチャ

### 3.1 テンポはスワイプ速度が決める

各スクランブル操作のスワイプ速度（magnitude）が、そのステップの duration を決める。

- 速いスワイプ → 短い duration → 速いテンポ
- 遅いスワイプ → 長い duration → 遅いテンポ
- テンポは全体で一定ではない。ステップごとに異なる
- 作曲者が手の動きでリズムを刻んでいる

### 3.2 duration の算出

```
speed = sqrt(velocity.dx² + velocity.dy²)
duration = clamp(referenceSpeed / speed, minDuration, maxDuration)

minDuration = 0.05 秒
maxDuration = 2.0 秒
referenceSpeed = 実機チューニングで決める
```

### 3.3 スワイプ速度の正確な取得

現状は `value.predictedEndLocation`（終点座標）を velocity として使っており不正確。

正しい取得方法:

```swift
// DragGesture.onEnded
let vel = value.velocity  // iOS 17+: CGVector
let speed = sqrt(vel.dx * vel.dx + vel.dy * vel.dy)
```

---

## 4. データモデル

### 4.1 Move 構造体（変更必要）

```swift
struct Move {
    let axis: Axis3D
    let sliceIndex: Int
    let clockwise: Bool
    let movedCells: [Pos3D]
    let timestamp: Date
    let swipeVelocity: CGFloat  // ← 追加。現状未保存
}
```

### 4.2 ScrambleStep（新規定義必要）

現状の `scrambleHistory: [[String]]` と `scatHistory` を統合する。

```swift
struct ScrambleStep {
    let colors: [String]                           // 色状態（108セル）
    let scatSymbols: [(grid: [Int], scat: String)] // SCAT配置
    let duration: TimeInterval                     // swipeVelocity から算出
    let redSpecialState: RedSpecialState           // その時点のコントロール状態
}

@Published var scrambleHistory: [ScrambleStep]
```

---

## 5. 演奏アーキテクチャ

### 5.1 HotSpace の正しい動作

```
HotSpace 1回押す
    ↓
scrambleHistory を逆順にループ（全ステップ自動）
    ↓
各ステップで:
    1. そのステップの音を生成・再生
    2. キューブを1手リバース
    3. step.duration 後に次のステップへ進む
    ↓
全ステップ完了 → キューブが解かれた状態
    ↓
moveHistory / scrambleHistory をクリア
```

### 5.2 音生成フロー（1ステップ）

```
ScrambleStep
    ↓
18列を処理
    ├── SCAT記号あり → SCATVoice model → vocal PCM
    └── SCAT記号なし → PrismDecoder → instrument PCM
         ├── color → timbre
         ├── row → pitch
         └── RedSpecialState → 音色条件
    ↓
全列の PCM を AVAudioEngine でミックス再生
```

### 5.3 moveHistory のクリアタイミング

現状は `handleUndo()` 冒頭で即クリアしており、リバースアニメーション中に履歴が消える。

正しくは全ステップ演奏完了後にクリアする。

---

## 6. サウンドモデル

### 6.1 PrismDecoder（楽器音）

- 資産: `PrismDecoder.mlpackage` 存在確認済み
- I/O: `latent_input [1, 26]`, `instrument_input [1]` → `Identity [1, 16000] Float32`
- computeUnits: `cpuAndNeuralEngine`（設定済み）
- ANE 実使用: 実機で `MLComputePlan` preferred devices を確認要
- Red Special 全コントロールを latent_input に反映する（現状は一部のみ）

### 6.2 SCATVoice（ボーカル音）

- 現状: モデル資産なし
- 必要な入力: SCAT音節 + 音高 + 強さ + 声質パラメータ
- 推奨候補: RAVE または WORLD 系（Core ML 変換実績あり、ANE 適合性高い）
- v1 方針: 楽器音（PrismDecoder）を先に成立させる。SCATVoice は v2

### 6.3 ANE 対応方針

- 必須ではなく best effort
- `cpuAndNeuralEngine` 設定で実機検証
- preferred devices に neuralEngine が出ない場合はモデル構造を見直す

---

## 7. 現行実装との差分

| 項目 | 現状（仮実装） | あるべき姿 |
|---|---|---|
| HotSpace | 1回 = 1ステップ手動 | 1回 = 全ステップ自動リバース演奏 |
| リバース間隔 | 固定 0.5秒 | swipeVelocity から算出 |
| swipeVelocity | 受け取るが捨てる | Move に保存 → duration 算出 |
| 速度取得 | predictedEndLocation（不正確） | value.velocity の magnitude |
| scrambleHistory | 色のみ `[[String]]` | ScrambleStep（色 + SCAT + duration + state） |
| scatHistory | scrambleHistory と別管理 | ScrambleStep に統合 |
| moveHistory クリア | handleUndo 冒頭で即クリア | 全ステップ完了後にクリア |
| SCAT 再生 | モデルなし、print のみ | v2 で SCATVoice model 実装 |
| Red Special → 音 | 一部のみ反映 | 全コントロールを latent_input に反映 |
| white セル | 別音色扱い | 無音（発音しない） |

---

## 8. 実装優先順位

### Phase 1: タイミング基盤（最優先）

1. `Move` に `swipeVelocity: CGFloat` を追加
2. ジェスチャー層で `value.velocity` の magnitude を正確に取得・保存
3. `ScrambleStep` を定義し `scrambleHistory` / `scatHistory` を統合
4. `handleUndo()` を全ステップ自動ループに変更
5. 各ステップの duration を swipeVelocity から算出して使用
6. `moveHistory.removeAll()` を演奏完了後に移動

### Phase 2: 音生成の精度向上

7. Red Special 全コントロールを `buildPrismInput()` に反映
8. white = silence を確実に実装
9. 列単位の統合推論に近づける

### Phase 3: ANE 最適化

10. 実機で `MLComputePlan` preferred devices を確認
11. ANE 未使用ならモデル構造を見直し

### Phase 4: SCAT ボーカル（v2）

12. SCATVoice モデルの選定・変換・統合
13. SCAT 声質チューニングパラメータの実装

---

## 9. 確定事項と未確定事項

### 確定

- スクランブル = 作曲
- リバース = 演奏（逆順で問題なし）
- HotSpace 1回 = 全ステップ自動演奏
- スワイプ速度 = テンポ（ステップごとに異なる）
- カラータイル = 音色、行 = 音程、列 = サウンドイベント
- white = 無音
- SCAT = 演奏可能なボーカル音色層
- 特定人物の再現は行わない
- 6×6×6 の全スクランブルは事実上ユニークな楽曲

### 未確定

- swipeVelocity → duration の具体的なスケーリング係数（実機チューニング必要）
- SCATVoice に使用するモデル
- ANE が実機で実際に使われるか
- Red Special 各コントロールの latent_input への具体的な写像
- SCAT 声質チューニングパラメータの種類と範囲
