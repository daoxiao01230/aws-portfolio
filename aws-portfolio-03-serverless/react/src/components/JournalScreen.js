import { useState, useEffect } from 'react';
import { listEntries, createEntry, updateEntry, deleteEntry } from '../api/entries';
import { signOut } from '../auth/cognito';

const CARD_STYLE = {
  background: 'rgba(255,255,255,0.75)', borderRadius: 16,
  border: '1px solid rgba(255,255,255,0.9)', padding: '14px 18px', marginBottom: 10,
};

function formatDate(iso) {
  return new Date(iso).toLocaleString('ja-JP', {
    month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit',
  });
}

export default function JournalScreen({ onSignOut }) {
  const [entries, setEntries] = useState([]);
  const [newText, setNewText] = useState('');
  const [editingId, setEditingId] = useState(null);
  const [editText, setEditText] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const items = await listEntries();
      setEntries(items);
    } catch (err) {
      // セッション切れ(401)はエラー表示ではなく、ログイン画面へ戻す
      if (String(err.message).startsWith('401')) {
        signOut();
        onSignOut();
        return;
      }
      setError(err.message || String(err));
    } finally {
      setLoading(false);
    }
  };

  // eslint-disable-next-line react-hooks/exhaustive-deps -- 初回マウント時のみ実行したい
  useEffect(() => { load(); }, []);

  const handleCreate = async () => {
    if (!newText.trim()) return;
    try {
      const entry = await createEntry(newText.trim());
      setEntries([entry, ...entries]);
      setNewText('');
    } catch (err) {
      setError(err.message || String(err));
    }
  };

  const handleUpdate = async (entryId) => {
    try {
      await updateEntry(entryId, editText.trim());
      setEntries(entries.map(e => e.entryId === entryId ? { ...e, content: editText.trim() } : e));
      setEditingId(null);
    } catch (err) {
      setError(err.message || String(err));
    }
  };

  const handleDelete = async (entryId) => {
    try {
      await deleteEntry(entryId);
      setEntries(entries.filter(e => e.entryId !== entryId));
    } catch (err) {
      setError(err.message || String(err));
    }
  };

  const handleSignOut = () => {
    signOut();
    onSignOut();
  };

  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(160deg, #fdf4ee 0%, #f0eaf8 50%, #eaf2f8 100%)',
      fontFamily: "'Georgia', 'Noto Serif SC', 'Noto Serif JP', serif",
      display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '0 0 40px',
    }}>
      <div style={{ width: '100%', maxWidth: 430 }}>

        <div style={{ padding: '28px 16px 0', display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
          <h1 style={{ margin: 0, fontSize: 24, fontWeight: 700, color: '#5a3e6b' }}>感謝日記</h1>
          <button onClick={handleSignOut} style={{
            background: 'rgba(255,255,255,0.7)', border: '1.5px solid #d4c5e6',
            borderRadius: 20, padding: '5px 14px', fontSize: 13, color: '#7a5fa0',
            cursor: 'pointer', fontFamily: 'inherit',
          }}>ログアウト</button>
        </div>

        <div style={{ padding: '16px' }}>
          <div style={{
            background: 'rgba(255,255,255,0.75)', borderRadius: 20,
            border: '1px solid rgba(255,255,255,0.9)', boxShadow: '0 2px 16px rgba(90,62,107,0.06)', padding: 20,
          }}>
            <textarea value={newText} onChange={e => setNewText(e.target.value)}
              placeholder="今日、何に感謝しますか？"
              style={{
                width: '100%', minHeight: 100, border: 'none', outline: 'none',
                background: 'transparent', resize: 'none', fontSize: 16,
                color: '#3d2b52', lineHeight: 1.8, fontFamily: 'inherit', boxSizing: 'border-box',
              }} />
            <button onClick={handleCreate} disabled={!newText.trim()} style={{
              width: '100%', marginTop: 12, padding: '13px', borderRadius: 12, border: 'none',
              background: newText.trim() ? 'linear-gradient(135deg, #a07ac4, #7a5fa0)' : 'rgba(180,160,200,0.3)',
              color: newText.trim() ? '#fff' : '#c0acd4', fontSize: 15, fontWeight: 600,
              cursor: newText.trim() ? 'pointer' : 'default', fontFamily: 'inherit',
            }}>保存する</button>
          </div>
        </div>

        {error && (
          <div style={{ margin: '0 16px 12px', fontSize: 13, color: '#b04040' }}>{error}</div>
        )}

        <div style={{ padding: '0 16px' }}>
          {loading && (
            <div style={{ textAlign: 'center', color: '#c0acd4', padding: '30px 0' }}>読み込み中…</div>
          )}
          {!loading && entries.length === 0 && (
            <div style={{ textAlign: 'center', color: '#c0acd4', padding: '30px 0', fontSize: 15 }}>
              まだ記録がありません。今日から始めましょう！
            </div>
          )}
          {entries.map((entry) => (
            <div key={entry.entryId} style={CARD_STYLE}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 6 }}>
                <span style={{ fontSize: 12, color: '#b0a0c8' }}>{formatDate(entry.createdAt)}</span>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button onClick={() => { setEditingId(entry.entryId); setEditText(entry.content); }} style={{
                    background: 'none', border: 'none', cursor: 'pointer', fontSize: 13, color: '#b0a0c8', padding: 0,
                  }}>編集</button>
                  <button onClick={() => handleDelete(entry.entryId)} style={{
                    background: 'none', border: 'none', cursor: 'pointer', fontSize: 13, color: '#d4a0a0', padding: 0,
                  }}>削除</button>
                </div>
              </div>
              {editingId === entry.entryId ? (
                <div>
                  <textarea value={editText} onChange={e => setEditText(e.target.value)} style={{
                    width: '100%', minHeight: 80, border: '1px solid #d4c5e6', borderRadius: 8,
                    padding: 8, fontSize: 14, color: '#3d2b52', lineHeight: 1.7,
                    fontFamily: 'inherit', resize: 'none', boxSizing: 'border-box', outline: 'none',
                  }} />
                  <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
                    <button onClick={() => handleUpdate(entry.entryId)} style={{
                      flex: 1, padding: 8, borderRadius: 8, border: 'none',
                      background: '#7a5fa0', color: '#fff', fontSize: 13, fontFamily: 'inherit', cursor: 'pointer',
                    }}>保存</button>
                    <button onClick={() => setEditingId(null)} style={{
                      flex: 1, padding: 8, borderRadius: 8, border: '1px solid #d4c5e6',
                      background: 'transparent', color: '#9b85b0', fontSize: 13, fontFamily: 'inherit', cursor: 'pointer',
                    }}>キャンセル</button>
                  </div>
                </div>
              ) : (
                <div style={{ fontSize: 14, color: '#3d2b52', lineHeight: 1.7, whiteSpace: 'pre-wrap' }}>
                  {entry.content}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
