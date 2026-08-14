'use client';

import { type ReactNode, useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Bell, Boxes, BriefcaseBusiness, CheckCircle2, ChevronRight, ClipboardList, CreditCard, FileBarChart, Hammer, LayoutDashboard, Menu, PackageCheck, Plus, Settings, X } from 'lucide-react';
import { demoRoleLabel, demoRoles } from '@/lib/demo-role';
import { DemoRoleProvider, useDemoRole } from '@/lib/demo-role-context';
const navigation = [
  ['Dashboard', '/', LayoutDashboard], ['Projects', '/projects', BriefcaseBusiness],
  ['Fabrication', '/fabrication', Hammer], ['Procurement', '/procurement', ClipboardList],
  ['Inventory', '/inventory', Boxes], ['Billing & Collections', '/billing', CreditCard],
  ['Finance Operations', '/finance', PackageCheck], ['Reports', '/reports', FileBarChart],
  ['Settings', '/settings', Settings],
] as const;

function routeWithoutBasePath(pathname: string, basePath: string) {
  const normalizedBasePath = basePath.replace(/\/+$/, '');
  const hasBasePath = normalizedBasePath &&
    (pathname === normalizedBasePath || pathname.startsWith(`${normalizedBasePath}/`));
  const route = hasBasePath ? pathname.slice(normalizedBasePath.length) : pathname;
  return route || '/';
}

function Navigation({ onNavigate }: { onNavigate?: () => void }) {
  const pathname = usePathname();
  const route = routeWithoutBasePath(pathname, process.env.NEXT_PUBLIC_BASE_PATH ?? '');
  return <nav className="nav-list" aria-label="Primary navigation">{navigation.map(([label, href, Icon]) => {
    const active = href === '/' ? route === '/' : route === href || route.startsWith(`${href}/`);
    return <Link aria-current={active ? 'page' : undefined} className={`nav-link ${active ? 'nav-link-active' : ''}`} href={href} key={label} onClick={onNavigate}><Icon aria-hidden="true" size={17} strokeWidth={1.8} /><span>{label}</span></Link>;
  })}</nav>;
}
function Brand() { return <div className="brand"><div className="brand-mark" aria-hidden="true">P</div><div><div className="brand-name">PADANG ERP</div><div className="brand-caption">Operations lite</div></div></div>; }

const stats = [['Active Projects', '05', '+1 this month', 'positive'], ['Fabrication Jobs', '03', '2 in production', 'muted'], ['Pending Approvals', '07', 'Needs your review', 'positive'], ['Accounts Receivable', '₱1.24M', '₱380K due this week', 'muted']] as const;
const approvals = [['FR-2026-0042', 'Fund Request · Project materials', '₱185,400.00'], ['PB-ABC-2026-03', 'Progress Billing · ABC Building', '₱642,880.00'], ['PO-2026-0118', 'Purchase Order · Steel supply', '₱928,150.00'], ['FR-2026-0040', 'Fund Request · Site operations', '₱74,200.00']];
const projects = [['ABC Building Construction', 'ABC Holdings Inc.', '₱12,450,000', 'Active', '68%'], ['San Fernando Warehouse', 'Padang Properties', '₱8,200,000', 'Active', '41%'], ['Mexico Road Improvement', 'City Engineering Office', '₱5,780,000', 'Planning', '12%']];

export function DashboardShell() {
  return <DemoRoleProvider><DashboardShellContent /></DemoRoleProvider>;
}

