import { getDemoRole } from './demo-role';

export type ApiError = { code: string; message: string; details?: unknown };

export class ApiRequestError extends Error {
  readonly status: number;
  readonly code?: string;
  readonly retryAfter?: number;

  constructor(message: string, status: number, code?: string, retryAfter?: number) {
    super(message);
    this.name = 'ApiRequestError';
    this.status = status;
    this.code = code;
    this.retryAfter = retryAfter;
  }
}

const apiOrigin = (process.env.NEXT_PUBLIC_API_ORIGIN ?? '').replace(/\/+$/, '');
const basePath = (process.env.NEXT_PUBLIC_BASE_PATH ?? '').replace(/\/+$/, '');
let accessToken: string | null = null;

export function setAccessToken(token: string) {
  accessToken = token;
}

export function clearAccessToken() {
  accessToken = null;
}

export async function logout() {
  try {
    await apiFetch('/api/v1/auth/logout', { method: 'POST' });
  } finally {
    clearAccessToken();
  }
}

function demoRole() {
  return getDemoRole();
}

function urlFor(path: string) {
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  // A direct API origin already points at the API root. The compiled basePath
  // is only part of the URL when the API is routed through the web origin.
  const routePrefix = apiOrigin ? '' : basePath;
  return `${apiOrigin}${routePrefix}${normalizedPath}`;
}

async function refreshAccessToken(signal?: AbortSignal): Promise<string | null> {
  const response = await fetch(urlFor('/api/v1/auth/refresh'), {
    method: 'POST',
    headers: { Accept: 'application/json' },
    credentials: 'include',
    signal,
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
    const token = await refreshAccessToken(init.signal ?? undefined);
    if (token) {
      headers.set('Authorization', `Bearer ${token}`);
      response = await fetch(urlFor(path), { ...init, headers, credentials: 'include', signal: init.signal });
    }
  }
  if (!response.ok) {
    const payload = (await response.json().catch(() => null)) as { error?: ApiError } | null;
    const retryAfterHeader = response.headers.get('Retry-After');
    const retryAfter = retryAfterHeader ? Number.parseInt(retryAfterHeader, 10) : undefined;
    throw new ApiRequestError(
      payload?.error?.message ?? `API request failed (${response.status})`,
      response.status,
      payload?.error?.code,
      Number.isFinite(retryAfter) ? retryAfter : undefined,
    );
  }
  return response.json() as Promise<T>;
}
