import { getDemoRole } from './demo-role';

export type ApiError = { code: string; message: string; details?: unknown };

const apiOrigin = process.env.NEXT_PUBLIC_API_ORIGIN ?? '';
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? '';
let accessToken: string | null = null;

export function setAccessToken(token: string) {
  accessToken = token;
}

export function clearAccessToken() {
  accessToken = null;
}

function demoRole() {
  return getDemoRole();
}

function urlFor(path: string) {
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  return `${apiOrigin}${basePath}${normalizedPath}`;
}

async function refreshAccessToken(): Promise<string | null> {
  const response = await fetch(urlFor('/api/v1/auth/refresh'), {
    method: 'POST',
    headers: { Accept: 'application/json' },
    credentials: 'include',
  });
  if (!response.ok) {
    clearAccessToken();
    return null;
  }
  const payload = (await response.json()) as { data?: { access_token?: string } };
  const token = payload.data?.access_token;
  if (!token) {
    clearAccessToken();
    return null;
  }
  setAccessToken(token);
  return token;
}

export async function apiFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  headers.set('Accept', 'application/json');
  if (process.env.NEXT_PUBLIC_APP_ENV === 'demo') headers.set('X-Demo-Role', demoRole());
  if (accessToken && !headers.has('Authorization')) headers.set('Authorization', `Bearer ${accessToken}`);
  let response = await fetch(urlFor(path), { ...init, headers, credentials: 'include' });
  if (response.status === 401 && !path.includes('/auth/')) {
    const token = await refreshAccessToken();
    if (token) {
      headers.set('Authorization', `Bearer ${token}`);
      response = await fetch(urlFor(path), { ...init, headers, credentials: 'include' });
    }
  }
  if (!response.ok) {
    const payload = (await response.json().catch(() => null)) as { error?: ApiError } | null;
    throw new Error(payload?.error?.message ?? `API request failed (${response.status})`);
  }
  return response.json() as Promise<T>;
}