function DashboardShellContent() {
  const { role, setRole } = useDemoRole();
  const isDemo = process.env.NEXT_PUBLIC_APP_ENV === 'demo';
  const [drawerOpen, setDrawerOpen] = useState(false);
  const roleName = demoRoleLabel(role);
  useEffect(() => {
    if (!drawerOpen) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setDrawerOpen(false);
    };
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    document.addEventListener('keydown', closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener('keydown', closeOnEscape);
    };
  }, [drawerOpen]);
  return <div className="shell-grid">
    <aside className="sidebar"><div className="sidebar-inner"><Brand /><Navigation /><div className="sidebar-footer"><div className="user-row"><div className="avatar">JD</div><div><div className="user-name">John Dela Cruz</div><div className="user-role">{roleName}</div></div></div></div></div></aside>
    <div className="main">
      {isDemo && <div className="demo-banner">Demo mode · Synthetic data resets every 30 minutes · No login required</div>}
      <header className="topbar"><div className="top-actions"><button className="mobile-menu" type="button" onClick={() => setDrawerOpen(true)} aria-label="Open navigation"><Menu size={18} /></button><div className="breadcrumb">Workspace <ChevronRight size={13} style={{ display: 'inline', verticalAlign: 'middle' }} /> <strong>Dashboard</strong></div></div><div className="top-actions"><button className="icon-button" type="button" disabled aria-label="Notifications (coming soon)" title="Notifications are not available in this preview"><Bell aria-hidden="true" size={17} /></button>{isDemo && <><label className="role-label" htmlFor="role">Demo role</label><select className="role-select" id="role" value={role} onChange={(event) => setRole(event.target.value)}>{demoRoles.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></>}</div></header>
      <main className="content"><section className="page-heading"><div><div className="eyebrow">Tuesday, 12 August 2026</div><h1 className="page-title">Good morning, John.</h1><p className="page-copy">A clear view of Padang&apos;s active work, cash position, and decisions waiting for action.</p></div><button className="primary-button" type="button" disabled title="Record creation is not available in this foundation preview"><Plus size={15} /> New record <span className="sr-only">(coming soon)</span></button></section>
        <div className="data-status" role="status"><strong>Foundation preview</strong><span>Dashboard metrics and approval rows are sample data; live workflow actions are not enabled.</span></div>
        <section className="stats-grid" aria-label="Key performance indicators">{stats.map(([label, value, meta, tone]) => <article className="stat-card" key={label}><div className="stat-label">{label}</div><div className="stat-value">{value}</div><div className={`stat-meta ${tone === 'muted' ? 'stat-meta-muted' : ''}`}>{tone === 'positive' && <CheckCircle2 size={13} />}{meta}</div></article>)}</section>
        <section className="dashboard-grid"><article className="panel"><div className="panel-header"><h2 className="panel-title">Budget vs actual</h2><Link className="panel-link" href="/reports">View report</Link></div><div className="panel-body"><div className="bar-chart">{[['ABC Building', 76, '₱9.4M'], ['San Fernando Warehouse', 54, '₱4.4M'], ['Mexico Road Improvement', 19, '₱1.1M'], ['Office Renovation', 86, '₱2.2M']].map(([label, width, value]) => <div className="bar-row" key={label}><span className="bar-label">{label}</span><span className="bar-track"><span className="bar-fill" style={{ width: `${width}%` }} /></span><span className="bar-value">{value}</span></div>)}</div></div></article><article className="panel"><div className="panel-header"><h2 className="panel-title">Pending approvals</h2><span className="status-pill status-amber">7 waiting</span></div><div className="panel-body"><div className="approval-list">{approvals.map(([reference, description, amount]) => <div className="approval-row" key={reference}><div><div className="approval-ref">{reference}</div><div className="approval-type">{description}</div></div><div className="approval-amount">{amount}</div></div>)}</div></div></article></section>
        <section className="panel" style={{ marginTop: 16 }}><div className="panel-header"><h2 className="panel-title">Active project portfolio</h2><Link className="panel-link" href="/projects">Open projects <ChevronRight size={13} style={{ display: 'inline', verticalAlign: 'middle' }} /></Link></div><div className="table-wrap"><table className="data-table"><caption className="sr-only">Active project portfolio</caption><thead><tr><th scope="col">Project</th><th scope="col">Client</th><th scope="col">Contract value</th><th scope="col">Status</th><th scope="col">Completion</th></tr></thead><tbody>{projects.map(([name, client, amount, status, completion]) => <tr key={name}><td>{name}</td><td>{client}</td><td className="font-mono">{amount}</td><td><span className={`status-pill ${status === 'Active' ? 'status-green' : 'status-blue'}`}>{status}</span></td><td className="font-mono">{completion}</td></tr>)}</tbody></table></div></section>
      </main>
    </div>
     <div hidden={!drawerOpen} className={`mobile-drawer ${drawerOpen ? 'open' : ''}`} role="dialog" aria-modal="true" aria-label="Mobile navigation" onClick={() => setDrawerOpen(false)}><div className="mobile-drawer-panel" onClick={(event) => event.stopPropagation()}><div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}><Brand /><button className="mobile-menu" type="button" onClick={() => setDrawerOpen(false)} aria-label="Close navigation"><X size={18} /></button></div><Navigation onNavigate={() => setDrawerOpen(false)} /></div></div>
  </div>;
}

