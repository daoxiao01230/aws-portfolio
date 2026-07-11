[目次](./README.md) | 前へ: [Part 6 — CI/CD](./06-cicd.md) | 次へ: [Part 8 — 後片付け](./08-cleanup.md)

---

# Part 7 — 完成確認チェックリスト

実際に手を動かして、以下がすべてYESになることを確認する。

### インフラ
- [ ] `terraform plan`（またはCloudFormationの`describe-stacks`）で
      すべてのリソースが意図通り作成されている
- [ ] `curl -i https://<api_endpoint>/entries` が **401** を返す
      （認証なしアクセスが拒否される）

### バックエンド（Lambda直接テスト）
- [ ] `aws lambda invoke`でcreate_entryを呼び、DynamoDBに1件書き込まれる
- [ ] 同様にlist/update/deleteもそれぞれ意図通り動く
- [ ] テストで作ったダミーデータは削除して片付けておく
      （`aws dynamodb scan --table-name <table> --select COUNT`で件数確認）

### フロントエンド（実際のブラウザで）
- [ ] `https://<自分のドメインまたはCloudFrontドメイン>/` を開くと
      ログイン画面が表示される
- [ ] 「アカウントを作成する」→ メール・パスワード入力 → 登録できる
- [ ] メールに届いた確認コードを入力 → 確認が通る
- [ ] ログインできる（ログイン後、日記画面が表示される）
- [ ] 「今日」タブで日記を保存できる → 連続日数（streak）が1になる
- [ ] 「履歴」タブに保存した日記が表示される → 編集できる → 削除できる
- [ ] 「気づき」タブでも同様にCRUDができる
- [ ] 言語切り替えボタン（🌐）で日本語→英語→中国語→日本語と巡回する
- [ ] ログアウトボタン（⏻）でログイン画面に戻る

### CI/CD
- [ ] `backend/lambda/`配下を編集してpush → Lambda Deployだけ起動し成功する
- [ ] `frontend/`配下を編集してpush → Frontend Deployだけ起動し成功する
- [ ] デプロイ後、実際にブラウザで変更が反映されていることを確認する
      （CloudFrontのキャッシュ無効化が効いているか）

すべてチェックできたら、Phase 3は完成。

---

[目次](./README.md) | 前へ: [Part 6 — CI/CD](./06-cicd.md) | 次へ: [Part 8 — 後片付け](./08-cleanup.md)
