# 導入・検証・復元

## 導入の動き

`Setup-NightCoop.cmd` はSteamのライブラリ、GOGの登録情報、Epicのインストール情報からゲーム本体を探します。
自動検出できなければフォルダを入力できます。ゲームルート、`bin/x64`、`Cyberpunk2077.exe` のパスを受け付けます。
複数見つかった場合は選択します。

セーブは現在のWindowsユーザーのSaved Gamesフォルダから検出します。移動したSaved Gamesにも対応し、`-SavePath` で明示指定もできます。
個別のパスは `config.local.json` に保存し、配布・Git管理には含めません。

導入スクリプトは次の順序で処理します。

1. ゲーム終了状態と、EXEのProductVersionが固定版と一致することを確認。
2. 未取得なら公式配布一覧の版・撤回情報・URL・SHA-256・サイズを照合して公式ZIPを取得。
3. ZIPのSHA-256・サイズ・収録パスを検証。キャッシュを使う場合もハッシュを再確認。
4. セーブと上書き対象を `backups/<日時-ID>/` にコピーし、個別ハッシュで照合。セーブ未作成なら0件として記録。
5. MODの10ファイルを配置・照合し、`local/installation.json` に導入記録を保存。

既存のNightCoopフォルダやこのキットの導入記録がある場合、インストーラーは重ねて上書きしません。
`Setup-NightCoop.cmd` はこのキットで導入済みなら検証だけを行います。他の方法で導入している場合は既存構成を整理してから利用してください。

## PCにだけ残るデータ

| 場所 | 内容 |
| --- | --- |
| `config.local.json` | 自分のゲームとセーブのパス |
| `.cache/` | 公式ZIP。公式と同じSHA-256であることを毎回検証 |
| `local/installation.json` | 導入先、ファイルハッシュ、復元元 |
| `backups/<日時-ID>/saves/` | 導入前のセーブがある場合、そのコピー |
| `backups/<日時-ID>/saves-manifest.json` | セーブの照合情報 |
| `backups/<日時-ID>/originals/` | 上書き前のMOD・ローダーファイル |
| `backups/<日時-ID>/disabled/` | 明示オプションで退避した旧CETがある場合、そのコピー |

復元に必要なので、このキットのフォルダは導入後も保持してください。
`Check-NightCoop.cmd` はMODファイルに加え、導入時からゲームEXEが変わっていないことも確認します。
ゲーム更新後は、同じ表示バージョンでもEXEが変わっていれば起動スクリプトが停止します。

## 復元

ゲームを終了して `Restore-NightCoop.cmd` を実行します。プレビューは次のコマンドです。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Restore-NightCoop.ps1 -WhatIf
```

導入記録にあるファイルだけを削除または元に戻します。後から別のMODで変更されたファイルがあれば、処理前の確認で停止します。
NightCoopが後から生成した設定・ログは削除せず、空でないフォルダも残します。再導入時は残ったNightCoop設定を別の場所に保存してから整理してください。
セーブとバックアップ自体は残します。セーブを過去の状態に戻す機能はありません。

## 既存MODと旧CET

通常のセットアップは既存CETを無効化しません。NightCoopに必要なRED4extは公式ZIPに含まれます。
このキットだけで問題を切り分ける場合、他のMODとの互換性は別に確認してください。

古いCETを退避すると判断した場合のみ、設定後に次を実行できます。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-NightCoop.ps1 -DisableLegacyCet -WhatIf
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-NightCoop.ps1 -DisableLegacyCet
```

このオプションは `bin/x64/version.dll` と `bin/x64/plugins/cyber_engine_tweaks.asi` をバックアップ後に無効化します。
復元すると旧CETも元に戻るため、ゲームの再起動前に確認してください。

## ログと確認状況

Co-opが出ない場合はゲーム本体の `red4ext/logs/red4ext-*.log` を確認します。
NightCoopのログは `red4ext/logs` と `red4ext/plugins/NightCoop/logs` です。[公式ガイド](https://nightcoop.net/docs.html)

2026-11-07の実機確認では、ゲーム2.5でRED4ext 1.31.0とNightCoop 0.2.0が読み込まれ、protocol 164・build a3ea83dfをログで確認しました。
Co-opメニューの目視確認と他PCとの接続は未確認です。
