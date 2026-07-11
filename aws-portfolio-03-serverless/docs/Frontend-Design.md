# Phase 03 — Frontend Design

## Component structure

```
App.js
 ├─ (not authenticated) → AuthScreen.js
 │                          sign in / sign up / confirm code
 └─ (authenticated)     → JournalScreen.js
                            ├─ GratitudeTree.js   (pure SVG, no data fetching)
                            ├─ write tab          (create a gratitude entry)
                            ├─ history tab        (list/edit/delete gratitude entries)
                            └─ reflect tab        (create/list/edit/delete reflections)

src/auth/cognito.js   — thin Promise wrapper around amazon-cognito-identity-js
src/api/entries.js    — fetch wrapper for the HTTP API (attaches JWT, handles 401)
src/config.js         — reads REACT_APP_* env vars (set from terraform outputs)
```

`App.js` only decides which top-level screen to render — it holds no journal
data itself. All entry state (`entries`, tabs, edit-in-progress text) lives in
`JournalScreen.js`; there was no need for Context or a global store at this
scale (one screen owns all the data it uses).

## Auth flow

Uses `amazon-cognito-identity-js` directly rather than AWS Amplify. Amplify
would pull in more dependencies and its own state-management conventions
(`Hub`, `Auth` singleton) for a login flow that's only 3 screens; the raw SDK
keeps the JWT mechanics visible, which matters here since the user is using
this project to learn how Cognito auth actually works, not to learn Amplify's
abstraction over it.

- **Sign up** → Cognito sends a confirmation code by email → **confirm** →
  **sign in** (`USER_SRP_AUTH` — the SDK never sends the raw password over the
  wire, it does a Secure Remote Password exchange).
- The SDK caches the resulting tokens in `localStorage` under keys prefixed
  `CognitoIdentityServiceProvider.<clientId>.*` — this repo's code never reads
  or writes those keys directly, only through `CognitoUser`/`CognitoUserPool`
  methods (`getSession`, `getCurrentUser`, `signOut`).
- `getIdToken()` (`auth/cognito.js`) calls `user.getSession()`, which returns
  the cached token immediately if it's still valid, or silently refreshes it
  via the refresh token if expired — the app never manually manages token
  expiry.
- **On the first API call** (`JournalScreen`'s initial `listEntries()`), a
  `401` response is treated as "session invalid" and triggers `signOut()` +
  returning to `AuthScreen` — this is also what happens if `App.js`'s initial
  `getCurrentUser()` check was a false positive (e.g. a stale cached user with
  an unrecoverable session). There's deliberately no separate "am I still
  logged in?" check on mount; the first real API call *is* that check.

## State management: plain `useState`, no Redux/Context

`JournalScreen` is the only component that needs journal data, so it owns
`entries`/`activeTab`/`editingId`/etc. directly. If a second screen ever needs
the same entries (e.g. a dashboard), that'd be the point to introduce a shared
store — doing it now would be solving a problem that doesn't exist yet.

## i18n: inline translation dictionary, not a library

Copied Phase 1's pattern verbatim: a `translations = { ja: {...}, en: {...},
zh: {...} }` object plus a `LANG_CYCLE` array and a button that cycles through
it (rather than a dropdown). No `react-i18next` or similar — three languages,
~20 strings each, all in one file is simpler than wiring up a library for this
scale, and it matches the sibling Phase 1 app so the two feel like the same
product family.

## Data model on the frontend: filtering, not separate endpoints

The backend's `entries` table holds two conceptually different kinds of
writes — `entryType: "gratitude"` (write/history tabs) and
`entryType: "reflection"` (reflect tab) — see
[`../docs/Architecture.md`](../docs/Architecture.md) for why this is one table
instead of two. The frontend never asks the API for "only gratitude entries"
or "only reflections"; `listEntries()` always returns everything for the
signed-in user, and `JournalScreen` derives:

```js
const gratitudeEntries = entries.filter((e) => !isReflection(e));
const reflectionEntries = entries.filter(isReflection);
```

on every render. This keeps the API surface at 4 routes instead of 6+, at the
cost of shipping slightly more data per `GET /entries` than a tab strictly
needs — acceptable at this app's scale (a personal journal, not a
high-traffic product).

## Streak & day-numbering logic

Two small pieces of derived state are worth documenting because they're not
obvious from reading the JSX alone:

**Streak** (`calculateStreak` in `JournalScreen.js`) — builds a `Set` of
calendar-date strings (`YYYY-MM-DD`) from every *gratitude* entry's
`createdAt`, then walks backward from today counting consecutive days present
in that set. Phase 1's original version assumed exactly one entry per day
(a plain object keyed by date); Phase 3's backend allows multiple entries per
day, so this was rewritten around a `Set` (membership check, not entry count)
to preserve the same "did I write *something* today" semantics.

**Day-number badges** (`dayNumber(atIso, firstDateKey)` in `JournalScreen.js`)
— shown in the reflect tab as "Day N". `firstDateKey` is computed as
`entries[entries.length - 1].createdAt`'s date — i.e. the *oldest entry of
either type*, not the oldest gratitude entry specifically. This was a real bug
fix: an earlier version anchored day-numbering to the oldest **gratitude**
entry only, which produced a negative day number (`"-1日目"`) for a reflection
written before any gratitude entry existed. Anchoring to the oldest entry
overall (which the API guarantees is `entries[entries.length - 1]`, since
`list_entries` always returns newest-first — see the DynamoDB section in
`../docs/Architecture.md`) fixes this for good, not just for the specific
scenario that surfaced it.

## Known limitations

- No client-side form validation beyond "non-empty textarea" — the backend
  rejects empty `content` with a 400, but the UI doesn't pre-empt that with
  its own message beyond disabling the save button.
- `AuthScreen.js` is Japanese-only (no i18n cycling) — it wasn't part of the
  Phase 1 comparison that prompted `JournalScreen`'s i18n work, so it was left
  as-is rather than scope-creeping the UI-parity pass.
- No automated component tests (Jest/RTL). Verified via a real signup → login
  → CRUD → logout session in a browser, plus Playwright screenshots taken
  during development (mocking `/entries` responses to reach states that need
  a real Cognito session to trigger naturally) — not by a checked-in test
  suite.

---

# Phase 03 — フロントエンド設計（日本語）

## コンポーネント構成

```
App.js
 ├─ (未認証時)  → AuthScreen.js
 │                 ログイン・サインアップ・確認コード入力
 └─ (認証済み)  → JournalScreen.js
                    ├─ GratitudeTree.js   (純粋なSVG、データ取得なし)
                    ├─ 今日タブ           (感謝エントリの作成)
                    ├─ 履歴タブ           (感謝エントリの一覧・編集・削除)
                    └─ 気づきタブ         (気づきの作成・一覧・編集・削除)

