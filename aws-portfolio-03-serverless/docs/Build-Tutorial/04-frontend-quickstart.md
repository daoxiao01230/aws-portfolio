[目次](./README.md) | 前へ: [Part 2 — Terraform](./02-terraform.md) / [Part 3 — CloudFormation](./03-cloudformation.md) | 次へ: [Part 5 — フロントエンド(段階的に理解)](./05-frontend-deep-dive.md) / [Part 6 — CI/CD](./06-cicd.md)

---

# Part 4 — フロントエンド：まず動かす版

このPartは「仕組みはあとで理解するとして、まず手元で動くものを作りたい」人向け。
完成しているコードをそのまま貼り付けて、実際に動かすところまでを最短で進める。
「なぜこの順番・この設計にしたか」を理解したい場合はPart 5を読む（このPartを
先に終わらせてからでも、Part 5だけを読んでも、どちらでもよい）。

### 4-0. フォルダとpackage.jsonを作る

```bash
mkdir -p aws-portfolio-03-serverless/frontend/public
mkdir -p aws-portfolio-03-serverless/frontend/src/auth
mkdir -p aws-portfolio-03-serverless/frontend/src/api
mkdir -p aws-portfolio-03-serverless/frontend/src/components
cd aws-portfolio-03-serverless/frontend
```

`package.json`:
```json
{
  "name": "aws-portfolio-03-serverless",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "amazon-cognito-identity-js": "^6.3.12",
    "react": "^19.2.7",
    "react-dom": "^19.2.7",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
```

`public/index.html`:
```html
<!DOCTYPE html>
<html lang="ja">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="description" content="Serverless Gratitude Journal — Phase 03" />
    <title>Gratitude Journal (Serverless)</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
```

`src/index.css`:
```css
body {
  margin: 0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
```

`src/index.js`:
```jsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```

### 4-1. src/config.js

```js
// ローカル開発: terraform apply の outputs (cognito_user_pool_id / cognito_user_pool_client_id / api_endpoint)
// を .env.local に REACT_APP_ プレフィックス付きで設定する
const config = {
  region: process.env.REACT_APP_AWS_REGION || 'ap-northeast-1',
  userPoolId: process.env.REACT_APP_COGNITO_USER_POOL_ID,
  userPoolClientId: process.env.REACT_APP_COGNITO_CLIENT_ID,
  apiEndpoint: process.env.REACT_APP_API_ENDPOINT,
};

export default config;
```

### 4-2. src/auth/cognito.js

```js
import {
  CognitoUserPool,
  CognitoUser,
  AuthenticationDetails,
} from 'amazon-cognito-identity-js';
import config from '../config';

const userPool = new CognitoUserPool({
  UserPoolId: config.userPoolId,
  ClientId: config.userPoolClientId,
});

export function signUp(email, password) {
  return new Promise((resolve, reject) => {
    userPool.signUp(email, password, [], null, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
}

export function confirmSignUp(email, code) {
  const user = new CognitoUser({ Username: email, Pool: userPool });
  return new Promise((resolve, reject) => {
    user.confirmRegistration(code, true, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
}

export function signIn(email, password) {
  const user = new CognitoUser({ Username: email, Pool: userPool });
  const authDetails = new AuthenticationDetails({
    Username: email,
    Password: password,
  });
  return new Promise((resolve, reject) => {
    user.authenticateUser(authDetails, {
      onSuccess: (session) => resolve(session),
      onFailure: (err) => reject(err),
    });
  });
}

export function signOut() {
  const user = userPool.getCurrentUser();
  if (user) user.signOut();
}

export function getIdToken() {
  const user = userPool.getCurrentUser();
  if (!user) return Promise.resolve(null);

  return new Promise((resolve, reject) => {
    user.getSession((err, session) => {
      if (err) reject(err);
      else resolve(session.isValid() ? session.getIdToken().getJwtToken() : null);
    });
  });
}

export function getCurrentUser() {
  return userPool.getCurrentUser();
}
```

### 4-3. src/api/entries.js

```js
import config from '../config';
import { getIdToken } from '../auth/cognito';

async function authHeaders() {
  const token = await getIdToken();
  return {
    'Content-Type': 'application/json',
    Authorization: token,
  };
}

async function request(path, options = {}) {
  const res = await fetch(`${config.apiEndpoint}${path}`, {
    ...options,
    headers: { ...(await authHeaders()), ...options.headers },
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`${res.status} ${body}`);
  }
  return res.status === 204 ? null : res.json();
}

export function listEntries() {
  return request('/entries');
}

export function createEntry(content, entryType = 'gratitude') {
  return request('/entries', {
    method: 'POST',
    body: JSON.stringify({ content, entryType }),
  });
}

export function updateEntry(entryId, content) {
  return request(`/entries/${encodeURIComponent(entryId)}`, {
    method: 'PUT',
    body: JSON.stringify({ content }),
  });
}

export function deleteEntry(entryId) {
  return request(`/entries/${encodeURIComponent(entryId)}`, {
    method: 'DELETE',
  });
}
```

