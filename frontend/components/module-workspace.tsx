'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { ArrowUpRight, ChevronRight, RefreshCw, Search } from 'lucide-react';
import { StatusBadge } from '@/components/ui/status-badge';
import { apiFetch } from '@/lib/api-client';
import { useDemoRole } from '@/lib/demo-role-context';
import { demoCanAccess, demoRoleLabel, demoPermissions } from '@/lib/demo-role';
import { formatDate, formatPHP } from '@/lib/formatters';

export type ModuleKey = 'projects' | 'fabrication' | 'procurement' | 'inventory' | 'billing' | 'finance' | 'reports' | 'settings';
type Row = Record<string, string | number | null | undefined>;
type ModuleConfig = { title: string; description: string; eyebrow: string; endpoint?: string; columns: Array<[string, string]>; fallback: Row[]; cards: Array<[string, string, string]> };
type RequestState = 'preview' | 'loading' | 'live' | 'error' | 'unavailable';

const modules: Record<ModuleKey, ModuleConfig> = {
  projects: {
    title: 'Projects', eyebrow: 'Delivery portfolio', description: 'Track contracts, BOQ progress, variations, costing, and documents from one operational view.', endpoint: '/api/v1/projects',
    columns: [['project_code', 'Code'], ['project_name', 'Project'], ['client_name', 'Client'], ['contract_amount', 'Contract value'], ['status', 'Status']],
    fallback: [
      { project_code: 'PRJ-ABC-001', project_name: 'ABC Building Construction', client_name: 'ABC Holdings Inc.', contract_amount: '₱12,450,000', status: 'active' },
      { project_code: 'PRJ-SFW-002', project_name: 'San Fernando Warehouse', client_name: 'Padang Properties', contract_amount: '₱8,200,000', status: 'active' },
      { project_code: 'PRJ-MRI-003', project_name: 'Mexico Road Improvement', client_name: 'City Engineering Office', contract_amount: '₱5,780,000', status: 'planning' },
    ], cards: [['3', 'Tracked projects', '1 planning'], ['₱26.43M', 'Contract value', 'Across active portfolio'], ['68%', 'Top completion', 'ABC Building']],
  },
  fabrication: {
    title: 'Fabrication', eyebrow: 'Shop floor control', description: 'Move estimates through production, delivery, billing, and job profitability.', endpoint: '/api/v1/fabrication',
    columns: [['job_number', 'Job'], ['client_name', 'Client'], ['description', 'Description'], ['status', 'Status'], ['proposed_price', 'Proposed price']],
    fallback: [{ job_number: 'FAB-2026-001', client_name: 'ABC Holdings Inc.', description: 'Structural steel package', status: 'in_production', proposed_price: '₱1,850,000' }, { job_number: 'FAB-2026-002', client_name: 'Padang Properties', description: 'Warehouse rolling doors', status: 'job_order', proposed_price: '₱620,000' }, { job_number: 'FAB-2026-003', client_name: 'City Engineering Office', description: 'Guardrail fabrication', status: 'delivered', proposed_price: '₱410,000' }], cards: [['3', 'Open job orders', '2 in production'], ['₱2.88M', 'Proposed revenue', 'Current job book'], ['1', 'Delivery due', 'This week']],
  },
  procurement: {
    title: 'Procurement', eyebrow: 'Buy with control', description: 'Follow purchase requests, purchase orders, suppliers, and fund requests through approval.', endpoint: '/api/v1/procurement/purchase-requests',
    columns: [['pr_number', 'Request'], ['purpose', 'Purpose'], ['status', 'Status'], ['created_at', 'Created']],
    fallback: [{ pr_number: 'PR-2026-0042', purpose: 'Structural steel supply · ABC Building', status: 'submitted', created_at: '12 Aug 2026' }, { pr_number: 'PR-2026-0041', purpose: 'Site safety equipment', status: 'approved', created_at: '11 Aug 2026' }, { pr_number: 'PR-2026-0040', purpose: 'Warehouse electrical materials', status: 'fulfilled', created_at: '08 Aug 2026' }], cards: [['12', 'Open requests', '4 awaiting action'], ['₱1.74M', 'Committed POs', 'This month'], ['4', 'Supplier accounts', 'Active']],
  },
  inventory: {
    title: 'Inventory', eyebrow: 'Materials and stock', description: 'See on-hand quantities, weighted-average cost, reorder alerts, and material issues.', endpoint: '/api/v1/inventory/items',
    columns: [['item_code', 'Item'], ['description', 'Description'], ['category', 'Category'], ['current_qty', 'On hand'], ['avg_unit_cost', 'Avg cost']],
    fallback: [{ item_code: 'STL-PL-010', description: 'Steel plate 10mm', category: 'Structural steel', current_qty: '42 sheets', avg_unit_cost: '₱18,500' }, { item_code: 'CEM-040', description: 'Portland cement 40kg', category: 'Concrete', current_qty: '280 bags', avg_unit_cost: '₱285' }, { item_code: 'WEL-7018', description: 'Welding rods E7018', category: 'Consumables', current_qty: '18 boxes', avg_unit_cost: '₱1,240' }], cards: [['42', 'Stock items', 'Across categories'], ['₱1.08M', 'Stock valuation', 'Weighted average'], ['3', 'Reorder alerts', 'Review today']],
  },
  billing: {
    title: 'Billing & Collections', eyebrow: 'Revenue operations', description: 'Prepare progress billings, monitor collections, and keep retention, VAT, and EWT visible.', endpoint: '/api/v1/billing/progress',
    columns: [['billing_number', 'Billing'], ['project_id', 'Project'], ['gross_amount', 'Gross'], ['net_amount', 'Net due'], ['status', 'Status']],
    fallback: [{ billing_number: 'PB-ABC-2026-03', project_id: 'ABC Building', gross_amount: '₱720,000', net_amount: '₱642,880', status: 'gm_approval' }, { billing_number: 'PB-SFW-2026-02', project_id: 'San Fernando Warehouse', gross_amount: '₱410,000', net_amount: '₱366,520', status: 'issued' }, { billing_number: 'PB-MRI-2026-01', project_id: 'Mexico Road Improvement', gross_amount: '₱285,000', net_amount: '₱254,460', status: 'partial_collected' }], cards: [['3', 'Open billings', '1 awaiting GM'], ['₱1.26M', 'Outstanding AR', '₱380K due this week'], ['₱126K', 'Retention held', 'Current portfolio']],
  },
  finance: {
    title: 'Finance Operations', eyebrow: 'Cash discipline', description: 'Coordinate reimbursements, liquidations, payments, and the DCS execution queue.', endpoint: '/api/v1/finance/reimbursements',
    columns: [['purpose', 'Request'], ['amount', 'Amount'], ['status', 'Status'], ['receipt_reference', 'Reference']],
    fallback: [{ purpose: 'Site fuel reimbursement · J. Dela Cruz', amount: '₱18,400', status: 'submitted', receipt_reference: 'OR-88231' }, { purpose: 'Advance liquidation · ABC site', amount: '₱74,200', status: 'submitted', receipt_reference: 'LIQ-2026-014' }, { purpose: 'Office utilities · August', amount: '₱42,800', status: 'approved', receipt_reference: 'FR-2026-0040' }], cards: [['7', 'Pending actions', 'GM and DCS queues'], ['₱412K', 'Due for payment', 'Approved requests'], ['₱96K', 'Unliquidated', 'Review this week']],
  },
  reports: {
    title: 'Reports', eyebrow: 'Decision support', description: 'Turn operational records into profitability, cash, purchasing, and aging views for management.',
    columns: [['name', 'Report'], ['period', 'Period'], ['owner', 'Audience'], ['status', 'Status']],
    fallback: [{ name: 'Project profitability', period: 'Jan–Aug 2026', owner: 'GM / Admin', status: 'ready' }, { name: 'Collections aging', period: 'As of 12 Aug 2026', owner: 'GM / Billing', status: 'ready' }, { name: 'Budget vs actual', period: 'FY 2026', owner: 'GM / PM', status: 'ready' }], cards: [['8', 'Standard reports', 'Filterable views'], ['₱1.24M', 'Receivables', 'Current snapshot'], ['₱3.18M', 'Costs posted', 'FY 2026']],
  },
  settings: {
    title: 'Settings', eyebrow: 'Workspace controls', description: 'Demo settings are intentionally read-only. Production administrators will manage users, roles, and configuration here.',
    columns: [['name', 'Control'], ['owner', 'Owner'], ['status', 'Status']],
    fallback: [{ name: 'User and role management', owner: 'Administrator', status: 'production_only' }, { name: 'Email provider', owner: 'Administrator', status: 'production_only' }, { name: 'Backblaze B2 storage', owner: 'Administrator', status: 'production_only' }], cards: [['10', 'Defined roles', 'Canonical identifiers'], ['2', 'Environments', 'Demo and production'], ['1', 'Codebase', 'Web + future mobile']],
  },
};

