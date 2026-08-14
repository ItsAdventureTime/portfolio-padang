'use client';

import { FormEvent, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { ApiRequestError, apiFetch, setAccessToken } from '@/lib/api-client';
import { PadangLogo } from '@/components/brand/padang-brand';

export default function LoginPage() {
  const isDemo = process.env.NEXT_PUBLIC_APP_ENV === 'demo';
  const router = useRouter();
  const emailRef = useRef<HTMLInputElement>(null);
  const codeRef = useRef<HTMLInputElement>(null);
  const [email, setEmail] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [challengeId, setChallengeId] = useState('');
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [nextPath] = useState(() => {
    if (typeof window === 'undefined') return '/';
    const next = new URLSearchParams(window.location.search).get('next');
    return next && next.startsWith('/') && !next.startsWith('//') ? next : '/';
  });
  const [cooldownUntil, setCooldownUntil] = useState<number | null>(null);
  const [expiresAt, setExpiresAt] = useState<number | null>(null);
  const [now, setNow] = useState(() => Date.now());

  useEffect(() => {
    emailRef.current?.focus();
  }, []);

  useEffect(() => {
    if (!submitted && !cooldownUntil) return;
    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [cooldownUntil, submitted]);

  useEffect(() => {
    if (submitted) codeRef.current?.focus();
  }, [submitted]);

  const cooldownSeconds = cooldownUntil ? Math.max(0, Math.ceil((cooldownUntil - now) / 1000)) : 0;
  const expired = Boolean(submitted && expiresAt && now >= expiresAt);
  const expiryMinutes = expiresAt ? Math.max(0, Math.ceil((expiresAt - now) / 60000)) : 0;

  async function submitRequest() {
    setBusy(true);
    setError('');
    setStatus('Requesting a one-time code…');
    try {
      const payload = await apiFetch<{ data: { challenge_id: string } }>('/api/v1/auth/request-otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });
      setChallengeId(payload.data.challenge_id);
      setSubmitted(true);
      setCode('');
      setExpiresAt(Date.now() + 10 * 60 * 1000);
      setCooldownUntil(Date.now() + 30 * 1000);
      setStatus('If the account is approved, a code is on its way.');
    } catch (requestError) {
      const retryAfter = requestError instanceof ApiRequestError ? requestError.retryAfter : undefined;
      if (retryAfter) setCooldownUntil(Date.now() + retryAfter * 1000);
      setStatus('');
      setError(requestError instanceof Error ? requestError.message : 'Unable to request a sign-in code.');
    } finally {
      setBusy(false);
    }
  }

  async function requestCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (cooldownSeconds > 0) return;
    await submitRequest();
  }

  async function verifyCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (expired) return;
    setBusy(true);
    setError('');
    setStatus('Verifying the one-time code…');
    try {
      const payload = await apiFetch<{ data: { access_token: string } }>('/api/v1/auth/verify-otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ challenge_id: challengeId, code }),
      });
      setAccessToken(payload.data.access_token);
      router.replace(nextPath);
    } catch (verifyError) {
      setStatus('');
      setError(verifyError instanceof Error ? verifyError.message : 'Unable to verify the sign-in code.');
    } finally {
      setBusy(false);
    }
  }

  function restart() {
    setSubmitted(false);
    setChallengeId('');
    setCode('');
    setError('');
    setStatus('');
    setCooldownUntil(null);
    setExpiresAt(null);
    window.setTimeout(() => emailRef.current?.focus(), 0);
  }

  if (isDemo) {
    return <main className="session-gate"><section className="panel session-gate-panel"><div className="session-brand"><PadangLogo alt="Padang Construction and Supplies Corporation logo" priority /></div><div className="eyebrow">Demo mode</div><h1 className="page-title">No login required</h1><p className="page-copy">The demonstration environment uses synthetic data and a guarded role selector. Production authentication is intentionally not part of this build.</p><Link className="primary-button session-gate-primary" href="/">Open demo dashboard</Link></section></main>;
  }

  return <main className="session-gate"><section className="panel session-gate-panel" aria-labelledby="login-title"><div className="session-brand"><PadangLogo alt="Padang Construction and Supplies Corporation logo" priority /></div><div className="eyebrow">Padang ERP Lite</div><h1 id="login-title" className="page-title">Sign in securely.</h1><p className="page-copy">Enter your approved work email. We&apos;ll send a one-time code; no password is stored.</p>{error && <div className="login-error" role="alert">{error}</div>}<div className="sr-only" role="status" aria-live="polite">{status}</div>{submitted ? <form className="login-form" onSubmit={verifyCode} aria-describedby="code-help"><div className="status-pill status-green">If the account is approved, a code is on its way.</div><p id="code-help" className="login-help">{expired ? 'This code has expired. Request a new code to continue.' : `The code expires in about ${expiryMinutes} minute${expiryMinutes === 1 ? '' : 's'}.`}</p><label className="form-label" htmlFor="code">One-time code</label><input className="form-input login-code-input" ref={codeRef} id="code" name="code" required inputMode="numeric" pattern="[0-9]{6}" maxLength={6} autoComplete="one-time-code" value={code} onChange={(event) => setCode(event.target.value.replace(/\D/g, '').slice(0, 6))} placeholder="000000" aria-invalid={Boolean(error)} /><button className="primary-button" type="submit" disabled={busy || expired}>{busy ? 'Verifying…' : expired ? 'Code expired' : 'Verify and sign in'}</button><button className="secondary-button" type="button" onClick={() => void submitRequest()} disabled={busy || cooldownSeconds > 0}>{cooldownSeconds > 0 ? `Resend code in ${cooldownSeconds}s` : 'Resend code'}</button><button type="button" onClick={restart} className="text-button text-button-muted">Use a different email</button></form> : <form className="login-form" onSubmit={requestCode}><label className="form-label" htmlFor="email">Work email</label><input className="form-input" ref={emailRef} id="email" name="email" required type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="name@company.com" aria-invalid={Boolean(error)} /><button className="primary-button" type="submit" disabled={busy || cooldownSeconds > 0}>{busy ? 'Sending…' : cooldownSeconds > 0 ? `Try again in ${cooldownSeconds}s` : 'Send one-time code'}</button></form>}</section></main>;
}
