# Phase 03 — Architecture & Design Decisions

## Overview

```
                         ┌─────────────────────────────┐
                         │  CloudFront (journal.daoxiao.org)
                         │  + S3 (private, OAC-only)   │
                         └──────────────┬──────────────┘
                                        │  serves React build
                                        ▼
                                   ┌─────────┐
                                   │ Browser │
                                   └────┬────┘
                        login/signup    │  JWT ID Token (Authorization header)
                                        ▼
                         ┌──────────────────────────────┐
                         │ Cognito User Pool (Essentials) │
                         └──────────────┬───────────────┘
                                        │ issues JWT
                                        ▼
                    ┌───────────────────────────────────────┐
                    │ API Gateway (HTTP API)                 │
                    │ JWT Authorizer — verifies token before │
                    │ any request reaches Lambda              │
                    └───────────────────┬─────────────────────┘
                     ┌──────────┬───────┼────────┬──────────┐
                POST /entries GET /entries PUT /entries/{id} DELETE /entries/{id}
                     │          │        │        │
              create_entry list_entries update_entry delete_entry   (Lambda, Python 3.12)
                     └──────────┴───────┬┴────────┘
                                        ▼
                         DynamoDB `entries` table
                         PK: userId / SK: entryId
```

## Why these choices

### HTTP API, not REST API

API Gateway's **HTTP API** type has a native JWT Authorizer that validates a Cognito
User Pool's ID tokens directly — no custom Lambda authorizer needed. It's also
cheaper ($1.00/million requests vs. REST API's $3.50/million) and has less
configuration surface. REST API's extra features (request validation, usage
plans, WAF integration at the API level) aren't needed for a CRUD app at this
scale; if this project ever needs them, migrating is possible but not free —
that trade-off is accepted here deliberately.

### Python for Lambda

The user is learning Python (see project memory `user_python_learning`), so the
Lambda handlers double as learning material — production code that's also a
teaching example, rather than a separate toy script.

### DynamoDB single-table design: `PK=userId`, `SK=entryId`

Every query for "a user's entries" is a `Query` on the partition key, never a
`Scan`. This has a security side effect worth naming explicitly: **there is no
code path that can read another user's data**, because every read/write/update/
delete operation is keyed by `userId` taken from the verified JWT claims
(`event.requestContext.authorizer.jwt.claims.sub`), not from client input. An
attacker who guesses or steals another user's `entryId` still can't act on it,
because the DynamoDB key includes their own `userId`, which doesn't match.

`entryId` is `{ISO timestamp}#{uuid4}` — prefixing with the timestamp means
`Query` results come back in chronological order for free (no separate sort
attribute needed), and the array returned by `list_entries` is always
newest-first (`ScanIndexForward=False`). Several places in the frontend rely on
this ordering invariant (e.g. computing the "first ever entry date" as
`entries[entries.length - 1]`) — **if this changes, those call sites break
silently**, so don't remove `ScanIndexForward=False` without updating the
frontend.

### Single table, two entry "types"

The journal has two conceptually different things a user writes: a daily
gratitude entry (`write`/`history` tabs) and a free-form "growth reflection"
(`reflect` tab). Rather than a second table or a second set of Lambda
functions/routes, both are stored as rows in the same `entries` table
distinguished by an `entryType` attribute (`"gratitude"` | `"reflection"`,
defaulting to `"gratitude"` if omitted for backward compatibility). The
frontend filters client-side (`entries.filter(...)`) rather than the backend
exposing separate endpoints — this was a deliberate scope decision to avoid
adding two more Lambda functions and two more API routes for what's ultimately
the same CRUD shape with a label attached.

### IAM: extend the existing GitHub Actions user, don't create a new one

`github-actions-portfolio-01` (created in Phase 1) is reused rather than
creating `github-actions-portfolio-03`. Every new IAM user means a new set of
GitHub Secrets to manage; the roadmap's "each phase is independently
deployable" principle is about the *infrastructure* being independently
deployable, not about credential sprawl. The Phase 3 policy attached to this
user (`iam.tf`) is scoped narrowly to `lambda:UpdateFunctionCode` on exactly
the four Phase 3 function ARNs — it cannot touch Phase 1/2 resources or any
other Phase 3 resource type.

