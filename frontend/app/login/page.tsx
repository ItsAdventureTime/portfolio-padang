'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { apiFetch, setAccessToken } from '@/lib/api-client';

export default function LoginPage() {
  const isDemo = process.env.NEXT_PUBLIC_APP_ENV === 'demo';
  const router = useRouter();
  const [email, setEmail] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [challengeId, setChallengeId] = useState('');
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  async function requestCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      const payload = await apiFetch<{ data: { challenge_id: string } }>('/api/v1/auth/request-otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email }),
      });
      setChallengeId(payload.data.challenge_id);
      setSubmitted(true);
    } catch (requestError) {
      setError(requestError instanceof Error ? requestError.message : 'Unable to request a sign-in code.');
    } finally {
      setBusy(false);
    }
  }

  async function verifyCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError('');
    try {
      const payload = await apiFetch<{ data: { access_token: string } }>('/api/v1/auth/verify-otp', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ challenge_id: challengeId, code }),
      });
      setAccessToken(payload.data.access_token);
      router.push('/');
    } catch (verifyError) {
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
  }

  if (isDemo) {
    return <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', padding: 24 }}><section className="panel" style={{ maxWidth: 460, padding: 28, textAlign: 'center' }}><div className="eyebrow">Demo mode</div><h1 className="page-title" style={{ marginTop: 10 }}>No login required</h1><p className="page-copy" style={{ marginInline: 'auto' }}>The demonstration environment uses synthetic data and a guarded role selector. Production authentication is intentionally not part of this build.</p><Link className="primary-button" href="/" style={{ marginTop: 22 }}>Open demo dashboard</Link></section></main>;
  }

  return <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', padding: 24 }}><section className="panel" style={{ width: 'min(100%, 430px)', padding: 30 }}><div className="eyebrow">Padang ERP Lite</div><h1 className="page-title" style={{ marginTop: 10 }}>Sign in securely.</h1><p className="page-copy">Enter your approved work email. We&apos;ll send a one-time code; no password is stored.</p>{error && <div role="alert" style={{ color: 'var(--danger)', marginTop: 16 }}>{error}</div>}{submitted ? <form onSubmit={verifyCode} style={{ marginTop: 22, display: 'grid', gap: 12 }}><div className="status-pill status-green">If the account is approved, a code is on its way.</div><label htmlFor="code" style={{ fontSize: 12, fontWeight: 700 }}>One-time code</label><input id="code" name="code" required inputMode="numeric" pattern="[0-9]{6}" maxLength={6} autoComplete="one-time-code" value={code} onChange={(event) => setCode(event.target.value.replace(/\D/g, '').slice(0, 6))} placeholder="000000" style={{ border: '1px solid var(--line)', borderRadius: 8, padding: '11px 12px', letterSpacing: '0.25em' }} /><button className="primary-button" type="submit" disabled={busy}>{busy ? 'Verifying…' : 'Verify and sign in'}</button><button type="button" onClick={restart} style={{ border: 0, background: 'transparent', color: 'var(--muted)', cursor: 'pointer' }}>Use a different email</button></form> : <form onSubmit={requestCode} style={{ marginTop: 22, display: 'grid', gap: 12 }}><label htmlFor="email" style={{ fontSize: 12, fontWeight: 700 }}>Work email</label><input id="email" name="email" required type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="name@company.com" style={{ border: '1px solid var(--line)', borderRadius: 8, padding: '11px 12px' }} /><button className="primary-button" type="submit" disabled={busy}>{busy ? 'Sending…' : 'Send one-time code'}</button></form>}</section></main>;
}