### 4-4. src/components/GratitudeTree.js

```jsx
export default function GratitudeTree({ streak }) {
  const level = Math.min(streak, 30);
  const leaves = Math.floor(level * 2.5);
  const generateLeaves = (count) => {
    const items = [];
    for (let i = 0; i < count; i++) {
      const angle = (i / count) * 360;
      const radius = 20 + (i % 3) * 14;
      const x = 50 + radius * Math.cos((angle * Math.PI) / 180);
      const y = 55 - radius * Math.abs(Math.sin((angle * Math.PI) / 180));
      const size = 6 + (i % 4) * 2;
      const colors = ["#a8d8a8", "#7bc47b", "#5aad5a", "#c8e6c8", "#b8ddb8", "#e8f5e8"];
      items.push(
        <ellipse key={i} cx={x} cy={y} rx={size} ry={size * 0.7}
          fill={colors[i % colors.length]} opacity={0.85}
          transform={`rotate(${angle + 20}, ${x}, ${y})`} />
      );
    }
    return items;
  };
  const trunkHeight = 20 + level * 0.8;
  return (
    <svg viewBox="0 0 100 100" width="120" height="120" style={{ filter: "drop-shadow(0 2px 8px rgba(0,0,0,0.08))", flexShrink: 0 }}>
      <ellipse cx="50" cy="95" rx="22" ry="5" fill="#d4b896" opacity="0.4" />
      <rect x="45" y={100 - trunkHeight} width="10" height={trunkHeight - 5} rx="4" fill="#c4956a" />
      {leaves > 0 && generateLeaves(leaves)}
      {streak === 0 && <circle cx="50" cy="60" r="18" fill="#e8f5e8" stroke="#a8d8a8" strokeWidth="2" strokeDasharray="4 3" />}
      {streak === 0 && <text x="50" y="65" textAnchor="middle" fontSize="16" fill="#a8d8a8">🌱</text>}
    </svg>
  );
}
```

### 4-5. src/components/AuthScreen.js

