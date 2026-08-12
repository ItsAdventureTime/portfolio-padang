export type ApiError = { code: string; message: string; details?: unknown };

const apiOrigin = process.env.NEXT_PUBLIC_API_ORIGIN ?? '';
const basePath = process.env.NEXT_PUBLIC_BASE_PATH ?? '';

export async function apiFetch<T>(path: string, init: RequestInit = {}): Promise<T> {
  const normalizedPath = path.startsWith('/') ? path : `/${path}`;
  const response = await fetch(`${apiOrigin}${basePath}${normalizedPath}`, {
    ...init,
    headers: {
      Accept: 'application/json',
      ...(process.env.NEXT_PUBLIC_APP_ENV === 'demo' ? { 'X-Demo-Role': 'general_manager' } : {}),
      ...init.headers,
    },
    credentials: 'include',
  });
  if (!response.ok) {
    const payload = (await response.json().catch(() => null)) as { error?: ApiError } | null;
    throw new Error(payload?.error?.message ?? `API request failed (${response.status})`);
  }
  return response.json() as Promise<T>;
}
