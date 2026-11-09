# 配布と更新

## 配布方式

配布するのは、このキットのスクリプト・設定例・説明書・固定バージョン情報です。
NightCoop.dll本体に対する再配布許諾を公式配布物内で確認できなかったため、MODのZIP/DLLは配布物に含めず、各自が公式からダウンロードします。
RED4extとNightCoopFlightのライセンスも公式ZIPのまま導入されます。詳細は [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。

メンバーに渡すZIPは次のコマンドで生成します。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-Package.ps1
```

`scripts/dist/NightCoop-Setup-0.2.0-beta.zip` とSHA-256ファイルが生成されます。
ZIPを解凍すると、直下のファイルは `NightCoop.cmd` だけです。説明書・ライセンスは `docs/`、設定例・固定バージョン情報・内部PowerShellスクリプトは `scripts/` にあります。フォルダ全体を手動で圧縮せず、このパッケージを使ってください。
`scripts/config.local.json`、`scripts/local/`、`scripts/backups/`、`scripts/.cache/`、`scripts/dist/`、`.git/` は配布対象外です。
旧版のルートに残る個別設定・導入記録・バックアップも配布ZIPには含めません。設定例は `scripts/config.example.json` です。
GitHubのCode → Download ZIPにも、追跡対象外のデータは含まれません。

## 固定版を更新する

1. [公式配布ページ](https://nightcoop.net/download.html)と[配布一覧JSON](https://nightcoop.net/releases.json)で版・対象ゲーム・protocol・撤回状態を確認。
2. `scripts/nightcoop.lock.json` のURL・SHA-256・サイズ・ゲーム版・RED4ext版・protocolなどを更新し、公式ZIPの内容を確認。
3. インストーラーの許可パスに新しい公式構成が収まるか確認。構成が変わった場合は許可パスも見直す。
4. 隔離したフォルダで導入・検証・復元のテストと、実機での読み込み確認を実施。全員が更新前に導入済み構成を復元する。
5. `docs/README.md` の固定値を更新し、GitHubへpushして新しい導入キットを配る。

このキットは勝手に最新版へ更新しません。旧版の撤回は新規ダウンロード時に確認し、既にある公式ZIPは固定ハッシュで検証します。

## テスト

GitHubのソース一式で、Windows PowerShell 5.1から実行します。メンバー向け配布パッケージにはテストは収録しません。外部モジュールは不要です。

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Smoke.Tests.ps1
```

隔離した模擬ゲームとZIPを作り、セットアップ・保存データなしの導入・ハッシュ検証・復元・変更後の復元拒否・危険なZIPパスの拒否を確認します。
実際のゲーム・セーブには触れません。テストでゲームを起動することもありません。
