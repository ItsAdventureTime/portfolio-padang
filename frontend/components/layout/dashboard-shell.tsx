'use client';

import Link from 'next/link';
import { type ReactNode, useCallback, useEffect, useRef, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { Bell, Boxes, BriefcaseBusiness, CheckCircle2, ChevronRight, ClipboardList, CreditCard, FileBarChart, Hammer, LayoutDashboard, LogOut, Menu, PackageCheck, Settings, X } from 'lucide-react';
import { ProductionSessionGuard } from '@/components/auth/session-guard';
import { PadangLogo } from '@/components/brand/padang-brand';
import { StatusBadge } from '@/components/ui/status-badge';
import { apiFetch, logout } from '@/lib/api-client';
import { demoCanAccess, demoPermissions, demoRoleLabel, demoRoles } from '@/lib/demo-role';
import { DemoRoleProvider, useDemoRole } from '@/lib/demo-role-context';
import { formatDate, formatPHP } from '@/lib/formatters';

const navigation = [
  { label: 'Dashboard', href: '/', Icon: LayoutDashboard, module: 'dashboard' as const },
  { label: 'Projects', href: '/projects', Icon: BriefcaseBusiness, module: 'projects' as const },
  { label: 'Fabrication', href: '/fabrication', Icon: Hammer, module: 'fabrication' as const },
  { label: 'Procurement', href: '/procurement', Icon: ClipboardList, module: 'procurement' as const },
  { label: 'Inventory', href: '/inventory', Icon: Boxes, module: 'inventory' as const },
  { label: 'Billing & Collections', href: '/billing', Icon: CreditCard, module: 'billing' as const },
  { label: 'Finance Operations', href: '/finance', Icon: PackageCheck, module: 'finance' as const },
  { label: 'Reports', href: '/reports', Icon: FileBarChart, module: 'reports' as const },
  { label: 'Settings', href: '/settings', Icon: Settings, module: 'settings' as const },
];

function routeWithoutBasePath(pathname: string, basePath: string) {
  const normalizedBasePath = basePath.replace(/\/+$/, '');
  const hasBasePath = normalizedBasePath && (pathname === normalizedBasePath || pathname.startsWith(`${normalizedBasePath}/`));
  const route = hasBasePath ? pathname.slice(normalizedBasePath.length) : pathname;
  return route || '/';
}

function Navigation({ role, isDemo, onNavigate }: { role: ReturnType<typeof useDemoRole>['role']; isDemo: boolean; onNavigate?: () => void }) {
  const pathname = usePathname();
  const route = routeWithoutBasePath(pathname, process.env.NEXT_PUBLIC_BASE_PATH ?? '');
  const visibleNavigation = isDemo ? navigation.filter((item) => demoCanAccess(role, item.module)) : navigation;

  return <nav className="nav-list" aria-label="Primary navigation">{visibleNavigation.map(({ label, href, Icon }) => {
    const active = href === '/' ? route === '/' : route === href || route.startsWith(`${href}/`);
    return <Link aria-current={active ? 'page' : undefined} className={`nav-link ${active ? 'nav-link-active' : ''}`} href={href} key={label} onClick={onNavigate}><Icon aria-hidden="true" size={17} strokeWidth={1.8} /><span>{label}</span></Link>;
  })}</nav>;
}

function Brand({ onClick }: { onClick?: () => void }) {
  return <Link className="brand" href="/" aria-label="Padang ERP dashboard" onClick={onClick}><PadangLogo alt="" priority={!onClick} /><span className="sr-only">Padang ERP</span></Link>;
}

function MobileBrand() {
  return <Link className="mobile-brand" href="/" aria-label="Padang ERP dashboard"><PadangLogo alt="" className="mobile-brand-logo" priority /><span className="sr-only">Padang ERP</span></Link>;
}

function MobileDrawer({ open, onClose, role, isDemo, triggerRef }: { open: boolean; onClose: () => void; role: ReturnType<typeof useDemoRole>['role']; isDemo: boolean; triggerRef: React.RefObject<HTMLButtonElement | null> }) {
  const panelRef = useRef<HTMLDivElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const previousFocusRef = useRef<HTMLElement | null>(null);

  useEffect(() => {
    if (!open) return;
    previousFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : triggerRef.current;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    const focusTimer = window.setTimeout(() => closeButtonRef.current?.focus(), 0);
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onClose();
      if (event.key !== 'Tab' || !panelRef.current) return;
      const focusable = panelRef.current.querySelectorAll<HTMLElement>('a[href],button:not([disabled]),select,input,textarea,[tabindex]:not([tabindex="-1"])');
      if (!focusable.length) return;
      const first = focusable[0];
      const last = focusable[focusable.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };
    document.addEventListener('keydown', closeOnEscape);
    return () => {
      window.clearTimeout(focusTimer);
      document.body.style.overflow = previousOverflow;
      document.removeEventListener('keydown', closeOnEscape);
      if (previousFocusRef.current?.isConnected) previousFocusRef.current.focus();
      previousFocusRef.current = null;
    };
  }, [onClose, open, triggerRef]);

  return <div id="mobile-navigation" hidden={!open} className={`mobile-drawer ${open ? 'open' : ''}`} role="dialog" aria-modal="true" aria-hidden={!open} aria-labelledby="mobile-navigation-title" onClick={onClose}>
    <div className="mobile-drawer-panel" ref={panelRef} onClick={(event) => event.stopPropagation()}>
      <div className="mobile-drawer-header"><Brand onClick={onClose} /><button ref={closeButtonRef} className="mobile-menu" type="button" onClick={onClose} aria-label="Close navigation"><X aria-hidden="true" size={18} /></button></div>
      <h2 id="mobile-navigation-title" className="sr-only">Mobile navigation</h2>
      <Navigation role={role} isDemo={isDemo} onNavigate={onClose} />
    </div>
  </div>;
}

function SessionActions({ isDemo }: { isDemo: boolean }) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  if (isDemo) return null;

  async function signOut() {
    setBusy(true);
    setError('');
    try {
      await logout();
      router.replace('/login');
    } catch (logoutError) {
      setError(logoutError instanceof Error ? logoutError.message : 'Unable to sign out.');
    } finally {
      setBusy(false);
    }
  }

  return <div className="session-actions"><button className="text-button" type="button" onClick={signOut} disabled={busy}><LogOut size={13} aria-hidden="true" />{busy ? 'Signing out…' : 'Sign out'}</button>{error && <span className="session-error" role="alert">{error}</span>}</div>;
}