### CI/CD scope: Lambda code only, infra stays manual

`deploy-03-serverless.yml` zips and pushes Lambda code on every push to
`backend/lambda/**`. It does **not** run `terraform apply`. This mirrors
Phase 2's approach and is a direct consequence of the IAM decision above: the
CI user only has `lambda:UpdateFunctionCode`, not the broader
Cognito/API Gateway/DynamoDB/S3/CloudFront/Route53/IAM-role permissions a full
`terraform apply` would need. Giving CI those permissions was considered and
rejected — it would mean a compromised GitHub Actions run (or a bad PR from a
fork) could restructure the AWS account, not just overwrite a function's code.
Infra changes go through a human running `terraform plan`/`apply` locally.

### Frontend hosting: its own S3 + CloudFront, not reusing Phase 1's

Phase 1's bucket/distribution serves the *static* version of this app.
Phase 3's React build is a different app (auth + API calls) and gets its own
S3 bucket and CloudFront distribution, so that `terraform destroy` in Phase 3's
state can never affect Phase 1 or 2. The two are linked only by DNS: both point
at records in the same Route 53 hosted zone (`daoxiao.org`, created in
Phase 2), which is why Phase 3 doesn't pay for a second hosted zone
($0.50/month) — it just adds one more A record to the existing zone.

## Security notes

- **JWT verification happens at the API Gateway layer**, before Lambda ever
  runs — an invalid or expired token never reaches application code.
- **IDOR protection is structural, not a check** — see the single-table design
  section above. There's no `if (entry.userId !== requestingUserId) reject()`
  anywhere because the DynamoDB key itself makes cross-user access
  unaddressable, not just unauthorized.
- **S3 is never public.** Both Phase 1 and Phase 3 buckets block all public
  access and only allow reads from their own CloudFront distribution's
  `AWS:SourceArn` — CloudFront can't be pointed at the "wrong" bucket to bypass
  this, since the condition is distribution-specific.

## Cost

See the repository-wide [`docs/Cost-Estimation.md`](../../docs/Cost-Estimation.md)
— Phase 3 rounds to **$0.00/month** at current portfolio-scale usage. The one
line item to watch if this app ever gets real traffic is DynamoDB's on-demand
request cost, which (unlike Lambda/API Gateway) has no always-free allowance.

## Known limitations / future work

- No automated frontend deployment yet — `aws s3 sync` + `create-invalidation`
  are run manually. A GitHub Actions job could be added following the same
  pattern as `deploy-01-static-site.yml`.
- The `reflect` tab's "day N" badge is computed at render time from the
  earliest entry of *either* type, not stored at creation time — see
  `frontend/docs/Design.md` for why, and the edge case it fixes.
- No integration/unit tests for the Lambda handlers. Verified so far by direct
  `aws lambda invoke` smoke tests and a real end-to-end browser session
  (documented in project memory), not by an automated test suite.

---

# Phase 03 — アーキテクチャと設計判断（日本語）

## 全体構成

```
                         ┌─────────────────────────────┐
                         │  CloudFront (journal.daoxiao.org)
                         │  + S3（プライベート・OAC限定） │
                         └──────────────┬──────────────┘
                                        │  Reactビルドを配信
                                        ▼
                                   ┌─────────┐
                                   │ ブラウザ │
                                   └────┬────┘
                    ログイン/サインアップ │  JWT IDトークン(Authorizationヘッダー)
                                        ▼
                         ┌──────────────────────────────┐
                         │ Cognito User Pool (Essentials) │
                         └──────────────┬───────────────┘
                                        │ JWT発行
                                        ▼
                    ┌───────────────────────────────────────┐
                    │ API Gateway (HTTP API)                 │
                    │ JWT Authorizer — Lambdaに到達する前に  │
                    │ トークンを検証する                      │
                    └───────────────────┬─────────────────────┘
                     ┌──────────┬───────┼────────┬──────────┐
                POST /entries GET /entries PUT /entries/{id} DELETE /entries/{id}
                     │          │        │        │
              create_entry list_entries update_entry delete_entry   (Lambda, Python 3.12)
                     └──────────┴───────┬┴────────┘
                                        ▼
                         DynamoDB `entries` テーブル
                         PK: userId / SK: entryId
```

