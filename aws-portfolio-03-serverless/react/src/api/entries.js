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
  // 204 No Content (delete) にはbodyがない
  return res.status === 204 ? null : res.json();
}

export function listEntries() {
  return request('/entries');
}

export function createEntry(content) {
  return request('/entries', {
    method: 'POST',
    body: JSON.stringify({ content }),
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
