import { useState, useEffect } from "react";

const STORAGE_KEY = "gratitude_entries";
const REFLECTIONS_KEY = "gratitude_reflections";

const translations = {
  zh: {
    appName: "感恩日记",
    subtitle: "每天记录美好，积累幸福",
    todayPrompt: "今天你感恩什么？",
    placeholder: "写下三件让你感恩的事...",
    save: "保存今天的感恩",
    saved: "已保存 ✓",
    streak: "连续天数",
    noEntries: "还没有记录，今天开始吧！",
    today: "今天",
    langNext: "日本語",
    formatDate: (d) => `${d.getMonth() + 1}月${d.getDate()}日`,
    last7: "近7天",
    writeTab: "✍️ 今日",
    historyTab: "📖 历史",
    reflectTab: "🌿 感悟",
    reflectTitle: "我的成长感悟",
    reflectSubtitle: "记录写日记后内心的变化",
    reflectPlaceholder: "此刻有什么感悟？写下你注意到的变化...",
    reflectSave: "保存感悟",
    reflectSaved: "已保存 ✓",
    reflectEmpty: "还没有感悟，随时记录你的变化吧",
    dayLabel: (n) => `第 ${n} 天`,
  },
  ja: {
    appName: "感謝日記",
    subtitle: "毎日の感謝を記録して、幸せを積み重ねよう",
    todayPrompt: "今日、何に感謝しますか？",
    placeholder: "感謝していること3つを書いてみよう...",
    save: "今日の感謝を保存する",
    saved: "保存しました ✓",
    streak: "連続日数",
    noEntries: "まだ記録がありません。今日から始めましょう！",
    today: "今日",
    langNext: "EN",
    formatDate: (d) => `${d.getMonth() + 1}月${d.getDate()}日`,
    last7: "直近7日間",
    writeTab: "✍️ 今日",
    historyTab: "📖 履歴",
    reflectTab: "🌿 気づき",
    reflectTitle: "私の成長の気づき",
    reflectSubtitle: "日記を書いて気づいた心の変化を記録",
    reflectPlaceholder: "今、どんな気づきがありますか？変化を書いてみましょう...",
    reflectSave: "気づきを保存",
    reflectSaved: "保存しました ✓",
    reflectEmpty: "まだ気づきがありません。いつでも記録できます",
    dayLabel: (n) => `${n}日目`,
  },
  en: {
    appName: "Gratitude Journal",
    subtitle: "Notice the good, grow your joy",
    todayPrompt: "What are you grateful for today?",
    placeholder: "Write three things you're grateful for...",
    save: "Save Today's Gratitude",
    saved: "Saved ✓",
    streak: "Day Streak",
    noEntries: "No entries yet — start today!",
    today: "Today",
    langNext: "中文",
    formatDate: (d) => d.toLocaleDateString("en-US", { month: "short", day: "numeric" }),
    last7: "Last 7 days",
    writeTab: "✍️ Today",
    historyTab: "📖 History",
    reflectTab: "🌿 Growth",
    reflectTitle: "My Growth Journal",
    reflectSubtitle: "Record how journaling is changing you",
    reflectPlaceholder: "What shift have you noticed? Write your reflection...",
    reflectSave: "Save Reflection",
    reflectSaved: "Saved ✓",
    reflectEmpty: "No reflections yet — write one whenever you feel a change",
    dayLabel: (n) => `Day ${n}`,
  },
};

const LANG_CYCLE = ["zh", "ja", "en"];