## なぜこの設計にしたか

### REST APIではなくHTTP API

API Gatewayの**HTTP API**は、Cognito User PoolのIDトークンを直接検証できる
JWT Authorizerを標準搭載しており、カスタムLambda Authorizerが不要になる。
料金も安く（$1.00/100万リクエスト、REST APIは$3.50/100万）、設定項目も少ない。
REST APIの追加機能（リクエストバリデーション、使用量プラン、API層でのWAF連携）は
このCRUDアプリの規模では不要と判断した。将来必要になれば移行は可能だが無料ではない
というトレードオフを意識的に受け入れている。

### LambdaはPython

ユーザーがPythonを学習中のため（memory `user_python_learning` 参照）、
Lambdaハンドラーがそのまま学習教材を兼ねる。別に用意した練習用スクリプトではなく、
実際に動く本番コードで学べるようにする狙い。

### DynamoDBシングルテーブル: `PK=userId`, `SK=entryId`

「あるユーザーのエントリ一覧」の取得はすべてパーティションキーに対する`Query`であり、
`Scan`は一切使わない。これはセキュリティ上の副次効果として明記する価値がある：
**他ユーザーのデータを読み取る経路がコード上に存在しない**。読み取り・書き込み・
更新・削除のすべての操作が、クライアント入力ではなく検証済みJWTクレーム
（`event.requestContext.authorizer.jwt.claims.sub`）由来の`userId`をキーにしているため。
他ユーザーの`entryId`を推測・窃取できたとしても、DynamoDBのキーには自分自身の
`userId`が含まれるため操作できない。

`entryId`は`{ISO時刻}#{uuid4}`の形式。先頭にタイムスタンプを置くことで、
`Query`結果が追加のソート属性なしに自動的に時系列順になり、`list_entries`が返す
配列は常に新しい順（`ScanIndexForward=False`）になる。フロントエンドの複数箇所が
この順序の前提に依存している（例:「最初のエントリの日付」を`entries[entries.length - 1]`
で計算している）。**この前提を崩すとフロントエンドが静かに壊れる**ため、
`ScanIndexForward=False`はフロントエンドの対応する箇所を確認せずに変更しないこと。

### 1つのテーブルに2つの「種別」

日記アプリには概念的に異なる2種類の書き込みがある：日々の感謝エントリ
（今日/履歴タブ）と、自由記述の「成長の気づき」（気づきタブ）。別テーブルや
別Lambda関数・別ルートを用意するのではなく、両方とも同じ`entries`テーブルの行として、
`entryType`属性（`"gratitude"` | `"reflection"`、省略時は後方互換のため`"gratitude"`扱い）
で区別している。フロントエンド側でクライアントサイドにフィルタ（`entries.filter(...)`）
する設計で、バックエンドが別エンドポイントを公開する構成にはしていない。
これは、結局同じCRUDの形にラベルを1つ付けるだけのために、Lambda関数2本・
APIルート2本を追加する必要はないという意識的なスコープ判断。

### IAM: 新規GitHub Actionsユーザーを作らず既存を拡張

Phase 1で作成した`github-actions-portfolio-01`をそのまま使い、
`github-actions-portfolio-03`のような新規ユーザーは作らない。IAMユーザーが
増えるたびにGitHub Secretsの管理対象も増える。ロードマップの「各Phaseは
独立してデプロイ可能」という原則は**インフラ**が独立デプロイ可能であることを
指しており、認証情報の増殖を指すものではないと解釈している。このユーザーに
付与したPhase 3用ポリシー（`iam.tf`）は、Phase 3の4つのLambda関数ARNに対する
`lambda:UpdateFunctionCode`のみに厳密に限定されており、Phase 1/2のリソースや
Phase 3の他のリソース種別には一切触れられない。