export function WorkspaceFrame({ children, sectionTitle = 'Operations' }: { children: ReactNode; sectionTitle?: string }) {
  return <DemoRoleProvider><WorkspaceFrameContent sectionTitle={sectionTitle}>{children}</WorkspaceFrameContent></DemoRoleProvider>;
}

function WorkspaceFrameContent({ children, sectionTitle }: { children: ReactNode; sectionTitle: string }) {
  const { role, setRole } = useDemoRole();
  const isDemo = process.env.NEXT_PUBLIC_APP_ENV === 'demo';
  const [drawerOpen, setDrawerOpen] = useState(false);
  const roleName = demoRoleLabel(role);
  useEffect(() => {
    if (!drawerOpen) return;
    const closeOnEscape = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setDrawerOpen(false);
    };
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    document.addEventListener('keydown', closeOnEscape);
    return () => {
      document.body.style.overflow = previousOverflow;
      document.removeEventListener('keydown', closeOnEscape);
    };
  }, [drawerOpen]);
  return <div className="shell-grid">
    <aside className="sidebar"><div className="sidebar-inner"><Brand /><Navigation /><div className="sidebar-footer"><div className="user-row"><div className="avatar">JD</div><div><div className="user-name">John Dela Cruz</div><div className="user-role">{roleName}</div></div></div></div></div></aside>
    <div className="main">
      {isDemo && <div className="demo-banner">Demo mode · Synthetic data resets every 30 minutes · No login required</div>}
      <header className="topbar"><div className="top-actions"><button className="mobile-menu" type="button" onClick={() => setDrawerOpen(true)} aria-label="Open navigation"><Menu size={18} /></button><div className="breadcrumb">Workspace <ChevronRight size={13} style={{ display: 'inline', verticalAlign: 'middle' }} /> <strong>{sectionTitle}</strong></div></div><div className="top-actions"><button className="icon-button" type="button" disabled aria-label="Notifications (coming soon)" title="Notifications are not available in this preview"><Bell aria-hidden="true" size={17} /></button>{isDemo && <><label className="role-label" htmlFor="module-role">Demo role</label><select className="role-select" id="module-role" value={role} onChange={(event) => setRole(event.target.value)}>{demoRoles.map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></>}</div></header>
      {children}
    </div>
    <div hidden={!drawerOpen} className={`mobile-drawer ${drawerOpen ? 'open' : ''}`} role="dialog" aria-modal="true" aria-label="Mobile navigation" onClick={() => setDrawerOpen(false)}><div className="mobile-drawer-panel" onClick={(event) => event.stopPropagation()}><div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}><Brand /><button className="mobile-menu" type="button" onClick={() => setDrawerOpen(false)} aria-label="Close navigation"><X size={18} /></button></div><Navigation onNavigate={() => setDrawerOpen(false)} /></div></div>
  </div>;
}