src/auth/cognito.js   — amazon-cognito-identity-jsを薄くPromiseでラップ
src/api/entries.js    — HTTP API向けfetchラッパー（JWT付与・401ハンドリング）
src/config.js         — REACT_APP_ 環境変数の読み取り（terraform outputsから設定）
```

`App.js`はトップレベルでどちらの画面を表示するかを決めるだけで、日記データ自体は
持たない。エントリの状態（`entries`・タブ・編集中テキスト）はすべて
`JournalScreen.js`が保持している。この規模ではContextやグローバルストアを
導入する必要はなかった（1つの画面が使うデータをすべて自分で持っているため）。

## 認証フロー

AWS AmplifyではなくAmazon `amazon-cognito-identity-js`を直接使用している。
Amplifyはログイン画面3つ程度のフローに対して、追加の依存関係と独自の状態管理の
作法（`Hub`・`Auth`シングルトン）を持ち込むことになる。生のSDKを使うことで
JWTの仕組みが見える形になっており、これはユーザーがこのプロジェクトを通じて
Amplifyの抽象化ではなく「Cognito認証が実際どう動くか」を学びたいという文脈で
意味を持つ。

- **サインアップ** → Cognitoがメールで確認コードを送信 → **確認** →
  **ログイン**（`USER_SRP_AUTH` — SDKは生のパスワードをネットワークに送信せず、
  Secure Remote Password方式でやり取りする）。
- SDKは発行されたトークンを`localStorage`の
  `CognitoIdentityServiceProvider.<clientId>.*`というキーにキャッシュする。
  このリポジトリのコードはこれらのキーを直接読み書きせず、常に
  `CognitoUser`/`CognitoUserPool`のメソッド（`getSession`・`getCurrentUser`・
  `signOut`）経由でのみ触れる。
- `getIdToken()`（`auth/cognito.js`）は`user.getSession()`を呼び出し、
  キャッシュされたトークンがまだ有効ならそのまま返し、期限切れならリフレッシュ
  トークンで裏側で自動更新する。アプリ側でトークンの有効期限を手動管理する
  コードは存在しない。
- **最初のAPI呼び出し時**（`JournalScreen`の初回`listEntries()`）に`401`が
  返ってきた場合、「セッションが無効」とみなして`signOut()`を呼び
  `AuthScreen`へ戻す。これは`App.js`のマウント時`getCurrentUser()`チェックが
  偽陽性だった場合（キャッシュされたユーザー情報はあるがセッションが
  復旧不能な場合など）にも同じ経路で処理される。マウント時に「まだログイン
  しているか」を別途チェックする処理は意図的に置いていない。最初の実際の
  API呼び出しそのものがそのチェックを兼ねる。

## 状態管理: 素の`useState`のみ、Redux/Contextなし

ジャーナルデータを必要とするコンポーネントは`JournalScreen`だけなので、
`entries`/`activeTab`/`editingId`等をそのまま自分で持たせている。将来
別の画面（ダッシュボード等）が同じエントリデータを必要とするようになった時が
共有ストアを導入すべきタイミングであり、今の時点でそれをやるのは
まだ存在しない問題を解決することになる。

## 多言語対応: ライブラリではなくインラインの辞書

Phase 1のパターンをそのまま踏襲: `translations = { ja: {...}, en: {...},
zh: {...} }`というオブジェクトと`LANG_CYCLE`配列、それを順番に切り替える
ボタン（ドロップダウンではなく）。`react-i18next`等は使っていない —
3言語・各20語程度をこの規模でライブラリ化するより1ファイルにまとめた方が
シンプルであり、また兄弟にあたるPhase 1アプリと同じ方式にすることで
「同じプロダクトファミリー」としての一貫性を保っている。

## フロントエンドでのデータモデル: 別エンドポイントではなくフィルタリング

バックエンドの`entries`テーブルには、概念的に異なる2種類の書き込みが
含まれる — `entryType: "gratitude"`（今日/履歴タブ）と
`entryType: "reflection"`（気づきタブ）。1つのテーブルにした理由は
[`../docs/Architecture.md`](../docs/Architecture.md)を参照。フロントエンドは
「感謝エントリだけ」「気づきだけ」をAPIに問い合わせることはなく、
`listEntries()`は常にサインイン中ユーザーの全エントリを返し、
`JournalScreen`が毎回の描画時に以下のように振り分ける:

```js
const gratitudeEntries = entries.filter((e) => !isReflection(e));
const reflectionEntries = entries.filter(isReflection);
```

これによりAPIのルート数は6本以上ではなく4本のまま維持できる。代わりに
`GET /entries`は各タブが厳密に必要とする量よりやや多くのデータを返すことに
なるが、このアプリの規模（個人の日記であり高トラフィックな製品ではない）では
許容範囲と判断した。

## 連続日数・日数バッジのロジック

2つの派生状態はJSXを読むだけでは分かりにくいため、明記しておく価値がある。

**連続日数**（`JournalScreen.js`の`calculateStreak`）— すべての**感謝**
エントリの`createdAt`から日付文字列（`YYYY-MM-DD`）の`Set`を作り、今日から
過去に向かって、その`Set`に連続して含まれる日数を数える。Phase 1のオリジナル版は
1日1エントリを前提としていた（日付をキーにした単純なオブジェクト）が、
Phase 3のバックエンドは1日に複数エントリを許容するため、「今日"何かを"書いたか」
という同じ意味を保つために、エントリ数ではなく`Set`の存在チェックとして
書き直した。

**日数バッジ**（`JournalScreen.js`の`dayNumber(atIso, firstDateKey)`）—
気づきタブで「N日目」として表示される。`firstDateKey`は
`entries[entries.length - 1].createdAt`の日付、つまり**種別を問わず
最古のエントリ**から計算している（感謝エントリの中で最古、ではない）。
これは実際に発見・修正したバグに基づく: 以前のバージョンは日数の基準を
最古の**感謝**エントリのみに固定しており、感謝エントリが1件もない状態で
気づきを書いた場合に負の日数（「-1日目」）が表示される不具合があった。
種別を問わず全体の最古エントリを基準にする（`list_entries`は常に新しい順で
返す仕様のため`entries[entries.length - 1]`が保証される — 詳細は
`../docs/Architecture.md`のDynamoDBの節を参照）ことで、発覚した特定の
シナリオだけでなく根本的に修正されている。

## 既知の制約

- クライアント側のバリデーションは「テキストエリアが空でない」以上のことは
  していない。バックエンドは空の`content`を400で拒否するが、UI側では
  保存ボタンの無効化以上の事前メッセージは出していない。
- `AuthScreen.js`は日本語のみ（多言語切替なし）— `JournalScreen`の多言語対応は
  Phase 1とのUI比較で指摘されて対応したものであり、AuthScreenはその対象外
  だったためスコープを広げずそのままにしてある。
- コンポーネントの自動テスト（Jest/RTL）は未整備。実際のブラウザでの
  サインアップ→ログイン→CRUD→ログアウトの一連のセッションと、開発中に撮った
  Playwrightスクリーンショット（実際のCognitoセッションがないと到達できない
  状態は`/entries`のレスポンスをモックして確認）による検証のみで、
  リポジトリにチェックインされたテストスイートによるものではない。
