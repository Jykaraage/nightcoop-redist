# nightcoop-redist

一緒に遊ぶメンバー向けの **NightCoop導入キット** です。Windows標準のPowerShellで動き、Gitのインストールは不要です。
各PCのCyberpunk 2077を検出し、公式から同じMODをダウンロード・検証・バックアップして導入します。

| 全員で合わせるもの | 固定値 |
| --- | --- |
| Cyberpunk 2077 | **2.5**（Windows / Steam・GOG・Epic） |
| NightCoop | **0.2.0-beta** |
| 通信protocol | **164** |
| 同梱RED4ext | **1.31.0** |

## メンバーの導入手順

1. [このrepo](https://github.com/Jykaraage/nightcoop-redist)の **Code → Download ZIP** をダウンロードし、ZIPを**すべて展開**します。ゲーム本体とは別の、書き込み可能なフォルダに置いてください。
2. ゲームを終了し、展開先の **`Setup-NightCoop.cmd`** をダブルクリックします。ゲームの場所が見つからなければ、画面の案内に沿ってパスを入力します。
3. `Setup complete` または `Already installed and verified` と表示されたら完了。**`Start-NightCoop.cmd`** から起動します。ストアのクライアントは起動しておいてください。

初回は公式サイトへの通信が必要です。ゲーム本体は各自で用意してください。ゲーム版が2.5以外なら停止し、自動で更新・ダウングレードしません。
セーブがまだないPCでも導入できます。ダウンロード後にゲームを勝手に起動することはありません。

このrepoは非公開です。GitHubで取得するにはrepoへのアクセス権が必要です。メンバーに直接ZIPを渡す場合は、後述の配布パッケージを使えます。

## 一緒に遊ぶ

メインメニューの **Co-op** を使います。

- ホスト: **Host a session** → セーブまたは新規ゲームを選択 → 招待コードをメンバーに伝える。
- 参加者: **Join by code** → 招待コードを入力。
- 全員が上の固定バージョンを使う。新しい版への更新はグループ内で合わせる。

操作の詳細は[公式ガイド](https://nightcoop.net/docs.html)を参照してください。Beta版のため、最初の接続確認には新規または試験用のセーブをおすすめします。

## 同梱コマンド

| ファイル | 用途 |
| --- | --- |
| `Setup-NightCoop.cmd` | 自動検出・PCごとの設定保存・導入。導入済みなら再検証 |
| `Start-NightCoop.cmd` | バージョンとファイルの検証後にゲーム起動 |
| `Check-NightCoop.cmd` | 導入済みファイルとゲーム更新の確認 |
| `Restore-NightCoop.cmd` | 導入前のMOD構成に復元。セーブは上書きしない |

ゲームやセーブの場所を指定する場合は、PowerShellからも実行できます。

```powershell
.\Setup-NightCoop.cmd -GamePath "D:\Games\Cyberpunk 2077"

# セーブ場所を変更している場合のみ指定
.\Setup-NightCoop.cmd -GamePath "D:\Games\Cyberpunk 2077" -SavePath "D:\My Saves\Cyberpunk 2077"

# 設定だけ保存し、ゲーム本体は変更しない
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-NightCoop.ps1 -ConfigureOnly
```

CMDはプロセス単位の `ExecutionPolicy Bypass` を使います。Windows全体の設定は変更しません。
セーブや招待コード、ログをメンバーに配る必要はありません。

## 配布する人へ

このrepoを共有するか、次のコマンドで導入キットだけのZIPを作成します。ZIPを作る側にもGitは不要です。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Package.ps1
```

`dist/NightCoop-Setup-0.2.0-beta.zip` とSHA-256ファイルが生成されます。
配布ZIPは明示した管理ファイルだけを収録し、PCごとの設定・バックアップ・ログ・MODバイナリ・Git履歴を含めません。
MOD本体は受け取った人のPCで[公式サイト](https://nightcoop.net/download.html)から取得します。

詳細: [導入と復元](docs/installation.md) / [配布・更新方針](docs/distribution.md) / [第三者のソフトウェア](THIRD-PARTY-NOTICES.md)

このキットのスクリプトと説明書は[MIT License](LICENSE)です。NightCoopおよびCyberpunk 2077のライセンスを付与するものではありません。
