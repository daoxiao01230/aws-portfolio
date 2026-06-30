# Phase 01 — Troubleshooting Log

## 1. AWS CLI が YAML の日本語コメントを読めない

**エラー**
```
aws: [ERROR]: 'cp932' codec can't decode byte 0x83 in position 78: illegal multibyte sequence
```

**原因**
Windows の AWS CLI（Python）がファイルを cp932（Shift-JIS）で読もうとするが、YAML ファイルは UTF-8 で書かれているため文字化けが発生。

**解決策**
`--template-file` の代わりに、PowerShell で UTF-8 として読み込み `--template-body` で渡す。

```powershell
$template = Get-Content "path/to/template.yaml" -Raw -Encoding UTF8
aws cloudformation create-stack --template-body $template ...
```

---

## 2. S3 バケット作成が 409 エラーで失敗

**エラー**
```
A conflicting conditional operation is currently in progress against this resource.
```

**原因**
スタックを削除してすぐ同じバケット名で再作成しようとすると、AWS 内部でバケット名がロック状態のまま残っている。

**解決策**
- 60 秒以上待ってから再作成する
- または別のバケット名を使う

今回は `portfolio-01-gratitude-journal-2026` → `portfolio-01-gratitude-2026-v2` に変更して解決。

---

## 3. IAM スタックが権限不足で失敗

**エラー**
```
User: aws-cli-user is not authorized to perform: iam:GetUser
```

**原因**
AWS CLI 用の IAM ユーザー（`aws-cli-user`）に IAM 操作権限がなかった。

**解決策**
AWS コンソール → IAM → Users → `aws-cli-user` → Permissions → `IAMFullAccess` をアタッチ。

---

## 4. GitHub Actions で package-lock.json が見つからない

**エラー**
```
Dependencies lock file is not found in /home/runner/work/aws-portfolio/aws-portfolio.
```

**原因**
`actions/setup-node` の `cache: 'npm'` はリポジトリルートを探すが、モノレポ構成のためロックファイルがサブディレクトリにある。また、`defaults.run.working-directory` は `uses:` ステップには適用されない。

**解決策**
① `npm install` で `package-lock.json` を生成してコミット
② `setup-node` に `cache-dependency-path` を明示（build・deploy 両ジョブに必要）

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: '22'
    cache: 'npm'
    cache-dependency-path: 'aws-portfolio-01-static-site/react/package-lock.json'
```

---

## 5. ESLint エラーで CI ビルドが失敗

**エラー**
```
React Hook useEffect has a missing dependency: 'today'. react-hooks/exhaustive-deps
```

**原因**
CI 環境では `process.env.CI = true` のため、ESLint の警告がエラーとして扱われる。

**解決策**
`useEffect` の依存配列に `today` を追加。

```js
// Before
}, []);

// After
}, [today]);
```

---

## 6. GitHub Actions で aws-region が未設定エラー

**エラー**
```
Input required and not supplied: aws-region
```

**原因**
GitHub Secret `AWS_REGION` が空のまま登録されていた。

**解決策**
リージョンは機密情報ではないのでワークフローに直接ハードコード。

```yaml
aws-region: ap-northeast-1
```

---

## 7. S3 sync でバケット名が空エラー

**エラー**
```
Invalid bucket name "": Bucket name must match the regex ...
```

**原因**
GitHub Secret `S3_BUCKET_NAME` が登録されていなかった。

**解決策**
GitHub → Settings → Secrets and variables → Actions で以下を登録。

| Secret 名 | 値 |
|-----------|---|
| `S3_BUCKET_NAME` | `portfolio-01-gratitude-2026-v2` |
| `CLOUDFRONT_DISTRIBUTION_ID` | `E2NQ42ABXL6VYM` |

---

## 8. Node.js 20 非推奨警告

**警告**
```
Node.js 20 is deprecated. actions/checkout@v4, actions/setup-node@v4 are being forced to run on Node.js 24.
```

**原因**
ワークフローの `node-version: '20'` が非推奨になった。

**解決策**
`node-version: '22'` に変更。（`actions/checkout` 等のアクション自体の内部ランタイム警告は GitHub Actions 側の問題のため対処不要）
