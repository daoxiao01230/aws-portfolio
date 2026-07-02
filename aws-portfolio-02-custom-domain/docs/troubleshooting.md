# Troubleshooting

## 2026-07-01: カスタムドメインが Route53 の NS を設定してもずっと NXDOMAIN

### 症状

- `gratitude.daoxiao.org` はもちろん、親ドメイン `daoxiao.org` 自体も NXDOMAIN
- お名前.com 側で Route53 のネームサーバーへの変更は済んでいるはず
- Route53 側の CNAME（ACM検証用）・A レコードも正常に見える
- 「DNS 伝播待ち（最大24〜48h）」として様子見していたが、日をまたいでも変化なし

### 切り分けの手順

**1. 複数の公開DNSリゾルバで独立に確認する**

```bash
curl -s "https://dns.google/resolve?name=daoxiao.org&type=NS"
curl -s "https://dns.google/resolve?name=gratitude.daoxiao.org&type=CNAME"
```

Google (8.8.8.8) と Cloudflare (1.1.1.1) の両方で同じ NXDOMAIN が出るなら、単一リゾルバのキャッシュ遅延ではない。

**2. レスポンスの `Authority` セクションに注目する**

`dns.google` の JSON レスポンスで `Authority` が `daoxiao.org` 自身の SOA ではなく `org.` ゾーン自体の SOA（`a0.org.afilias-nst.info...`）を返している場合、
→ **registry が `daoxiao.org` の NS 委任情報を一切持っていない**ことを示すシグナル。単なる伝播遅延とは別の問題を疑う。

**3. `whois` が無い環境では RDAP を使う**

Windows の Git Bash などに `whois` コマンドが入っていない場合、代わりに RDAP（whois の後継、HTTPS API）が使える。`rdap.org` にクエリすると、TLD に応じた正しい registry の RDAP エンドポイントへ自動リダイレクトされる。

```bash
curl -sL "https://rdap.publicinterestregistry.org/rdap/domain/daoxiao.org"
```

（`.org` は Public Interest Registry。他 TLD は `https://rdap.org/domain/<domain>` にクエリすれば自動で正しい registry に飛ぶ）

確認すべきフィールド：
- `nameservers` → registry 側に実際に登録されている NS 値
- `status` → EPP ステータスコード（`client hold` 等）
- `events` → 登録日・最終変更日・RDAP DB 更新日時

**4. Route53 側の実際の NS 値と突き合わせる**

```bash
aws route53 list-hosted-zones --query "HostedZones[?Name=='daoxiao.org.']"
aws route53 get-hosted-zone --id <ZONE_ID> --query "DelegationSet.NameServers"
```

RDAP の `nameservers` と Route53 の値が一致していれば、NS設定自体は正しい → 問題は別にあると確定できる。

### 根本原因

RDAP の `status` に **`client hold`** が付いていた。

`client hold` は「registry は NS 委任情報を認識しているが、意図的に DNS ゾーンへの公開を止めている」状態を示す EPP ステータス。NS の設定が正しくても、このステータスが付いている限り**時間が経っても絶対に解決しない**（伝播待ちとは別次元の問題）。

今回のケースでは、登録日（2026-06-15）から `status` が変わった日（2026-06-29）までの期間から、**ICANN 義務の登録者（Whois）メールアドレス確認**が未完了だったことが原因と推測。2013 RAA のルールにより、新規登録後 15 日以内にメール確認をしないと registrar が自動的に `clientHold` を付与する。

### 解決

1. お名前.com の登録時に届く「Whois情報確認メール」（迷惑メールフォルダも確認）を探す
2. メール内の確認リンクをクリック
3. 数分〜数時間で RDAP の `status` が `active` に変わる（実際に確認済み：クリック直後に `client hold` → `active`）
4. その後、通常の DNS ゾーン反映待ち（数時間程度）で解決

### 教訓

- 「DNS が引けない」→ すぐに「伝播待ち」と決めつけない。`Authority` セクションが TLD 自体の SOA を返している場合は registry 側の委任情報そのものが無い/公開されていない可能性を疑う
- `whois` コマンドが無い環境では RDAP（`rdap.org` 経由）で代替できる
- 新規ドメイン登録直後のトラブルは、まず registrar からの確認メール未対応（`clientHold`）を疑う