function displayValue(value: Row[string]) {
  if (value === null || value === undefined || value === '') return '—';
  return String(value).replaceAll('_', ' ');
}

function readRows(payload: unknown): Row[] {
  if (typeof payload !== 'object' || payload === null || !Array.isArray((payload as { data?: unknown }).data) || !(payload as { data: unknown[] }).data.every((row) => typeof row === 'object' && row !== null && !Array.isArray(row))) {
    throw new Error('The API returned an invalid register response.');
  }
  return (payload as { data: Row[] }).data;
}

function cellValue(key: string, value: Row[string]) {
  if (key === 'status') return <StatusBadge value={value} />;
  if (key.endsWith('_at') || key.endsWith('_date')) return formatDate(value);
  if (key.includes('amount') || key.includes('price') || key.includes('cost')) return formatPHP(value);
  return displayValue(value);
}

function SkeletonRows({ columnCount }: { columnCount: number }) {
  return <>{[1, 2, 3].map((row) => <tr key={row} aria-hidden="true">{Array.from({ length: columnCount + 1 }, (_, column) => <td data-label="" key={column}><span className="skeleton" /></td>)}</tr>)}</>;
}

export function ModuleWorkspace({ module }: { module: ModuleKey }) {
  const config = modules[module];
  const { role } = useDemoRole();
  const isDemo = process.env.NEXT_PUBLIC_APP_ENV === 'demo';
  const hasAccess = !isDemo || demoCanAccess(role, module);
  const initialState: RequestState = !hasAccess ? 'unavailable' : config.endpoint ? 'loading' : isDemo ? 'preview' : 'unavailable';
  const [rows, setRows] = useState<Row[]>(hasAccess && isDemo && !config.endpoint ? config.fallback : []);
  const [query, setQuery] = useState('');
  const [requestState, setRequestState] = useState<RequestState>(initialState);
  const [errorMessage, setErrorMessage] = useState('');
  const [retryNonce, setRetryNonce] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    const resetStateTimer = window.setTimeout(() => {
      if (!controller.signal.aborted) {
        setQuery('');
        setErrorMessage('');
        setRows([]);
      }
    }, 0);

    if (isDemo && !demoCanAccess(role, module)) {
      const unavailableStateTimer = window.setTimeout(() => {
        if (!controller.signal.aborted) setRequestState('unavailable');
      }, 0);
      return () => {
        controller.abort();
        window.clearTimeout(unavailableStateTimer);
      };
    }
    if (!config.endpoint) {
      window.clearTimeout(resetStateTimer);
      window.setTimeout(() => {
        if (!controller.signal.aborted) {
          setRows(isDemo ? config.fallback : []);
          setRequestState(isDemo ? 'preview' : 'unavailable');
        }
      }, 0);
      return () => controller.abort();
    }

    const loadingStateTimer = window.setTimeout(() => {
      if (!controller.signal.aborted) setRequestState('loading');
    }, 0);
    apiFetch<unknown>(config.endpoint, { signal: controller.signal }).then((payload) => {
      if (controller.signal.aborted) return;
      setRows(readRows(payload));
      setRequestState('live');
    }).catch((error: unknown) => {
      if (controller.signal.aborted) return;
      setRows([]);
      setRequestState('error');
      setErrorMessage(error instanceof Error ? error.message : 'Live data could not be loaded.');
    });
    return () => {
      controller.abort();
      window.clearTimeout(resetStateTimer);
      window.clearTimeout(loadingStateTimer);
    };
  }, [config, isDemo, module, retryNonce, role]);

  const normalizedQuery = query.toLowerCase().trim();
  const filtered = useMemo(() => {
    if (!normalizedQuery) return rows;
    return rows.filter((row) => Object.values(row).some((value) => String(value ?? '').toLowerCase().includes(normalizedQuery)));
  }, [normalizedQuery, rows]);

  const statusCopy = requestState === 'live'
    ? `${filtered.length} of ${rows.length} live records shown.`
    : requestState === 'loading'
      ? 'Loading live data…'
      : requestState === 'error'
        ? 'Live data is unavailable. No sample rows were substituted.'
        : requestState === 'unavailable'
          ? (hasAccess ? 'This register is not connected to the production API yet.' : `${demoRoleLabel(role)} does not have access to this demo module.`)
          : 'Sample rows for this clearly labeled demo preview.';

  const liveEmpty = requestState === 'live' && rows.length === 0;
  const searchEmpty = requestState === 'live' && rows.length > 0 && filtered.length === 0;

  return <main id="workspace-main" className="content module-content">
    <div className="module-breadcrumb"><Link href="/">Workspace</Link><ChevronRight size={14} aria-hidden="true" /><span>{config.title}</span></div>
    <section className="page-heading"><div><div className="eyebrow">{config.eyebrow}</div><h1 className="page-title">{config.title}</h1><p className="page-copy">{config.description}</p></div><span className="read-only-action" title="Record creation is not connected in this build">Read-only register</span></section>
    <div className={`data-status ${requestState === 'error' ? 'data-status-error' : ''}`} role={requestState === 'error' ? 'alert' : 'status'} aria-live="polite">
      <div><strong>{requestState === 'live' ? 'Live API data' : requestState === 'preview' ? 'Demo preview' : requestState === 'error' ? 'Unable to load register' : requestState === 'loading' ? 'Loading register' : 'Register status'}</strong><span>{statusCopy}</span>{errorMessage && <span className="data-status-detail">{errorMessage}</span>}</div>
      {requestState === 'error' && <button className="secondary-button" type="button" onClick={() => setRetryNonce((value) => value + 1)}><RefreshCw size={14} aria-hidden="true" /> Retry</button>}
    </div>
    <div className="sr-only" role="status" aria-live="polite">{requestState === 'live' ? `${filtered.length} records shown.` : statusCopy}</div>
    {requestState === 'unavailable' && !hasAccess ? <section className="panel module-access" aria-live="polite"><h2 className="panel-title">Module hidden for this role</h2><p>{demoPermissions(role).summary}</p><Link className="secondary-button" href="/">Return to dashboard</Link></section> : <>
      {isDemo && <section className="stats-grid" aria-label={`${config.title} demo summary`}>{config.cards.map(([value, label, meta]) => <article className="stat-card" key={label}><div className="stat-label">{label}</div><div className="stat-value">{value}</div><div className="stat-meta stat-meta-muted">{meta}</div></article>)}</section>}
          <section className="panel" style={{ marginTop: 16 }} aria-busy={requestState === 'loading'}><div className="panel-header"><div><h2 className="panel-title">{config.title} register</h2><p className="panel-subtitle">{statusCopy}</p></div><label className="search-field" htmlFor={`${module}-search`}><Search size={15} aria-hidden="true" /><span className="sr-only">Search {config.title}</span><input id={`${module}-search`} value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search records" /></label></div><div className="table-wrap"><table className="data-table"><caption className="sr-only">{config.title} register</caption><thead><tr>{config.columns.map(([, label]) => <th key={label} scope="col">{label}</th>)}<th scope="col"><span className="sr-only">Actions</span></th></tr></thead><tbody>{requestState === 'loading' ? <SkeletonRows columnCount={config.columns.length} /> : filtered.map((row, index) => <tr key={String(row[config.columns[0][0]] ?? index)}>{config.columns.map(([key, label]) => <td data-label={label} key={key} className={key.includes('amount') || key.includes('price') || key.includes('cost') ? 'font-mono' : ''}>{cellValue(key, row[key])}</td>)}<td data-label="Actions"><span className="read-only-control" title="Record details are not available in this build"><ArrowUpRight aria-hidden="true" size={15} /><span className="sr-only">Details are read-only</span></span></td></tr>)}</tbody></table></div>{liveEmpty && <div className="empty-state">No live records have been created yet.</div>}{searchEmpty && <div className="empty-state">No live records match “{query}”.</div>}{requestState === 'preview' && <div className="empty-state">Preview rows are illustrative only and are not saved.</div>}{requestState === 'unavailable' && hasAccess && <div className="empty-state">No production rows are shown until this register is connected.</div>}</section>
    </>}
  </main>;
}
