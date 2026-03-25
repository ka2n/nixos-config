# wk2511058 クラッシュレポート: Ollama Vulkan GPU負荷によるハードクラッシュ

- **日時**: 2026-03-25 09:45:58 JST
- **マシン**: wk2511058 (Lenovo ThinkPad 21NSCTO1WW)
- **GPU**: Intel Arc Graphics 130V/140V (Lunar Lake, xe driver)
- **カーネル**: Linux 6.19.7
- **RAM**: 32GB

## 症状

- journalログが 09:45:58 で突然途切れ、正常シャットダウンのシーケンスなし
- 再起動後のブートで `BERT: [Hardware Error]: Skipped 1 error records` が記録
- 再起動後に `xe 0000:00:02.0: [drm] *ERROR* Tile0: GT1: GSC proxy component not bound!` エラー

## 推定原因

**Ollama の Vulkan 経由大量 embedding リクエストによる Intel Xe GPU ハードウェア障害**

### 根拠

1. **クラッシュ直前の状況**: ollama が `/api/embed` エンドポイントへ大量リクエスト処理中（セッション中6,073回）。クラッシュ直前の数分間は1-2秒間隔で連続的にembedリクエストを処理しており、GPU負荷が高い状態が続いていた

2. **ハードウェアエラーの痕跡**: 再起動後に BERT (Boot Error Record Table) がハードウェアエラーレコードのスキップを報告。これは前回ブート中にハードウェアレベルのエラーが発生したことを示す

3. **GPU DRMエラー**: xe ドライバが GSC proxy component のバインド失敗を報告。GPU の状態が不安定だった可能性

4. **熱問題の前兆**: 前日 (3/24 16:52) にCPUパッケージ温度が閾値を超えてスロットリングが発生。thermald はこのプラットフォーム(ThinkPad dytc_lapmode)で動作不可

5. **正常シャットダウンなし**: カーネルパニックのログもOOM killerのログもなく、突然のハードフリーズ → ハードウェアレベルの障害を示唆

## タイムライン

| 時刻 | イベント |
|------|---------|
| 3/24 16:31 | ブート -1 開始 |
| 3/24 16:52 | CPU温度閾値超過によるスロットリング (65→82イベント) |
| 3/24 18:44 | サスペンド/レジューム |
| 3/25 07:55 | ollama GPU メモリ確認 (17.3 GiB available / Vulkan) |
| 3/25 09:45-09:58 | ollama embed リクエスト連続処理中 |
| 3/25 09:45:58 | **ログ途絶 — ハードクラッシュ** |
| 3/25 09:59:36 | 新ブート開始、BERT ハードウェアエラー報告 |

## 対策案

1. **ollama embed のレートリミット/バッチサイズ制限**: 連続的なGPU負荷を軽減
2. **xe ドライバの更新確認**: Lunar Lake の xe ドライバはまだ成熟途上、カーネル更新で改善の可能性
3. **Vulkan → CPU fallback の検討**: embedding処理をCPUに切り替えてGPU負荷を回避

> **Note**: thermald はこの ThinkPad では DYTC (ファームウェア側熱管理) が有効なため起動不可。
> 熱管理は DYTC + power-profiles-daemon で対応済み。今回のクラッシュは CPU 温度ではなく GPU (Vulkan) 側の問題。