function GratitudeTree({ streak }) {
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

function getTodayStr() {
  return new Date().toISOString().split("T")[0];
}

function getFirstEntryDate(entries) {
  const keys = Object.keys(entries).sort();
  return keys.length > 0 ? keys[0] : null;
}

function daysSince(dateStr) {
  if (!dateStr) return 0;
  const start = new Date(dateStr + "T00:00:00");
  const now = new Date();
  return Math.floor((now - start) / (1000 * 60 * 60 * 24)) + 1;
}

const CARD = { width: "100%", boxSizing: "border-box", padding: "0 16px" };

export default function App() {
  const [langIdx, setLangIdx] = useState(0);
  const [entries, setEntries] = useState({});
  const [todayText, setTodayText] = useState("");
  const [savedToday, setSavedToday] = useState(false);
  const [activeTab, setActiveTab] = useState("write");
  const [reflections, setReflections] = useState([]);
  const [reflectText, setReflectText] = useState("");
  const [reflectSaved, setReflectSaved] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [editText, setEditText] = useState("");

  const lang = LANG_CYCLE[langIdx];
  const t = translations[lang];
  const today = getTodayStr();

  useEffect(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        setEntries(parsed);
        if (parsed[today]) { setTodayText(parsed[today]); setSavedToday(true); }
      }
      const storedR = localStorage.getItem(REFLECTIONS_KEY);
      if (storedR) setReflections(JSON.parse(storedR));
    } catch {}
  }, [today]);

  const calculateStreak = () => {
    let streak = 0;
    let d = new Date();
    while (true) {
      const key = d.toISOString().split("T")[0];
      if (entries[key]) { streak++; d.setDate(d.getDate() - 1); } else break;
    }
    return streak;
  };
  const streak = calculateStreak();
  const firstDate = getFirstEntryDate(entries);

  const handleSave = () => {
    if (!todayText.trim()) return;
    const updated = { ...entries, [today]: todayText };
    setEntries(updated);
    setSavedToday(true);
    try { localStorage.setItem(STORAGE_KEY, JSON.stringify(updated)); } catch {}
  };

  const handleSaveReflection = () => {
    if (!reflectText.trim()) return;
    const newItem = {
      id: Date.now().toString(),
      date: today,
      text: reflectText.trim(),
      dayNum: daysSince(firstDate),
    };
    const updated = [newItem, ...reflections];
    setReflections(updated);
    setReflectText("");
    setReflectSaved(true);
    setTimeout(() => setReflectSaved(false), 2000);
    try { localStorage.setItem(REFLECTIONS_KEY, JSON.stringify(updated)); } catch {}
  };

  const handleDeleteReflection = (id) => {
    const updated = reflections.filter(r => r.id !== id);
    setReflections(updated);
    try { localStorage.setItem(REFLECTIONS_KEY, JSON.stringify(updated)); } catch {}
  };

  const handleEditSave = (id) => {
    const updated = reflections.map(r => r.id === id ? { ...r, text: editText } : r);
    setReflections(updated);
    setEditingId(null);
    try { localStorage.setItem(REFLECTIONS_KEY, JSON.stringify(updated)); } catch {}
  };

  const pastEntries = Object.entries(entries)
    .filter(([k]) => k !== today)
    .sort(([a], [b]) => b.localeCompare(a))
    .slice(0, 20);

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
      <div style={{
        width: "100%",
        maxWidth: 430,
        display: "flex", flexDirection: "column",
      }}>

      {/* Header */}
      <div style={{ ...CARD, padding: "28px 16px 0", display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <div>
          <h1 style={{ margin: 0, fontSize: 24, fontWeight: 700, color: "#5a3e6b", letterSpacing: "0.06em", lineHeight: 1.2 }}>
            {t.appName}
          </h1>
          <p style={{ margin: "4px 0 0", fontSize: 13, color: "#9b85b0", fontStyle: "italic" }}>{t.subtitle}</p>
        </div>
        <button onClick={cycleLang} style={{
          background: "rgba(255,255,255,0.7)", border: "1.5px solid #d4c5e6",
          borderRadius: 20, padding: "5px 14px", fontSize: 13, color: "#7a5fa0",
          cursor: "pointer", fontFamily: "inherit", whiteSpace: "nowrap", flexShrink: 0, marginLeft: 12,
        }}>{t.langNext}</button>
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
                const k = d.toISOString().split("T")[0];
                const has = !!entries[k];
                return (
                  <div key={i} style={{
                    width: 24, height: 24, borderRadius: 6, flexShrink: 0,
                    background: has ? "#7bc47b" : "rgba(180,160,200,0.2)",
                    border: k === today ? "2px solid #7a5fa0" : "none",
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
        {TABS.map(tab => (
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
            <textarea value={todayText}
              onChange={e => { setTodayText(e.target.value); setSavedToday(false); }}
              placeholder={t.placeholder}
              style={{
                width: "100%", minHeight: 160, border: "none", outline: "none",
                background: "transparent", resize: "none", fontSize: 16,
                color: "#3d2b52", lineHeight: 1.8, fontFamily: "inherit", boxSizing: "border-box",
              }} />
            <button onClick={handleSave} disabled={savedToday || !todayText.trim()} style={{
              width: "100%", marginTop: 12, padding: "13px", borderRadius: 12, border: "none",
              background: savedToday ? "linear-gradient(135deg, #7bc47b, #5aad5a)"
                : todayText.trim() ? "linear-gradient(135deg, #a07ac4, #7a5fa0)" : "rgba(180,160,200,0.3)",
              color: savedToday || todayText.trim() ? "#fff" : "#c0acd4",
              fontSize: 15, fontWeight: 600,
              cursor: savedToday || !todayText.trim() ? "default" : "pointer",
              fontFamily: "inherit", transition: "all 0.2s", letterSpacing: "0.05em",
            }}>{savedToday ? t.saved : t.save}</button>
          </div>
        </div>
      )}

      {/* History Tab */}
      {activeTab === "history" && (
        <div style={{ ...CARD, marginTop: 12 }}>
          {entries[today] && (
            <div style={{
              background: "rgba(255,255,255,0.75)", borderRadius: 20,
              border: "1.5px solid #d4c5e6", padding: "16px 20px", marginBottom: 12,
            }}>
              <div style={{ fontSize: 12, color: "#a07ac4", marginBottom: 6, fontWeight: 600 }}>
                📌 {t.today} · {t.formatDate(new Date())}
              </div>
              <div style={{ fontSize: 15, color: "#3d2b52", lineHeight: 1.7, whiteSpace: "pre-wrap" }}>
                {entries[today]}
              </div>
            </div>
          )}
          {pastEntries.length === 0 && !entries[today] && (
            <div style={{ textAlign: "center", color: "#c0acd4", padding: "40px 0", fontSize: 15 }}>
              {t.noEntries}
            </div>
          )}
          {pastEntries.map(([date, text]) => (
            <div key={date} style={{
              background: "rgba(255,255,255,0.6)", borderRadius: 16,
              border: "1px solid rgba(255,255,255,0.9)", padding: "14px 18px", marginBottom: 10,
            }}>
              <div style={{ fontSize: 12, color: "#b0a0c8", marginBottom: 5 }}>
                {t.formatDate(new Date(date + "T00:00:00"))}
              </div>
              <div style={{ fontSize: 14, color: "#5a3e6b", lineHeight: 1.7, whiteSpace: "pre-wrap" }}>
                {text.length > 120 ? text.slice(0, 120) + "…" : text}
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Reflect Tab */}
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
                {t.dayLabel(daysSince(firstDate))}
              </div>
            )}
            <textarea
              value={reflectText}
              onChange={e => { setReflectText(e.target.value); setReflectSaved(false); }}
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
          {reflections.length === 0 && (
            <div style={{ textAlign: "center", color: "#c0acd4", padding: "30px 0", fontSize: 14 }}>
              {t.reflectEmpty}
            </div>
          )}
          {reflections.map((r, idx) => (
            <div key={r.id} style={{ display: "flex", gap: 12, marginBottom: 16 }}>
              <div style={{ display: "flex", flexDirection: "column", alignItems: "center", flexShrink: 0 }}>
                <div style={{
                  width: 12, height: 12, borderRadius: "50%", marginTop: 4,
                  background: idx === 0 ? "#7a5fa0" : "#c8b8e0",
                  boxShadow: idx === 0 ? "0 0 0 3px rgba(122,95,160,0.2)" : "none",
                }} />
                {idx < reflections.length - 1 && (
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
                    }}>{t.dayLabel(r.dayNum)}</span>
                    <span style={{ fontSize: 11, color: "#c0acd4" }}>
                      {t.formatDate(new Date(r.date + "T00:00:00"))}
                    </span>
                  </div>
                  <div style={{ display: "flex", gap: 8 }}>
                    <button onClick={() => { setEditingId(r.id); setEditText(r.text); }} style={{
                      background: "none", border: "none", cursor: "pointer", fontSize: 13, color: "#b0a0c8", padding: 0,
                    }}>✏️</button>
                    <button onClick={() => handleDeleteReflection(r.id)} style={{
                      background: "none", border: "none", cursor: "pointer", fontSize: 13, color: "#d4a0a0", padding: 0,
                    }}>🗑️</button>
                  </div>
                </div>
                {editingId === r.id ? (
                  <div>
                    <textarea value={editText} onChange={e => setEditText(e.target.value)} style={{
                      width: "100%", minHeight: 80, border: "1px solid #d4c5e6", borderRadius: 8,
                      padding: "8px", fontSize: 14, color: "#3d2b52", lineHeight: 1.7,
                      fontFamily: "inherit", resize: "none", boxSizing: "border-box", outline: "none",
                    }} />
                    <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
                      <button onClick={() => handleEditSave(r.id)} style={{
                        flex: 1, padding: "8px", borderRadius: 8, border: "none",
                        background: "#7a5fa0", color: "#fff", fontSize: 13,
                        fontFamily: "inherit", cursor: "pointer",
                      }}>✓</button>
                      <button onClick={() => setEditingId(null)} style={{
                        flex: 1, padding: "8px", borderRadius: 8, border: "1px solid #d4c5e6",
                        background: "transparent", color: "#9b85b0", fontSize: 13,
                        fontFamily: "inherit", cursor: "pointer",
                      }}>✕</button>
                    </div>
                  </div>
                ) : (
                  <div style={{ fontSize: 14, color: "#3d2b52", lineHeight: 1.7, whiteSpace: "pre-wrap" }}>
                    {r.text}
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
