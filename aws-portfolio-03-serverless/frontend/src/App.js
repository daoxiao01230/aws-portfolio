import { useState } from 'react';
import { getCurrentUser } from './auth/cognito';
import AuthScreen from './components/AuthScreen';
import JournalScreen from './components/JournalScreen';

export default function App() {
  // getCurrentUser はローカルストレージにキャッシュされたセッションを見るだけで、
  // トークンの有効性検証はしない。無効な場合はJournalScreen初回ロード時の
  // API呼び出しが401で失敗し、そこでログイン画面に戻す形でよい
  const [authed, setAuthed] = useState(!!getCurrentUser());

  if (!authed) {
    return <AuthScreen onAuthSuccess={() => setAuthed(true)} />;
  }

  return <JournalScreen onSignOut={() => setAuthed(false)} />;
}
