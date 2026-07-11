// Phase 1 (aws-portfolio-01-static-site/react/src/App.js) と同じビジュアル。
// streakに応じて葉の本数と幹の高さが伸びる、見た目だけの装飾コンポーネント
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