### CI/CDのスコープ: Lambdaコードのみ、インフラは手動のまま

`deploy-03-serverless.yml`は`backend/lambda/**`へのpush時にLambdaコードを
zip化してデプロイするだけで、`terraform apply`は実行**しない**。これはPhase 2の
方針を踏襲しており、上記のIAM判断の直接の帰結でもある：CI用ユーザーは
`lambda:UpdateFunctionCode`しか持たず、完全な`terraform apply`に必要な
Cognito/API Gateway/DynamoDB/S3/CloudFront/Route53/IAMロールの権限は持たない。
CIにこれらの権限を持たせる案も検討したが却下した — GitHub Actionsの実行が
侵害された場合（あるいはフォークからの悪意あるPR）、関数コードの上書きだけでなく
AWSアカウントの構成そのものを変更されてしまうリスクがあるため。インフラの変更は
人間がローカルで`terraform plan`/`apply`を実行する形を維持する。

### フロントエンド配信: Phase 1を流用せず専用のS3+CloudFront

Phase 1のバケット/ディストリビューションは、このアプリの**静的版**を配信している。
Phase 3のReactビルドは別アプリ（認証+API呼び出し）であり、専用のS3バケットと
CloudFrontディストリビューションを持つことで、Phase 3のstateに対する
`terraform destroy`がPhase 1・Phase 2に影響することが決してないようにしている。
両者はDNSでのみ繋がっており、どちらも同じRoute 53ホストゾーン
（`daoxiao.org`、Phase 2で作成）内のレコードを指しているだけ。そのためPhase 3は
2つ目のホストゾーン代（$0.50/月）を払う必要がなく、既存ゾーンにAレコードを
1件追加するだけで済んでいる。

## セキュリティに関する補足

- **JWT検証はAPI Gateway層で行われ**、Lambdaが実行される前に完了する。
  無効・期限切れのトークンがアプリケーションコードに到達することはない。
- **IDOR対策はチェックではなく構造そのもの** — 上記のシングルテーブル設計を参照。
  「`if (entry.userId !== requestingUserId) reject()`」のようなコードはどこにもない。
  DynamoDBのキー設計自体が、他ユーザーのデータへのアクセスを
  「権限がない」のではなく「そもそも到達できない」ものにしているため。
- **S3は一切パブリックにしない。** Phase 1・Phase 3どちらのバケットも
  パブリックアクセスを完全にブロックし、自分自身のCloudFrontディストリビューションの
  `AWS:SourceArn`からの読み取りのみを許可している。この条件はディストリビューション単位
  なので、CloudFrontを「別の」バケットに向けてこの制限を回避することはできない。

## コスト

リポジトリ全体の[`docs/Cost-Estimation.md`](../../docs/Cost-Estimation.md)を参照。
現在のポートフォリオ規模の使用量では、Phase 3のコストは**実質$0.00/月**に丸まる。
実トラフィックが発生した場合に最初に注視すべきはDynamoDBのオンデマンドリクエスト課金
（Lambda・API Gatewayと違い常時無料枠が存在しない）。

## 既知の制約・今後の課題

- フロントエンドの自動デプロイは未整備 — 現状`aws s3 sync`と
  `create-invalidation`は手動実行。`deploy-01-static-site.yml`と同じパターンで
  GitHub Actionsジョブを追加できる。
- 気づきタブの「N日目」バッジは、作成時に固定値として保存するのではなく、
  描画時にentryType問わず最古のエントリから計算している — 理由と、これが
  修正した具体的な不具合については`frontend/docs/Design.md`を参照。
- Lambdaハンドラーの自動テスト（unit/integration）は未整備。ここまでの検証は
  `aws lambda invoke`による直接スモークテストと、実ブラウザでのエンドツーエンド
  セッション（memoryに記録済み）によるもので、自動テストスイートによるものではない。
