'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';

export default function LoginPage() {
  const isDemo = process.env.NEXT_PUBLIC_APP_ENV === 'demo';
  const [email, setEmail] = useState('');
  const [submitted, setSubmitted] = useState(false);

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitted(true);
  }

  if (isDemo) {
    return <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', padding: 24 }}><section className="panel" style={{ maxWidth: 460, padding: 28, textAlign: 'center' }}><div className="eyebrow">Demo mode</div><h1 className="page-title" style={{ marginTop: 10 }}>No login required</h1><p className="page-copy" style={{ marginInline: 'auto' }}>The demonstration environment uses synthetic data and a guarded role selector. Production authentication is intentionally not part of this build.</p><Link className="primary-button" href="/" style={{ marginTop: 22 }}>Open demo dashboard</Link></section></main>;
  }

  return <main style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', padding: 24 }}><section className="panel" style={{ width: 'min(100%, 430px)', padding: 30 }}><div className="eyebrow">Padang ERP Lite</div><h1 className="page-title" style={{ marginTop: 10 }}>Sign in securely.</h1><p className="page-copy">Enter your approved work email. We&apos;ll send a one-time code; no password is stored.</p>{submitted ? <div className="status-pill status-green" style={{ marginTop: 20 }}>If the account is approved, a code is on its way.</div> : <form onSubmit={submit} style={{ marginTop: 22, display: 'grid', gap: 12 }}><label htmlFor="email" style={{ fontSize: 12, fontWeight: 700 }}>Work email</label><input id="email" name="email" required type="email" autoComplete="email" value={email} onChange={(event) => setEmail(event.target.value)} placeholder="name@company.com" style={{ border: '1px solid var(--line)', borderRadius: 8, padding: '11px 12px' }} /><button className="primary-button" type="submit">Send one-time code</button></form>}</section></main>;
}
