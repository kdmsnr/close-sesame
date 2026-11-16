# Sesame RESTful API メモ

出典: [CANDY HOUSE API Document — RESTful API](https://candy-house.github.io/API_document/ja/SesameOS3/webapi)（2026-11-17 参照）

API キーは [SESAME Biz の開発者向けページ](https://biz.candyhouse.co/)で取得する。各リクエストの `x-api-key` ヘッダーに設定する。ベース URL は `https://app.candyhouse.co/api/sesame2`。

## 状態と履歴

- `GET /{sesame2_uuid}`: 状態を取得する。レスポンスには `batteryPercentage`、`batteryVoltage`、`position`、`CHSesame2Status`（`locked`、`unlocked`、`moved`）、`timestamp` が含まれる。`position` は 360 度を 1024 とする角度。
- `GET /{sesame2_uuid}/history?page=0&lg=2`: 履歴を取得する。`page` は 0 始まりで、1 ページ最大 50 件。`lg` は取得件数。履歴は新しい順。
- 履歴には `type`、`timeStamp`、`historyTag`、`recordID`、`parameter` が含まれる。`historyTag` は鍵のタグやメモで、0〜21 バイト。`recordID` はデバイス再起動まで一意で、連続するとは限らない。
- 主な履歴の `type`: 6 オートロック、7 手動施錠、8 手動解錠、9 その他の手動操作、10 モーターによる施錠、11 モーターによる解錠、12 駆動失敗、14/15 WiFi モジュール経由の施錠/解錠、16/17 REST API 経由の施錠/解錠。全種類は出典を参照。

出典では状態・履歴のタイムスタンプをミリ秒と説明しているが、掲載値は桁数から秒単位に見える。単位は実際のレスポンスで確認する。

## コマンド

`POST /{sesame2_uuid}/cmd` に JSON を送る。出典では WiFi モジュール 2 に接続された Sesame を対象としている。

```json
{
  "cmd": 82,
  "history": "<Base64 encoded history>",
  "sign": "<AES-CMAC hex signature>"
}
```

`cmd` は施錠が `82`、解錠が `83`、切り替えが `88`。Bot2/Bot3 のスクリプト 0〜9 は `170`〜`179`。

`sign` はデバイスの秘密鍵を使った AES-CMAC。出典のコード例では、現在の Unix 時刻（秒）を 32 ビットのリトルエンディアンに変換し、先頭の 1 バイトを除いた残り 3 バイトをメッセージにする。出典の説明には「最上位バイトを除く」とあるが、このコード例の操作とは一致しないため注意する。署名は実機で検証していない。