```jsx
import { useState } from 'react';
import { signUp, confirmSignUp, signIn } from '../auth/cognito';

const INPUT = {
  width: '100%', boxSizing: 'border-box', padding: '12px 14px', marginTop: 8,
  borderRadius: 12, border: '1.5px solid #d4c5e6', fontSize: 15,
  color: '#3d2b52', fontFamily: 'inherit', outline: 'none', background: 'rgba(255,255,255,0.8)',
};

const BUTTON = {
  width: '100%', marginTop: 16, padding: '13px', borderRadius: 12, border: 'none',
  background: 'linear-gradient(135deg, #a07ac4, #7a5fa0)', color: '#fff',
  fontSize: 15, fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit', letterSpacing: '0.05em',
};

const LINK = {
  background: 'none', border: 'none', color: '#7a5fa0', fontSize: 13,
  cursor: 'pointer', fontFamily: 'inherit', marginTop: 14, textDecoration: 'underline',
};

export default function AuthScreen({ onAuthSuccess }) {
  const [mode, setMode] = useState('signIn'); // signIn | signUp | confirm
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  const handleSignIn = async (e) => {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      await signIn(email, password);
      onAuthSuccess();
    } catch (err) {
      setError(err.message || String(err));
    } finally {
      setBusy(false);
    }
  };

  const handleSignUp = async (e) => {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      await signUp(email, password);
      setMode('confirm');
    } catch (err) {
      setError(err.message || String(err));
    } finally {
      setBusy(false);
    }
  };

  const handleConfirm = async (e) => {
    e.preventDefault();
    setError('');
    setBusy(true);
    try {
      await confirmSignUp(email, code);
      setMode('signIn');
      setCode('');
    } catch (err) {
      setError(err.message || String(err));
    } finally {
      setBusy(false);
    }
  };

  const titles = {
    signIn: 'ログイン',
    signUp: 'アカウント登録',
    confirm: '確認コードを入力',
  };

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(160deg, #fdf4ee 0%, #f0eaf8 50%, #eaf2f8 100%)',
      fontFamily: "'Georgia', 'Noto Serif SC', 'Noto Serif JP', serif",
      display: 'flex', justifyContent: 'center', alignItems: 'flex-start', padding: '60px 16px',
    }}>
      <div style={{
        width: '100%', maxWidth: 380,
        background: 'rgba(255,255,255,0.75)', borderRadius: 20,
        border: '1px solid rgba(255,255,255,0.9)', boxShadow: '0 4px 24px rgba(90,62,107,0.08)',
        padding: 28,
      }}>
        <h1 style={{ margin: 0, fontSize: 22, fontWeight: 700, color: '#5a3e6b' }}>
          感謝日記
        </h1>
        <p style={{ margin: '6px 0 20px', fontSize: 13, color: '#9b85b0' }}>
          {titles[mode]}
        </p>

        {mode === 'signIn' && (
          <form onSubmit={handleSignIn}>
            <input style={INPUT} type="email" placeholder="メールアドレス" value={email}
              onChange={e => setEmail(e.target.value)} required />
            <input style={INPUT} type="password" placeholder="パスワード" value={password}
              onChange={e => setPassword(e.target.value)} required />
            <button style={BUTTON} type="submit" disabled={busy}>ログイン</button>
            <button type="button" style={LINK} onClick={() => { setMode('signUp'); setError(''); }}>
              アカウントを作成する
            </button>
          </form>
        )}

        {mode === 'signUp' && (
          <form onSubmit={handleSignUp}>
            <input style={INPUT} type="email" placeholder="メールアドレス" value={email}
              onChange={e => setEmail(e.target.value)} required />
            <input style={INPUT} type="password" placeholder="パスワード（8文字以上・大小英数字を含む）" value={password}
              onChange={e => setPassword(e.target.value)} required minLength={8} />
            <button style={BUTTON} type="submit" disabled={busy}>登録する</button>
            <button type="button" style={LINK} onClick={() => { setMode('signIn'); setError(''); }}>
              ログイン画面へ戻る
            </button>
          </form>
        )}

        {mode === 'confirm' && (
          <form onSubmit={handleConfirm}>
            <p style={{ fontSize: 13, color: '#9b85b0', margin: '0 0 8px' }}>
              {email} に届いた確認コードを入力してください
            </p>
            <input style={INPUT} type="text" placeholder="確認コード" value={code}
              onChange={e => setCode(e.target.value)} required />
            <button style={BUTTON} type="submit" disabled={busy}>確認する</button>
          </form>
        )}

        {error && (
          <div style={{ marginTop: 14, fontSize: 13, color: '#b04040' }}>{error}</div>
        )}
      </div>
    </div>
  );
}
```

### 4-6. src/components/JournalScreen.js

これが一番大きいファイル。感謝日記の「今日・履歴・気づき」3タブすべての
表示とCRUD操作をここに書く。

