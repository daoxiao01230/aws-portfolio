import { useState, useEffect } from 'react';
import { listEntries, createEntry, updateEntry, deleteEntry } from '../api/entries';
import { signOut } from '../auth/cognito';
import GratitudeTree from './GratitudeTree';

// Phase 1 (aws-portfolio-01-static-site/react/src/App.js) と同じ辞書構造・キー名
const translations = {
  ja: {
    appName: "感謝日記", subtitle: "毎日の感謝を記録して、幸せを積み重ねよう",
    todayPrompt: "今日、何に感謝しますか？", placeholder: "感謝していること1つを書いてみよう...",
    save: "保存する", saved: "保存しました ✓", streak: "連続日数",
    noEntries: "まだ記録がありません。今日から始めましょう！", today: "今日",
    langNext: "EN", formatDate: (d) => `${d.getMonth() + 1}月${d.getDate()}日`,
    last7: "直近7日間", writeTab: "✍️ 今日", historyTab: "📖 履歴",
    signOut: "ログアウト", edit: "編集", delete: "削除", cancel: "キャンセル",
    loading: "読み込み中…",
  },
  en: {
    appName: "Gratitude Journal", subtitle: "Notice the good, grow your joy",
    todayPrompt: "What are you grateful for today?", placeholder: "Write one thing you're grateful for...",
    save: "Save", saved: "Saved ✓", streak: "Day Streak",
    noEntries: "No entries yet — start today!", today: "Today",
    langNext: "中文", formatDate: (d) => d.toLocaleDateString("en-US", { month: "short", day: "numeric" }),
    last7: "Last 7 days", writeTab: "✍️ Today", historyTab: "📖 History",
    signOut: "Sign Out", edit: "Edit", delete: "Delete", cancel: "Cancel",
    loading: "Loading…",
  },
  zh: {
    appName: "感恩日记", subtitle: "每天记录美好，积累幸福",
    todayPrompt: "今天你感恩什么？", placeholder: "写下一件让你感恩的事...",
    save: "保存", saved: "已保存 ✓", streak: "连续天数",
    noEntries: "还没有记录，今天开始吧！", today: "今天",
    langNext: "日本語", formatDate: (d) => `${d.getMonth() + 1}月${d.getDate()}日`,
    last7: "近7天", writeTab: "✍️ 今日", historyTab: "📖 历史",
    signOut: "退出登录", edit: "编辑", delete: "删除", cancel: "取消",
    loading: "加载中…",
  },
};

const LANG_CYCLE = ["ja", "en", "zh"];

const CARD = { width: "100%", boxSizing: "border-box", padding: "0 16px" };

function getDateKey(iso) {
  return new Date(iso).toISOString().split("T")[0];
}

// Phase 1は「日付キー→1エントリ」だったが、Phase 3は1日に複数エントリを許す設計。
// streakは「その日に1件以上のエントリがあるか」で判定し、考え方をPhase 1に揃える
function calculateStreak(entries) {
  const daysWithEntry = new Set(entries.map((e) => getDateKey(e.createdAt)));
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

export default function JournalScreen({ onSignOut }) {
  const [langIdx, setLangIdx] = useState(0);
  const [entries, setEntries] = useState([]);
  const [activeTab, setActiveTab] = useState("write");
  const [newText, setNewText] = useState("");
  const [justSaved, setJustSaved] = useState(false);
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

  // eslint-disable-next-line react-hooks/exhaustive-deps -- 初回マウント時のみ実行したい
  useEffect(() => { load(); }, []);

  const streak = calculateStreak(entries);

  const handleCreate = async () => {
    if (!newText.trim()) return;
    try {
      const entry = await createEntry(newText.trim());
      setEntries([entry, ...entries]);
      setNewText("");
      setJustSaved(true);
      setTimeout(() => setJustSaved(false), 1500);
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

  const TABS = ["write", "history"];

  return (
    <div style={{
      minHeight: "100vh",
      background: "linear-gradient(160deg, #fdf4ee 0%, #f0eaf8 50%, #eaf2f8 100%)",
      fontFamily: "'Georgia', 'Noto Serif SC', 'Noto Serif JP', serif",
      display: "flex", flexDirection: "column", alignItems: "center",
      padding: "0 0 40px",
    }}>
      <div style={{ width: "100%", maxWidth: 430, display: "flex", flexDirection: "column" }}>

        {/* Header */}
        <div style={{ ...CARD, padding: "28px 16px 0", display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
          <div>
            <h1 style={{ margin: 0, fontSize: 24, fontWeight: 700, color: "#5a3e6b", letterSpacing: "0.06em", lineHeight: 1.2 }}>
              {t.appName}
            </h1>
            <p style={{ margin: "4px 0 0", fontSize: 13, color: "#9b85b0", fontStyle: "italic" }}>{t.subtitle}</p>
          </div>
          <div style={{ display: "flex", gap: 8, flexShrink: 0, marginLeft: 12 }}>
            <button onClick={cycleLang} style={{
              background: "rgba(255,255,255,0.7)", border: "1.5px solid #d4c5e6",
              borderRadius: 20, padding: "5px 14px", fontSize: 13, color: "#7a5fa0",
              cursor: "pointer", fontFamily: "inherit", whiteSpace: "nowrap",
            }}>{t.langNext}</button>
            <button onClick={handleSignOut} style={{
              background: "rgba(255,255,255,0.7)", border: "1.5px solid #d4c5e6",
              borderRadius: 20, padding: "5px 14px", fontSize: 13, color: "#7a5fa0",
              cursor: "pointer", fontFamily: "inherit", whiteSpace: "nowrap",
            }}>{t.signOut}</button>
          </div>
        </div>

        {/* Streak Card */}
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
                  const has = entries.some((e) => getDateKey(e.createdAt) === key);
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

        {/* Tabs */}
        <div style={{ ...CARD, marginTop: 16, display: "flex", gap: 6 }}>
          {TABS.map((tab) => (
            <button key={tab} onClick={() => setActiveTab(tab)} style={{
              flex: 1, padding: "10px 4px", borderRadius: 12, border: "none",
              background: activeTab === tab ? "#7a5fa0" : "rgba(255,255,255,0.6)",
              color: activeTab === tab ? "#fff" : "#9b85b0",
              fontSize: 13, fontFamily: "inherit", cursor: "pointer",
              fontWeight: activeTab === tab ? 600 : 400, transition: "all 0.2s",
            }}>
              {tab === "write" ? t.writeTab : t.historyTab}
            </button>
          ))}
        </div>

        {error && (
          <div style={{ ...CARD, marginTop: 12, fontSize: 13, color: "#b04040" }}>{error}</div>
        )}

        {/* Write Tab */}
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

        {/* History Tab */}
        {activeTab === "history" && (
          <div style={{ ...CARD, marginTop: 12 }}>
            {loading && (
              <div style={{ textAlign: "center", color: "#c0acd4", padding: "40px 0", fontSize: 15 }}>
                {t.loading}
              </div>
            )}
            {!loading && entries.length === 0 && (
              <div style={{ textAlign: "center", color: "#c0acd4", padding: "40px 0", fontSize: 15 }}>
                {t.noEntries}
              </div>
            )}
            {entries.map((entry) => (
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
      </div>
    </div>
  );
}
