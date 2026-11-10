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
2. ゲームを終了し、展開先の **`NightCoop.cmd`** をダブルクリックします。現在の状態を確認し、未導入なら `1` を入力して初回セットアップを選びます（`0` は何もせず終了）。ゲームの場所が見つからなければ、画面の案内に沿ってパスを入力します。
3. `Setup complete` と表示されたら完了。再び **`NightCoop.cmd`** を開き、導入済みメニューで `1` を選ぶと起動します。ストアのクライアントは起動しておいてください。

初回は公式サイトへの通信が必要です。ゲーム本体は各自で用意してください。ゲーム版が2.5以外なら停止し、自動で更新・ダウングレードしません。
セーブがまだないPCでも導入できます。ダウンロード後にゲームを勝手に起動することはありません。

メンバーに直接ZIPを渡す場合は、後述の配布パッケージを使えます。

## 一緒に遊ぶ

メインメニューの **Co-op** を使います。

- ホスト: **Host a session** → セーブまたは新規ゲームを選択 → 招待コードをメンバーに伝える。
- 参加者: **Join by code** → 招待コードを入力。
- 全員が上の固定バージョンを使う。新しい版への更新はグループ内で合わせる。

操作の詳細は[公式ガイド](https://nightcoop.net/docs.html)を参照してください。Beta版のため、最初の接続確認には新規または試験用のセーブをおすすめします。

## 操作は `NightCoop.cmd` に統一

起動時に状態を表示してから、次の操作を選びます。

| 状態 | メニュー |
| --- | --- |
| 未導入 | `1`: 初回セットアップ / `0`: 何もせず終了 |
| 導入済み | `1`: ゲーム起動 / `2`: 導入前のMOD構成に復元 / `0`: 何もせず終了 |

導入済みファイルとゲームの検証に失敗した場合は起動しません。復元は選択できますが、導入記録とバックアップのハッシュなどを確認し、安全に戻せない場合は停止します。復元でセーブを上書きすることはありません。

ルートに置くファイルは `NightCoop.cmd` だけです。説明書とライセンスは `docs/`、設定・固定バージョン情報・内部スクリプト・作業データは `scripts/` にあります。以下のコマンド例はすべてキットのルートから実行します。

ゲームやセーブの場所の指定、設定のみの保存、検証・復元のプレビューなど、詳細な操作には `scripts/` 内のPowerShellスクリプトを使えます。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-NightCoop.ps1 -GamePath "D:\Games\Cyberpunk 2077"

# セーブ場所を変更している場合のみ指定
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-NightCoop.ps1 -GamePath "D:\Games\Cyberpunk 2077" -SavePath "D:\My Saves\Cyberpunk 2077"

# 設定だけ保存し、ゲーム本体は変更しない
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Setup-NightCoop.ps1 -ConfigureOnly

# 状態確認だけを実行
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Test-Setup.ps1
```

CMDはプロセス単位の `ExecutionPolicy Bypass` を使います。Windows全体の設定は変更しません。
セーブや招待コード、ログをメンバーに配る必要はありません。

## 配布する人へ

このrepoを共有するか、次のコマンドで導入キットだけのZIPを作成します。ZIPを作る側にもGitは不要です。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Package.ps1
```

`scripts/dist/NightCoop-Setup-0.2.0-beta.zip` とSHA-256ファイルが生成されます。
配布ZIPは明示した管理ファイルだけを収録し、PCごとの設定・バックアップ・ログ・MODバイナリ・Git履歴を含めません。
MOD本体は受け取った人のPCで[公式サイト](https://nightcoop.net/download.html)から取得します。

詳細: [導入と復元](installation.md) / [配布・更新方針](distribution.md) / [第三者のソフトウェア](THIRD-PARTY-NOTICES.md)

このキットのスクリプトと説明書は[MIT License](LICENSE)です。NightCoopおよびCyberpunk 2077のライセンスを付与するものではありません。
