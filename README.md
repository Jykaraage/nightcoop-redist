# Cyberpunk 2077 / NightCoop

このフォルダは、NightCoopの導入情報・固定バージョン・管理スクリプトを置くローカルGit repoです。
ゲーム本体、MODバイナリ、セーブ、招待コード、バックアップはGitに含めません。

## 起動

`Start-NightCoop.cmd` をダブルクリックします。ゲーム本体を直接起動し、ゲーム更新やMODファイルの変更があれば起動前に停止します。Steamは起動した状態で使ってください。
専用ランチャーは不要です。ゲームのメインメニューの **Co-op** から操作します。

- ホスト: **Host a session** → セーブまたは新規ゲーム → 招待コードを共有。
- 参加者: **Join by code** → 招待コードを入力。
- 一緒に遊ぶ全員が **NightCoop 0.2.0-beta / protocol 164** を使ってください。

セッションの作成・他のプレイヤーとの接続は、ゲーム内で行います。[公式ガイド](https://nightcoop.net/docs.html)

## このPCの構成

| 項目 | 設定 |
| --- | --- |
| ゲーム | Steam版 Cyberpunk 2077 **2.5** |
| 本体 | `I:\steamlibrary\steamapps\common\Cyberpunk 2077` |
| DLC | Phantom Liberty 導入済み |
| NightCoop | **0.2.0-beta** / protocol **164** / build `a3ea83df` |
| 同梱ローダー | RED4ext **1.31.0** |
| 既存MOD | 2020〜2021年の旧Cyber Engine Tweaksはバックアップ後に無効化 |
| 確認日 | 2026-11-07（日本時間） |

## 管理コマンド

このフォルダでPowerShellを開いて実行します。管理者権限は通常不要ですが、ゲームフォルダへの書き込み権限は必要です。

```powershell
# ファイル・バージョン検証
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Setup.ps1

# 導入前プレビュー（導入済みの場合は再導入を拒否）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-NightCoop.ps1 -WhatIf

# 導入（公式ZIPをSHA-256照合、セーブと上書き対象をバックアップ）
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-NightCoop.ps1

# 導入ファイルを戻す。先に -WhatIf で確認可能
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Restore-NightCoop.ps1 -WhatIf
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Restore-NightCoop.ps1
```

`ExecutionPolicy Bypass` はこのコマンドのプロセスだけに適用されます。
導入スクリプトはゲーム起動中の実行を拒否します。セーブのバックアップも完了・照合してからゲーム内のファイルを書き換えます。
復元はこのrepoが記録したファイルだけを対象にし、後から内容が変わったファイルがあれば停止します。
このPCの初回導入では `-DisableLegacyCet` を付けて旧 `version.dll` と `cyber_engine_tweaks.asi` をバックアップ・無効化しました。通常の導入ではCETに触れません。復元すると、この旧CETも元に戻るので再起動前に注意してください。

## ファイルとバックアップ

- `nightcoop.lock.json`: 公式配布URL・SHA-256・対象ゲーム版を固定。
- `config.local.json`: このPCのゲーム/セーブパス。Git対象外。別PCでは `config.example.json` をコピーして編集。
- `local/installation.json`: 導入ファイル一覧、個別ハッシュ、バックアップ先。Git対象外。
- `backups/<日時-ID>/saves/`: 導入前のセーブ。復元スクリプトはセーブを上書きしません。
- `backups/<日時-ID>/originals/`: 導入前から存在した上書き対象ファイル。
- `backups/<日時-ID>/disabled/`: 無効化した旧CETの2ファイル。
- `.cache/`: 公式ZIPと配布一覧。Git対象外。
- [導入・動作確認記録](docs/installation.md)

セーブを戻す必要があるときはゲームを終了し、現在のセーブも別に保存してからバックアップを戻してください。
Steam Cloudによる再同期にも注意してください。

## 更新するとき

1. [公式配布ページ](https://nightcoop.net/download.html)と[配布一覧](https://nightcoop.net/releases.json)で、ゲーム版・撤回有無・SHA-256を確認。
2. 一緒に遊ぶ人と導入バージョンを合わせ、現在の導入を `Restore-NightCoop.ps1` で戻す。
3. `nightcoop.lock.json` のURL・サイズ・SHA-256・ゲーム版・protocolを更新して再導入。
4. `Test-Setup.ps1` とゲーム内Co-opメニューを確認し、記録を更新してコミット。

自動で最新版に追従しません。ゲームが更新されたら、対応版を確認してから更新します。

## 調子が悪いとき

Co-opが出ない場合は `red4ext\logs\red4ext-*.log` でプラグインの読み込み状況を確認します。
NightCoopのログはゲーム本体の `red4ext\logs` と `red4ext\plugins\NightCoop\logs` に出ます。[公式トラブル対応](https://nightcoop.net/docs.html#logs)

導入ZIPに含まれる `r6\scripts\NightCoopFlight` も同時に管理します。NightCoopのために追加のCETやredscriptを自動導入しません。
Gitのリモートは未設定です。
