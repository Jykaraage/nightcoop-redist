# 導入記録

2026-11-07（日本時間）確認。

## 導入前

- このフォルダは空。ローカルGit repo（`main`）を初期化。
- 本体: `I:\steamlibrary\steamapps\common\Cyberpunk 2077`
- Steam app: `1091500` / build ID: `26161058`
- EXE ProductVersion: `2.5` / FileVersion: `3.0.5813403`
- Phantom Libertyあり。
- 既存 `bin\x64\version.dll` と `plugins\cyber_engine_tweaks.asi` あり。
- `red4ext` とNightCoopは未導入。
- セーブ: 311ファイル、590,084,500 bytes。ユーザーのセーブやSteam IDはコミットしない。

## 配布物

[NightCoop公式配布一覧](https://nightcoop.net/releases.json)で最新版を確認し、ゲーム2.5用を選択。
固定情報は `nightcoop.lock.json` に記録。

```text
NightCoop-0.2.0-beta-2.5.zip
10,117,378 bytes
SHA-256: ca070aa296519fb4147dadf14a625a538df59d6a20d289fa3e335ae3da3cace5
```

公式値とダウンロード実体のサイズ・SHA-256が一致。
配布ページに残っているデモ説明文ではなく、実際の配布JSONを使用し、demoフラグや撤回情報も確認。

ZIP内の10ファイル:

```text
bin/x64/winmm.dll
red4ext/RED4ext.dll
red4ext/LICENSE.txt
red4ext/THIRD_PARTY_LICENSES.txt
red4ext/plugins/NightCoop/NightCoop.dll
red4ext/plugins/NightCoop/redscript/NightCoopSdk.reds
red4ext/plugins/NightCoop/redscript/NightCoopSdkNative.reds
r6/scripts/NightCoopFlight/NightCoopFlight.reds
r6/scripts/NightCoopFlight/LICENSE.txt
r6/scripts/NightCoopFlight/THIRD_PARTY.md
```

## 検証結果

- PowerShellスクリプトの構文解析が通過。
- 導入前の `Install-NightCoop.ps1 -DisableLegacyCet -WhatIf` が通過。
- セーブ311ファイルを個別SHA-256で照合してバックアップ。
- 旧CETの `bin\x64\version.dll`（2020-12-19）と `plugins\cyber_engine_tweaks.asi`（2021-01-06）をバックアップ後に無効化。旧ログはゲーム1.06時代。
- NightCoop / RED4ext / 同梱スクリプト10ファイルを配置し、全ファイルのSHA-256がZIP内の値と一致。
- `Test-Setup.ps1` 通過。`Restore-NightCoop.ps1 -WhatIf` 通過（実際の復元は未実施）。
- Steam URIによる起動ではゲームプロセスが立ち上がらず、直接EXE起動で起動を確認。起動スクリプトは直接EXE起動を採用。
- 2026-11-07 21:19 JST: ゲームプロセスとゲームウィンドウ名を確認。
- RED4extログ: `RED4ext (v1.31.0)` / `NightCoop (version: 0.2.0, author(s): NightCoop) has been loaded` / `1 plugin(s) loaded`。
- NightCoopログ: `protocol version 164, build a3ea83df` / `game version 2.5` / `NightCoop SDK v1 ready` を確認。
- 画面操作ツールは `windows sandbox failed: helper_unknown_error: setup refresh had errors` で起動に失敗。Co-opメニューの目視確認・セッション作成・他プレイヤーとの接続は未確認。

バックアップ先（Git対象外）:

```text
backups/20261107-211831-6e42f82d/
```

NightCoopログに、2.5のセーブ形式に関する未検証の警告あり。実際の協力プレイはバックアップを保持し、まず新規または試験用のセーブで確認する。

## 参照元

- [公式サイト](https://nightcoop.net/)
- [公式ダウンロード](https://nightcoop.net/download.html)
- [公式配布一覧JSON](https://nightcoop.net/releases.json)
- [公式導入・操作ガイド](https://nightcoop.net/docs.html)