```jsx
import { useState, useEffect } from 'react';
import { listEntries, createEntry, updateEntry, deleteEntry } from '../api/entries';
import { signOut } from '../auth/cognito';
import GratitudeTree from './GratitudeTree';

const translations = {
  ja: {
    appName: "感謝日記", subtitle: "毎日の感謝を記録して、幸せを積み重ねよう",
    todayPrompt: "今日、何に感謝しますか？", placeholder: "感謝していること1つを書いてみよう...",
    save: "保存する", saved: "保存しました ✓", streak: "連続日数",
    noEntries: "まだ記録がありません。今日から始めましょう！", today: "今日",
    langNext: "EN", formatDate: (d) => `${d.getMonth() + 1}月${d.getDate()}日`,
    last7: "直近7日間", writeTab: "✍️ 今日", historyTab: "📖 履歴", reflectTab: "🌿 気づき",
    reflectTitle: "私の成長の気づき", reflectSubtitle: "日記を書いて気づいた心の変化を記録",
    reflectPlaceholder: "今、どんな気づきがありますか？変化を書いてみましょう...",
    reflectSave: "気づきを保存", reflectSaved: "保存しました ✓",
    reflectEmpty: "まだ気づきがありません。いつでも記録できます",
    dayLabel: (n) => `${n}日目`,
    signOut: "ログアウト", edit: "編集", delete: "削除", cancel: "キャンセル",
    loading: "読み込み中…",
  },
  en: {
    appName: "Gratitude Journal", subtitle: "Notice the good, grow your joy",
    todayPrompt: "What are you grateful for today?", placeholder: "Write one thing you're grateful for...",
    save: "Save", saved: "Saved ✓", streak: "Day Streak",
    noEntries: "No entries yet — start today!", today: "Today",
    langNext: "中文", formatDate: (d) => d.toLocaleDateString("en-US", { month: "short", day: "numeric" }),
    last7: "Last 7 days", writeTab: "✍️ Today", historyTab: "📖 History", reflectTab: "🌿 Growth",
    reflectTitle: "My Growth Journal", reflectSubtitle: "Record how journaling is changing you",
    reflectPlaceholder: "What shift have you noticed? Write your reflection...",
    reflectSave: "Save Reflection", reflectSaved: "Saved ✓",
    reflectEmpty: "No reflections yet — write one whenever you feel a change",
    dayLabel: (n) => `Day ${n}`,
    signOut: "Sign Out", edit: "Edit", delete: "Delete", cancel: "Cancel",
    loading: "Loading…",
  },
  zh: {
    appName: "感恩日记", subtitle: "每天记录美好，积累幸福",
    todayPrompt: "今天你感恩什么？", placeholder: "写下一件让你感恩的事...",
    save: "保存", saved: "已保存 ✓", streak: "连续天数",
    noEntries: "还没有记录，今天开始吧！", today: "今天",
    langNext: "日本語", formatDate: (d) => `${d.getMonth() + 1}月${d.getDate()}日`,
    last7: "近7天", writeTab: "✍️ 今日", historyTab: "📖 历史", reflectTab: "🌿 感悟",
    reflectTitle: "我的成长感悟", reflectSubtitle: "记录写日记后内心的变化",
    reflectPlaceholder: "此刻有什么感悟？写下你注意到的变化...",
    reflectSave: "保存感悟", reflectSaved: "已保存 ✓",
    reflectEmpty: "还没有感悟，随时记录你的变化吧",
    dayLabel: (n) => `第 ${n} 天`,
    signOut: "退出登录", edit: "编辑", delete: "删除", cancel: "取消",
    loading: "加载中…",
  },
};

const LANG_CYCLE = ["ja", "en", "zh"];
const CARD = { width: "100%", boxSizing: "border-box", padding: "0 16px" };

function getDateKey(iso) {
  return new Date(iso).toISOString().split("T")[0];
}

function isReflection(entry) {
  return entry.entryType === "reflection";
}

function calculateStreak(gratitudeEntries) {
  const daysWithEntry = new Set(gratitudeEntries.map((e) => getDateKey(e.createdAt)));
  let streak = 0;
  let d = new Date();
  for (;;) {
    const key = d.toISOString().split("T")[0];
    if (daysWithEntry.has(key)) {
      streak++;
      d.setDate(d.getDate() - 1);
    } else break;
  }
  return streak;
}

function dayNumber(atIso, firstDateKey) {
  if (!firstDateKey) return 1;
  const start = new Date(firstDateKey + "T00:00:00");
  const at = new Date(atIso);
  return Math.floor((at - start) / (1000 * 60 * 60 * 24)) + 1;
}

export default function JournalScreen({ onSignOut }) {
  const [langIdx, setLangIdx] = useState(0);
  const [entries, setEntries] = useState([]);
  const [activeTab, setActiveTab] = useState("write");
  const [newText, setNewText] = useState("");
  const [justSaved, setJustSaved] = useState(false);
  const [reflectText, setReflectText] = useState("");
  const [reflectSaved, setReflectSaved] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [editText, setEditText] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const lang = LANG_CYCLE[langIdx];
  const t = translations[lang];
  const today = new Date().toISOString().split("T")[0];

  const load = async () => {
    setLoading(true);
    setError("");
    try {
      const items = await listEntries();
      setEntries(items);
    } catch (err) {
      if (String(err.message).startsWith("401")) {
        signOut();
        onSignOut();
        return;
      }
      setError(err.message || String(err));
    } finally {
      setLoading(false);
    }
  };

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => { load(); }, []);

  const gratitudeEntries = entries.filter((e) => !isReflection(e));
  const reflectionEntries = entries.filter(isReflection);
  const streak = calculateStreak(gratitudeEntries);
  const firstDate = entries.length > 0
    ? getDateKey(entries[entries.length - 1].createdAt)
    : null;

  const handleCreate = async () => {
    if (!newText.trim()) return;
    try {
      const entry = await createEntry(newText.trim(), "gratitude");
      setEntries([entry, ...entries]);
      setNewText("");
      setJustSaved(true);
      setTimeout(() => setJustSaved(false), 1500);
    } catch (err) {
      setError(err.message || String(err));
    }
  };

  const handleSaveReflection = async () => {
    if (!reflectText.trim()) return;
    try {
      const entry = await createEntry(reflectText.trim(), "reflection");
      setEntries([entry, ...entries]);
      setReflectText("");
      setReflectSaved(true);
      setTimeout(() => setReflectSaved(false), 1500);
    } catch (err) {
      setError(err.message || String(err));
    }
  };

  const handleUpdate = async (entryId) => {
    try {
      await updateEntry(entryId, editText.trim());
      setEntries(entries.map((e) => (e.entryId === entryId ? { ...e, content: editText.trim() } : e)));
      setEditingId(null);
    } catch (err) {
      setError(err.message || String(err));
    }
  };

  const handleDelete = async (entryId) => {
    try {
      await deleteEntry(entryId);
      setEntries(entries.filter((e) => e.entryId !== entryId));
    } catch (err) {
      setError(err.message || String(err));
    }
  };

  const handleSignOut = () => {
    signOut();
    onSignOut();
  };

  const cycleLang = () => setLangIdx((langIdx + 1) % LANG_CYCLE.length);

  const TABS = ["write", "history", "reflect"];

  return (
    <div style={{
      minHeight: "100vh",
      background: "linear-gradient(160deg, #fdf4ee 0%, #f0eaf8 50%, #eaf2f8 100%)",
      fontFamily: "'Georgia', 'Noto Serif SC', 'Noto Serif JP', serif",
      display: "flex", flexDirection: "column", alignItems: "center",
      padding: "0 0 40px",
    }}>
      <div style={{ width: "100%", maxWidth: 430, display: "flex", flexDirection: "column" }}>

        <div style={{ ...CARD, padding: "28px 16px 0", display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
          <div style={{ flex: 1, minWidth: 0 }}>
            <h1 style={{ margin: 0, fontSize: 24, fontWeight: 700, color: "#5a3e6b", letterSpacing: "0.06em", lineHeight: 1.2 }}>
              {t.appName}
            </h1>
            <p style={{ margin: "4px 0 0", fontSize: 13, color: "#9b85b0", fontStyle: "italic" }}>{t.subtitle}</p>
          </div>
          <div style={{ display: "flex", gap: 8, flexShrink: 0, marginLeft: 12 }}>
            <button onClick={cycleLang} title={t.langNext} aria-label={t.langNext} style={{
              background: "rgba(255,255,255,0.7)", border: "1.5px solid #d4c5e6",
              borderRadius: "50%", width: 32, height: 32, fontSize: 15, color: "#7a5fa0",
              cursor: "pointer", fontFamily: "inherit", display: "flex", alignItems: "center", justifyContent: "center", padding: 0,
            }}>🌐</button>
            <button onClick={handleSignOut} title={t.signOut} aria-label={t.signOut} style={{
              background: "rgba(255,255,255,0.7)", border: "1.5px solid #d4c5e6",
              borderRadius: "50%", width: 32, height: 32, fontSize: 15, color: "#7a5fa0",
              cursor: "pointer", fontFamily: "inherit", display: "flex", alignItems: "center", justifyContent: "center", padding: 0,
            }}>⏻</button>
          </div>
        </div>

        <div style={{ ...CARD, marginTop: 16 }}>
          <div style={{
            background: "rgba(255,255,255,0.65)", borderRadius: 20,
            border: "1px solid rgba(255,255,255,0.8)", boxShadow: "0 4px 24px rgba(90,62,107,0.08)",
            padding: "20px", display: "flex", alignItems: "center", gap: 12,
          }}>
            <GratitudeTree streak={streak} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontSize: 42, fontWeight: 800, color: "#5a3e6b", lineHeight: 1 }}>{streak}</div>
              <div style={{ fontSize: 14, color: "#9b85b0", marginTop: 4 }}>{t.streak}</div>
              <div style={{ marginTop: 10, display: "flex", gap: 3, flexWrap: "nowrap" }}>
                {[...Array(7)].map((_, i) => {
                  const d = new Date();
                  d.setDate(d.getDate() - (6 - i));
                  const key = d.toISOString().split("T")[0];
                  const has = gratitudeEntries.some((e) => getDateKey(e.createdAt) === key);
                  return (
                    <div key={i} style={{
                      width: 24, height: 24, borderRadius: 6, flexShrink: 0,
                      background: has ? "#7bc47b" : "rgba(180,160,200,0.2)",
                      border: key === today ? "2px solid #7a5fa0" : "none",
                      display: "flex", alignItems: "center", justifyContent: "center",
                      fontSize: 9, color: has ? "#fff" : "transparent",
                    }}>{has ? "✓" : "·"}</div>
                  );
                })}
              </div>
              <div style={{ fontSize: 11, color: "#c0acd4", marginTop: 4 }}>{t.last7}</div>
            </div>
          </div>
        </div>

        <div style={{ ...CARD, marginTop: 16, display: "flex", gap: 6 }}>
          {TABS.map((tab) => (
            <button key={tab} onClick={() => setActiveTab(tab)} style={{
              flex: 1, padding: "10px 4px", borderRadius: 12, border: "none",
              background: activeTab === tab ? "#7a5fa0" : "rgba(255,255,255,0.6)",
              color: activeTab === tab ? "#fff" : "#9b85b0",
              fontSize: 13, fontFamily: "inherit", cursor: "pointer",
              fontWeight: activeTab === tab ? 600 : 400, transition: "all 0.2s",
            }}>
              {tab === "write" ? t.writeTab : tab === "history" ? t.historyTab : t.reflectTab}
            </button>
          ))}
        </div>

        {error && (
          <div style={{ ...CARD, marginTop: 12, fontSize: 13, color: "#b04040" }}>{error}</div>
        )}

        {activeTab === "write" && (
          <div style={{ ...CARD, marginTop: 12 }}>
            <div style={{
              background: "rgba(255,255,255,0.75)", borderRadius: 20,
              border: "1px solid rgba(255,255,255,0.9)", boxShadow: "0 2px 16px rgba(90,62,107,0.06)", padding: "20px",
            }}>
              <div style={{ fontSize: 13, color: "#9b85b0", marginBottom: 10 }}>
                {t.formatDate(new Date())} · {t.todayPrompt}
              </div>
              <textarea value={newText}
                onChange={(e) => setNewText(e.target.value)}
                placeholder={t.placeholder}
                style={{
                  width: "100%", minHeight: 160, border: "none", outline: "none",
                  background: "transparent", resize: "none", fontSize: 16,
                  color: "#3d2b52", lineHeight: 1.8, fontFamily: "inherit", boxSizing: "border-box",
                }} />
              <button onClick={handleCreate} disabled={!newText.trim()} style={{
                width: "100%", marginTop: 12, padding: "13px", borderRadius: 12, border: "none",
                background: justSaved ? "linear-gradient(135deg, #7bc47b, #5aad5a)"
                  : newText.trim() ? "linear-gradient(135deg, #a07ac4, #7a5fa0)" : "rgba(180,160,200,0.3)",
                color: justSaved || newText.trim() ? "#fff" : "#c0acd4",
                fontSize: 15, fontWeight: 600,
                cursor: !newText.trim() ? "default" : "pointer",
                fontFamily: "inherit", transition: "all 0.2s", letterSpacing: "0.05em",
              }}>{justSaved ? t.saved : t.save}</button>
            </div>
          </div>
        )}

        {activeTab === "history" && (
          <div style={{ ...CARD, marginTop: 12 }}>
            {loading && (
              <div style={{ textAlign: "center", color: "#c0acd4", padding: "40px 0", fontSize: 15 }}>
                {t.loading}
              </div>
            )}
            {!loading && gratitudeEntries.length === 0 && (
              <div style={{ textAlign: "center", color: "#c0acd4", padding: "40px 0", fontSize: 15 }}>
                {t.noEntries}
              </div>
            )}
            {gratitudeEntries.map((entry) => (
              <div key={entry.entryId} style={{
                background: "rgba(255,255,255,0.6)", borderRadius: 16,
                border: "1px solid rgba(255,255,255,0.9)", padding: "14px 18px", marginBottom: 10,
              }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 6 }}>
                  <span style={{ fontSize: 12, color: "#b0a0c8" }}>{t.formatDate(new Date(entry.createdAt))}</span>
                  <div style={{ display: "flex", gap: 8 }}>
                    <button onClick={() => { setEditingId(entry.entryId); setEditText(entry.content); }} style={{
                      background: "none", border: "none", cursor: "pointer", fontSize: 13, color: "#b0a0c8", padding: 0,
                    }}>{t.edit}</button>
                    <button onClick={() => handleDelete(entry.entryId)} style={{
                      background: "none", border: "none", cursor: "pointer", fontSize: 13, color: "#d4a0a0", padding: 0,
                    }}>{t.delete}</button>
                  </div>
                </div>
                {editingId === entry.entryId ? (
                  <div>
                    <textarea value={editText} onChange={(e) => setEditText(e.target.value)} style={{
                      width: "100%", minHeight: 80, border: "1px solid #d4c5e6", borderRadius: 8,
                      padding: "8px", fontSize: 14, color: "#3d2b52", lineHeight: 1.7,
                      fontFamily: "inherit", resize: "none", boxSizing: "border-box", outline: "none",
                    }} />
                    <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
                      <button onClick={() => handleUpdate(entry.entryId)} style={{
                        flex: 1, padding: "8px", borderRadius: 8, border: "none",
                        background: "#7a5fa0", color: "#fff", fontSize: 13,
                        fontFamily: "inherit", cursor: "pointer",
                      }}>✓</button>
                      <button onClick={() => setEditingId(null)} style={{
                        flex: 1, padding: "8px", borderRadius: 8, border: "1px solid #d4c5e6",
                        background: "transparent", color: "#9b85b0", fontSize: 13,
                        fontFamily: "inherit", cursor: "pointer",
                      }}>{t.cancel}</button>
                    </div>
                  </div>
                ) : (
                  <div style={{ fontSize: 14, color: "#3d2b52", lineHeight: 1.7, whiteSpace: "pre-wrap" }}>
                    {entry.content}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        {activeTab === "reflect" && (
          <div style={{ ...CARD, marginTop: 12 }}>
            <div style={{ marginBottom: 14, paddingLeft: 4 }}>
              <div style={{ fontSize: 16, fontWeight: 700, color: "#5a3e6b" }}>{t.reflectTitle}</div>
              <div style={{ fontSize: 12, color: "#b0a0c8", marginTop: 3 }}>{t.reflectSubtitle}</div>
            </div>
            <div style={{
              background: "rgba(255,255,255,0.75)", borderRadius: 20,
              border: "1px solid rgba(255,255,255,0.9)", boxShadow: "0 2px 16px rgba(90,62,107,0.06)",
              padding: "16px 20px", marginBottom: 16,
            }}>
              {firstDate && (
                <div style={{
                  display: "inline-block", fontSize: 11, color: "#a07ac4",
                  background: "rgba(160,122,196,0.12)", borderRadius: 10,
                  padding: "2px 10px", marginBottom: 10,
                }}>
                  {t.dayLabel(dayNumber(new Date().toISOString(), firstDate))}
                </div>
              )}
              <textarea
                value={reflectText}
                onChange={(e) => setReflectText(e.target.value)}
                placeholder={t.reflectPlaceholder}
                style={{
                  width: "100%", minHeight: 120, border: "none", outline: "none",
                  background: "transparent", resize: "none", fontSize: 15,
                  color: "#3d2b52", lineHeight: 1.8, fontFamily: "inherit", boxSizing: "border-box",
                }} />
              <button onClick={handleSaveReflection} disabled={!reflectText.trim()} style={{
                width: "100%", marginTop: 10, padding: "12px", borderRadius: 12, border: "none",
                background: reflectSaved ? "linear-gradient(135deg, #7bc47b, #5aad5a)"
                  : reflectText.trim() ? "linear-gradient(135deg, #a07ac4, #7a5fa0)" : "rgba(180,160,200,0.3)",
                color: reflectText.trim() ? "#fff" : "#c0acd4",
                fontSize: 14, fontWeight: 600,
                cursor: !reflectText.trim() ? "default" : "pointer",
                fontFamily: "inherit", transition: "all 0.2s",
              }}>{reflectSaved ? t.reflectSaved : t.reflectSave}</button>
            </div>
            {reflectionEntries.length === 0 && (
              <div style={{ textAlign: "center", color: "#c0acd4", padding: "30px 0", fontSize: 14 }}>
                {t.reflectEmpty}
              </div>
            )}
            {reflectionEntries.map((entry, idx) => (
              <div key={entry.entryId} style={{ display: "flex", gap: 12, marginBottom: 16 }}>
                <div style={{ display: "flex", flexDirection: "column", alignItems: "center", flexShrink: 0 }}>
                  <div style={{
                    width: 12, height: 12, borderRadius: "50%", marginTop: 4,
                    background: idx === 0 ? "#7a5fa0" : "#c8b8e0",
                    boxShadow: idx === 0 ? "0 0 0 3px rgba(122,95,160,0.2)" : "none",
                  }} />
                  {idx < reflectionEntries.length - 1 && (
                    <div style={{ width: 2, flex: 1, background: "rgba(180,160,200,0.25)", marginTop: 4 }} />
                  )}
                </div>
                <div style={{
                  flex: 1, background: "rgba(255,255,255,0.65)", borderRadius: 16,
                  border: "1px solid rgba(255,255,255,0.9)", padding: "12px 16px",
                }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 8 }}>
                    <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
                      <span style={{
                        fontSize: 11, color: "#a07ac4",
                        background: "rgba(160,122,196,0.12)", borderRadius: 10, padding: "2px 10px",
                      }}>{t.dayLabel(dayNumber(entry.createdAt, firstDate))}</span>
                      <span style={{ fontSize: 11, color: "#c0acd4" }}>
                        {t.formatDate(new Date(entry.createdAt))}
                      </span>
                    </div>
                    <div style={{ display: "flex", gap: 8 }}>
                      <button onClick={() => { setEditingId(entry.entryId); setEditText(entry.content); }} style={{
                        background: "none", border: "none", cursor: "pointer", fontSize: 13, color: "#b0a0c8", padding: 0,
                      }}>✏️</button>
                      <button onClick={() => handleDelete(entry.entryId)} style={{
                        background: "none", border: "none", cursor: "pointer", fontSize: 13, color: "#d4a0a0", padding: 0,
                      }}>🗑️</button>
                    </div>
                  </div>
                  {editingId === entry.entryId ? (
                    <div>
                      <textarea value={editText} onChange={(e) => setEditText(e.target.value)} style={{
                        width: "100%", minHeight: 80, border: "1px solid #d4c5e6", borderRadius: 8,
                        padding: "8px", fontSize: 14, color: "#3d2b52", lineHeight: 1.7,
                        fontFamily: "inherit", resize: "none", boxSizing: "border-box", outline: "none",
                      }} />
                      <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
                        <button onClick={() => handleUpdate(entry.entryId)} style={{
                          flex: 1, padding: "8px", borderRadius: 8, border: "none",
                          background: "#7a5fa0", color: "#fff", fontSize: 13,
                          fontFamily: "inherit", cursor: "pointer",
                        }}>✓</button>
                        <button onClick={() => setEditingId(null)} style={{
                          flex: 1, padding: "8px", borderRadius: 8, border: "1px solid #d4c5e6",
                          background: "transparent", color: "#9b85b0", fontSize: 13,
                          fontFamily: "inherit", cursor: "pointer",
                        }}>{t.cancel}</button>
                      </div>
                    </div>
                  ) : (
                    <div style={{ fontSize: 14, color: "#3d2b52", lineHeight: 1.7, whiteSpace: "pre-wrap" }}>
                      {entry.content}
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
```

