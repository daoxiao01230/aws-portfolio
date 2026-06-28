# package.json と package-lock.json

## package.json — プロジェクトの設計書（人間が書く）

```json
{
  "name": "aws-portfolio-01-static-site",  // アプリ名
  "version": "1.0.0",
  "scripts": {
    "start": "react-scripts start",        // npm start で開発サーバー起動
    "build": "react-scripts build"         // npm run build で本番用ファイルを build/ に生成
  },
  "dependencies": {
    "react": "^18.2.0"                     // 使うライブラリと「だいたいのバージョン」を指定
  }
}
```

ポイント：`"^18.2.0"` は「18.x.x の最新」という意味で、バージョンに幅がある。

---

## package-lock.json — 依存関係の固定リスト（npm が自動生成）

`npm install` を実行すると npm が自動で生成する。

**役割：**
package.json が「React を使う」と書いているなら、
package-lock.json は「React 18.2.0 を使う。
そのために必要な scheduler 0.23.0、
loose-envify 1.4.0、
js-tokens 4.0.0…」と
全ての依存ライブラリのバージョンを完全に固定する。

**なぜ必要か：**
- 自分のPC・チームメンバーのPC・GitHub Actions（CI）で全く同じバージョンが入ることを保証する
- `npm ci`（CI/CD で使うコマンド）は package-lock.json がないと動かない
- 「自分の PC では動くのに CI で動かない」を防ぐ

**編集してはいけない：**
`npm install` が自動管理するファイルなので手動で書き換えない。

---

## まとめ

| ファイル | 誰が書く | 役割 |
|---------|---------|------|
| package.json | 開発者（人間） | 使うライブラリの「だいたいのバージョン」を宣言 |
| package-lock.json | npm（自動生成） | 全ライブラリの「完全に固定されたバージョン」を記録 |

両方 Git にコミットするのが正しい。
