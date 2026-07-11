# Phase 03 構築チュートリアル — ゼロから自分の手で完成させるガイド

このドキュメントは、**AIに頼らず自分の手だけでPhase 3（サーバーレス感謝日記）を
最初から構築できる**ことを目標にした実況型チュートリアルです。
[`../Architecture.md`](../Architecture.md)が「なぜこう設計したか」を説明する文書、
[`../../infrastructure/terraform/README.md`](../../infrastructure/terraform/README.md)が
「できあがったものの早見表」だとすると、この文書は「今この瞬間、何を打ち込めば
いいか」だけを追った手順書です。

## この文書の歩き方

- **AWSを触るのが初めて** → [Part 0](./00-prerequisites.md)から順番に読む
- **AWSアカウント・IAM・CLIは使ったことがある** → Part 0は読み飛ばして
  [Part 1](./01-overview.md)から
- インフラの作り方は **[Terraform版（Part 2）](./02-terraform.md)** と
  **[CloudFormation版（Part 3）](./03-cloudformation.md)** の2通りを用意した。
  どちらか片方だけ進めればOK（両方やってもよい）
- フロントエンドは **[まず動かす版（Part 4）](./04-frontend-quickstart.md)** と
  **[段階的に理解する版（Part 5）](./05-frontend-deep-dive.md)** の2通り。
  急いでいるならPart 4だけで完成する

## 目次

| Part | 内容 | 所要時間の目安 |
|---|---|---|
| [Part 0](./00-prerequisites.md) | 完全初心者向け準備（AWSアカウント・IAM・CLI・Terraform・Node.js） | 30分 |
| [Part 1](./01-overview.md) | 全体像 — 何を作るのか、各AWSサービスは何をする係なのか | 15分 |
| [Part 2](./02-terraform.md) | Terraformで作る（バックエンド → フロントエンド配信） | 60〜90分 |
| [Part 3](./03-cloudformation.md) | CloudFormationで作る（同じものを別ツールで） | 60〜90分 |
| [Part 4](./04-frontend-quickstart.md) | フロントエンド：まず動かす版（完成コードを貼って確認） | 20分 |
| [Part 5](./05-frontend-deep-dive.md) | フロントエンド：段階的に理解する版（なぜこの順で書いたか） | 20分 |
| [Part 6](./06-cicd.md) | GitHub Actionsで自動デプロイを設定する | 20分 |
| [Part 7](./07-verification-checklist.md) | 完成確認チェックリスト | 10分 |
| [Part 8](./08-cleanup.md) | 後片付け（リソースの削除） | 10分 |

## 進め方の全体図

```
Part 0 (任意) ─→ Part 1
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
    Part 2 (Terraform)     Part 3 (CloudFormation)
        └───────────┬───────────┘
                     ▼
        ┌───────────────────────┐
        ▼                       ▼
  Part 4 (まず動かす)     Part 5 (段階的に理解)
        └───────────┬───────────┘
                     ▼
                  Part 6 (CI/CD)
                     ▼
                  Part 7 (確認)
                     ▼
                  Part 8 (後片付け)
```

---

はじめる: [Part 0 — 完全初心者向け準備](./00-prerequisites.md) ／
急いでいる人は [Part 1 — 全体像](./01-overview.md) へ
