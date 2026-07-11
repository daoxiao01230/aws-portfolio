import config from '../config';
import { getIdToken } from '../auth/cognito';

async function authHeaders() {
  // ログイン中でない場合 getIdToken() は null を返す（例外は投げない）。
  // その場合でもリクエスト自体は送信し、API Gateway側の401で弾かせる。
  // ここで事前にチェックして早期returnしない理由: 401ハンドリングを
  // 呼び出し元(JournalScreen)の1箇所に集約するため
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
    // エラーメッセージの先頭にHTTPステータスを埋め込む。
    // 呼び出し側は `err.message.startsWith('401')` でセッション切れを判定する
    throw new Error(`${res.status} ${body}`);
  }
  // 204 No Content (delete) にはbodyがない
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
  // entryId は "2026-07-11T00:00:00+00:00#uuid" のように ":" "#" を含むため、
  // パスセグメントとして送る前にエンコードが必須
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
