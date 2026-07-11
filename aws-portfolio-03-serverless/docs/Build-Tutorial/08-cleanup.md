[目次](./README.md) | 前へ: [Part 7 — 確認チェックリスト](./07-verification-checklist.md)

---

# Part 8 — 後片付け（リソースの削除）

学習が終わり、費用が気になる場合や作り直したい場合は、以下でリソースを削除する。
（現状のコストは`docs/Cost-Estimation.md`の通りほぼ$0.00/月なので、急いで
削除する必要は無いが、練習として一度壊してみるのもよい）

### Terraform版の削除

```bash
cd aws-portfolio-03-serverless/infrastructure/terraform
terraform destroy
```

S3バケットは`force_destroy = true`にしているため、中身のファイルごと
自動的に削除される。

### CloudFormation版の削除

**作った時と逆の順序**で削除する（依存関係があるため、順序を守らないと
「他のスタックから参照されている」エラーで削除に失敗する）。

```bash
cd aws-portfolio-03-serverless/infrastructure/cloudformation

aws cloudformation delete-stack --stack-name portfolio-03-iam-cicd
aws cloudformation delete-stack --stack-name portfolio-03-route53
aws cloudformation delete-stack --stack-name portfolio-03-cloudfront
aws cloudformation delete-stack --stack-name portfolio-03-acm --region us-east-1
aws cloudformation delete-stack --stack-name portfolio-03-s3
aws cloudformation delete-stack --stack-name portfolio-03-api
aws cloudformation delete-stack --stack-name portfolio-03-lambda
aws cloudformation delete-stack --stack-name portfolio-03-cognito
aws cloudformation delete-stack --stack-name portfolio-03-dynamodb
```

> 💡 S3バケットは中身が空でないと削除できないため、
> `aws s3 rm s3://<bucket-name> --recursive`で中身を空にしてから
> `delete-stack`を実行する必要がある場合がある。

削除後、`aws cloudformation describe-stacks`や AWSコンソールで
すべてのスタックが消えていることを確認する。

## おわりに

このチュートリアルに沿って進めれば、AIの助けを借りずにPhase 3を
ゼロから再現できるはず。もし途中で詰まった場合、実際にこのプロジェクトで
遭遇した問題と解決策は`docs/Architecture.md`・`docs/Frontend-Design.md`・
`infrastructure/terraform/README.md`にも記録してあるので、あわせて参照する。

---

[目次](./README.md) | 前へ: [Part 7 — 確認チェックリスト](./07-verification-checklist.md)