### 4-7. src/App.js

```jsx
import { useState } from 'react';
import { getCurrentUser } from './auth/cognito';
import AuthScreen from './components/AuthScreen';
import JournalScreen from './components/JournalScreen';

export default function App() {
  const [authed, setAuthed] = useState(!!getCurrentUser());

  if (!authed) {
    return <AuthScreen onAuthSuccess={() => setAuthed(true)} />;
  }

  return <JournalScreen onSignOut={() => setAuthed(false)} />;
}
```

### 4-8. .env.example（テンプレート）

```bash
REACT_APP_AWS_REGION=ap-northeast-1
REACT_APP_COGNITO_USER_POOL_ID=
REACT_APP_COGNITO_CLIENT_ID=
REACT_APP_API_ENDPOINT=
```

### 4-9. 実際に動かす

```bash
npm install

cp .env.example .env.local
# .env.local を開いて、Part 2またはPart 3で得た値を埋める:
#   REACT_APP_COGNITO_USER_POOL_ID=（terraform output cognito_user_pool_id）
#   REACT_APP_COGNITO_CLIENT_ID=（terraform output cognito_user_pool_client_id）
#   REACT_APP_API_ENDPOINT=（terraform output api_endpoint、末尾のスラッシュは除く）

npm start
```

ブラウザで http://localhost:3000 が開き、ログイン画面が表示されれば成功。
「アカウントを作成する」→ メール・パスワードを入力 →
メールに届く確認コードを入力 → ログイン → 日記を書いて保存できることを確認する。

問題なく動いたら、本番用にビルドしてデプロイする:
```bash
npm run build
aws s3 sync build/ s3://<frontend_bucket_name> --delete
aws cloudfront create-invalidation --distribution-id <cloudfront_distribution_id> --paths "/*"
```

これでPhase 3は完成。Part 6（CI/CD自動化）・Part 7（確認チェックリスト）に
進んでもよいし、「なぜこの順番でコードを書いたか」が気になる場合はPart 5へ。

---

[目次](./README.md) | 前へ: [Part 2 — Terraform](./02-terraform.md) / [Part 3 — CloudFormation](./03-cloudformation.md) | 次へ: [Part 5 — フロントエンド(段階的に理解)](./05-frontend-deep-dive.md) / [Part 6 — CI/CD](./06-cicd.md)
