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