function ShellLayout({ children, sectionTitle }: { children: ReactNode; sectionTitle: string }) {
  const { role, setRole } = useDemoRole();
  const isDemo = process.env.NEXT_PUBLIC_APP_ENV === 'demo';
  const [drawerOpen, setDrawerOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const closeDrawer = useCallback(() => setDrawerOpen(false), []);
  const roleName = demoRoleLabel(role);

  return <div className="shell-grid"><a className="skip-link" href="#workspace-main">Skip to workspace content</a>
    <aside className="sidebar" aria-hidden={drawerOpen || undefined} inert={drawerOpen ? true : undefined}><div className="sidebar-inner"><Brand /><Navigation role={role} isDemo={isDemo} /><div className="sidebar-footer"><div className="user-row"><div className="avatar">{isDemo ? 'JD' : 'AU'}</div><div><div className="user-name">{isDemo ? 'John Dela Cruz' : 'Authenticated user'}</div><div className="user-role">{isDemo ? roleName : 'Production session'}</div></div></div><SessionActions isDemo={isDemo} /></div></div></aside>
    <div className="main" aria-hidden={drawerOpen || undefined} inert={drawerOpen ? true : undefined}>
      {isDemo && <div className="demo-banner">Demo mode · Synthetic preview data · No login required</div>}
      <header className="topbar"><div className="top-actions"><button ref={triggerRef} id="mobile-navigation-trigger" className="mobile-menu" type="button" onClick={() => setDrawerOpen(true)} aria-label="Open navigation" aria-expanded={drawerOpen} aria-controls="mobile-navigation"><Menu aria-hidden="true" size={18} /></button><MobileBrand /><div className="breadcrumb">Workspace <ChevronRight aria-hidden="true" size={13} style={{ display: 'inline', verticalAlign: 'middle' }} /> <strong>{sectionTitle}</strong></div></div><div className="top-actions"><span className="read-only-control" title="Notifications are not connected in this build"><Bell aria-hidden="true" size={16} /><span className="desktop-only">Notifications unavailable</span></span>{isDemo && <><label className="role-label" htmlFor={`${sectionTitle.toLowerCase().replaceAll(' ', '-')}-role`}>Demo role</label><select className="role-select" id={`${sectionTitle.toLowerCase().replaceAll(' ', '-')}-role`} value={role} onChange={(event) => setRole(event.target.value)}>{demoRoles.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></>}</div></header>
      {children}
    </div>
    <MobileDrawer open={drawerOpen} onClose={closeDrawer} role={role} isDemo={isDemo} triggerRef={triggerRef} />
  </div>;
}

type DashboardSummary = { active_projects?: number; fabrication_jobs?: number; pending_approvals?: number; accounts_receivable?: number | string };
const demoStats = [['Active Projects', '05', '+1 this month', 'positive'], ['Fabrication Jobs', '03', '2 in production', 'muted'], ['Pending Approvals', '07', 'Needs your review', 'positive'], ['Accounts Receivable', '₱1.24M', '₱380K due this week', 'muted']] as const;
const approvals = [['FR-2026-0042', 'Fund Request · Project materials', '₱185,400.00'], ['PB-ABC-2026-03', 'Progress Billing · ABC Building', '₱642,880.00'], ['PO-2026-0118', 'Purchase Order · Steel supply', '₱928,150.00'], ['FR-2026-0040', 'Fund Request · Site operations', '₱74,200.00']];
const projects = [['ABC Building Construction', 'ABC Holdings Inc.', '₱12,450,000', 'active', '68%'], ['San Fernando Warehouse', 'Padang Properties', '₱8,200,000', 'active', '41%'], ['Mexico Road Improvement', 'City Engineering Office', '₱5,780,000', 'planning', '12%']];

function DashboardContent() {
  const { role } = useDemoRole();
  const isDemo = process.env.NEXT_PUBLIC_APP_ENV === 'demo';
  const permissions = demoPermissions(role);
  const [dashboard, setDashboard] = useState<DashboardSummary | null>(null);
  const [state, setState] = useState<'preview' | 'loading' | 'live' | 'error'>(isDemo ? 'preview' : 'loading');
  const [errorMessage, setErrorMessage] = useState('');
  const [retryNonce, setRetryNonce] = useState(0);

  useEffect(() => {
    if (isDemo) return;
    const controller = new AbortController();
    const loadingStateTimer = window.setTimeout(() => {
      if (!controller.signal.aborted) {
        setState('loading');
        setErrorMessage('');
      }
    }, 0);
    apiFetch<{ data: DashboardSummary }>('/api/v1/dashboard/summary', { signal: controller.signal }).then((payload) => {
      if (controller.signal.aborted || !payload.data || typeof payload.data !== 'object') return;
      setDashboard(payload.data);
      setState('live');
    }).catch((error: unknown) => {
      if (controller.signal.aborted) return;
      setDashboard(null);
      setState('error');
      setErrorMessage(error instanceof Error ? error.message : 'The live dashboard could not be loaded.');
    });
    return () => {
      controller.abort();
      window.clearTimeout(loadingStateTimer);
    };
  }, [isDemo, retryNonce]);

  const liveStats = dashboard ? [
    ['Active Projects', String(dashboard.active_projects ?? 0), 'Live API summary', 'positive'],
    ['Fabrication Jobs', String(dashboard.fabrication_jobs ?? 0), 'Live API summary', 'muted'],
    ['Pending Approvals', String(dashboard.pending_approvals ?? 0), 'Live API summary', 'positive'],
    ['Accounts Receivable', formatPHP(dashboard.accounts_receivable), 'Live API summary', 'muted'],
  ] as const : [];

  return <main id="workspace-main" className="content"><section className="page-heading motion-enter"><div><div className="eyebrow">{formatDate('2026-08-12')}</div><h1 className="page-title">Good morning, {isDemo ? 'John' : 'there'}.</h1><p className="page-copy">A clear view of Padang&apos;s active work, cash position, and decisions waiting for action.</p></div><span className="read-only-action" title="Record creation is not connected in this build">Read-only preview</span></section>
    {isDemo && <div className="permission-summary motion-enter" role="status" aria-live="polite"><strong>{demoRoleLabel(role)}</strong><span>{permissions.summary}</span><span>{permissions.canApprove ? 'Approval views visible.' : 'Approval controls hidden.'} {permissions.canCreate ? 'Creation permission is illustrative only.' : 'No creation permission.'}</span></div>}
    <div className={`data-status motion-enter ${state === 'error' ? 'data-status-error' : ''}`} role={state === 'error' ? 'alert' : 'status'} aria-live="polite"><div><strong>{state === 'live' ? 'Live API summary' : state === 'loading' ? 'Loading dashboard' : state === 'error' ? 'Dashboard unavailable' : 'Demo preview'}</strong><span>{state === 'live' ? 'Only summary values confirmed by the API are shown.' : state === 'loading' ? 'Loading production summary; no sample metrics are substituted.' : state === 'error' ? 'No production dashboard rows are shown until the API responds.' : 'Dashboard widgets below are illustrative synthetic data.'}</span>{errorMessage && <span className="data-status-detail">{errorMessage}</span>}</div>{state === 'error' && <button className="secondary-button" type="button" onClick={() => setRetryNonce((value) => value + 1)}>Retry dashboard</button>}</div>
    {state === 'loading' && <section className="stats-grid motion-stagger" aria-label="Loading dashboard summary" aria-busy="true">{[1, 2, 3, 4].map((item) => <article className="stat-card motion-item" key={item}><span className="skeleton skeleton-heading" /><span className="skeleton skeleton-value" /><span className="skeleton skeleton-meta" /></article>)}</section>}
    {state === 'live' && <><section className="stats-grid motion-stagger" aria-label="Live key performance indicators">{liveStats.map(([label, value, meta, tone]) => <article className="stat-card motion-item" key={label}><div className="stat-label">{label}</div><div className="stat-value">{value}</div><div className={`stat-meta ${tone === 'muted' ? 'stat-meta-muted' : ''}`}>{tone === 'positive' && <CheckCircle2 size={13} />}{meta}</div></article>)}</section><section className="panel honest-limit panel-spaced motion-enter"><h2 className="panel-title">Detailed widgets are not connected</h2><p className="page-copy">Project portfolio, approval rows, and budget charts appear only in the clearly labeled demo preview. Production will not display synthetic records in their place.</p></section></>}
        {isDemo && <><section className="stats-grid motion-stagger" aria-label="Demo key performance indicators">{demoStats.map(([label, value, meta, tone]) => <article className="stat-card motion-item" key={label}><div className="stat-label">{label}</div><div className="stat-value">{value}</div><div className={`stat-meta ${tone === 'muted' ? 'stat-meta-muted' : ''}`}>{tone === 'positive' && <CheckCircle2 size={13} />}{meta}</div></article>)}</section><section className="dashboard-grid motion-enter"><article className="panel"><div className="panel-header"><h2 className="panel-title">Budget vs actual</h2><Link className="panel-link" href="/reports">View report</Link></div><div className="panel-body"><div className="bar-chart">{[['ABC Building', 76, '₱9.4M'], ['San Fernando Warehouse', 54, '₱4.4M'], ['Mexico Road Improvement', 19, '₱1.1M'], ['Office Renovation', 86, '₱2.2M']].map(([label, width, value]) => <div className="bar-row" key={label}><span className="bar-label">{label}</span><span className="bar-track"><span className="bar-fill" style={{ width: `${width}%` }} /></span><span className="bar-value">{value}</span></div>)}</div></div></article><article className="panel"><div className="panel-header"><h2 className="panel-title">Pending approvals</h2><span className="status-pill status-amber">7 waiting</span></div><div className="panel-body"><div className="approval-list">{approvals.map(([reference, description, amount]) => <div className="approval-row" key={reference}><div><div className="approval-ref">{reference}</div><div className="approval-type">{description}</div></div><div className="approval-amount">{amount}</div><span className="read-only-control approval-preview">Preview only</span></div>)}</div></div></article></section><section className="panel panel-spaced motion-enter"><div className="panel-header"><h2 className="panel-title">Active project portfolio</h2><Link className="panel-link" href="/projects">Open projects <ChevronRight aria-hidden="true" size={13} style={{ display: 'inline', verticalAlign: 'middle' }} /></Link></div><div className="table-wrap"><table className="data-table"><caption className="sr-only">Active project portfolio demo preview</caption><thead><tr><th scope="col">Project</th><th scope="col">Client</th><th scope="col">Contract value</th><th scope="col">Status</th><th scope="col">Completion</th></tr></thead><tbody>{projects.map(([name, client, amount, status, completion]) => <tr key={name}><td data-label="Project">{name}</td><td data-label="Client">{client}</td><td data-label="Contract value" className="font-mono">{amount}</td><td data-label="Status"><StatusBadge value={status} /></td><td data-label="Completion" className="font-mono">{completion}</td></tr>)}</tbody></table></div></section></>}
  </main>;
}

export function DashboardShell() {
  return <ProductionSessionGuard><DemoRoleProvider><ShellLayout sectionTitle="Dashboard"><DashboardContent /></ShellLayout></DemoRoleProvider></ProductionSessionGuard>;
}

export function WorkspaceFrame({ children, sectionTitle = 'Operations' }: { children: ReactNode; sectionTitle?: string }) {
  return <ProductionSessionGuard><DemoRoleProvider><ShellLayout sectionTitle={sectionTitle}>{children}</ShellLayout></DemoRoleProvider></ProductionSessionGuard>;
}
