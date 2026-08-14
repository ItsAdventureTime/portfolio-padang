'use client';

import { useEffect, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { ApiRequestError, apiFetch, clearAccessToken } from '@/lib/api-client';
import { PadangLogo } from '@/components/brand/padang-brand';

type SessionState = 'checking' | 'authenticated' | 'error';

function routeWithoutBasePath(pathname: string) {
  const basePath = (process.env.NEXT_PUBLIC_BASE_PATH ?? '').replace(/\/+$/, '');
  if (basePath && (pathname === basePath || pathname.startsWith(`${basePath}/`))) {
    return pathname.slice(basePath.length) || '/';
  }
  return pathname || '/';
}

export function ProductionSessionGuard({ children }: { children: React.ReactNode }) {
  const isDemo = process.env.NEXT_PUBLIC_APP_ENV === 'demo';
  const pathname = usePathname();
  const router = useRouter();
  const [attempt, setAttempt] = useState(0);
  const [state, setState] = useState<SessionState>(isDemo ? 'authenticated' : 'checking');
  const [message, setMessage] = useState('');

  useEffect(() => {
    if (isDemo) return;
    let active = true;

    const checkStateTimer = window.setTimeout(() => {
      if (active) {
        setState('checking');
        setMessage('');
      }
    }, 0);
    apiFetch('/api/v1/auth/me').then(() => {
      if (active) setState('authenticated');
    }).catch((error: unknown) => {
      if (!active) return;
      if (error instanceof ApiRequestError && error.status === 401) {
        clearAccessToken();
        const next = routeWithoutBasePath(`${window.location.pathname}${window.location.search}`);
        router.replace(`/login?next=${encodeURIComponent(next)}`);
        return;
      }
      setState('error');
      setMessage(error instanceof Error ? error.message : 'The production session could not be verified.');
    });

    return () => {
      active = false;
      window.clearTimeout(checkStateTimer);
    };
  }, [attempt, isDemo, pathname, router]);

  if (isDemo || state === 'authenticated') return <>{children}</>;

  return <main className="session-gate" aria-live="polite" aria-busy={state === 'checking'}>
    <section className="panel session-gate-panel">
      <div className="session-brand"><PadangLogo alt="Padang Construction and Supplies Corporation logo" priority /></div>
      {state === 'checking' ? <>
        <div className="eyebrow">Production session</div>
        <h1 className="page-title">Checking your session…</h1>
        <p className="page-copy">The workspace will open only after the API confirms your signed-in account.</p>
      </> : <>
        <div className="eyebrow">Production unavailable</div>
        <h1 className="page-title">We couldn&apos;t verify your session.</h1>
        <p className="page-copy">No operational records were loaded. Check the API connection and try again, or return to sign in.</p>
        {message && <p className="session-gate-error" role="alert">{message}</p>}
        <div className="session-gate-actions">
          <button className="primary-button" type="button" onClick={() => setAttempt((value) => value + 1)}>Retry verification</button>
          <button className="secondary-button" type="button" onClick={() => router.replace('/login')}>Return to sign in</button>
        </div>
      </>}
    </section>
  </main>;
}
