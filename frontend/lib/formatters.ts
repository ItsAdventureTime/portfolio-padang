export type StatusTone = 'green' | 'amber' | 'blue' | 'slate' | 'red';

const statusLabels: Record<string, string> = {
  active: 'Active',
  approved: 'Approved',
  delivered: 'Delivered',
  fulfilled: 'Fulfilled',
  gm_approval: 'GM approval',
  in_production: 'In production',
  issued: 'Issued',
  job_order: 'Job order',
  partial_collected: 'Partially collected',
  planning: 'Planning',
  production_only: 'Production only',
  ready: 'Ready',
  submitted: 'Submitted',
};

export function formatPHP(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value === 'string' && !/^-?\s*(?:₱|PHP)?\s*[\d,]+(?:\.\d+)?\s*$/.test(value)) return value;

  const numeric = Number(String(value).replace(/₱|PHP|,/gi, '').trim());
  if (!Number.isFinite(numeric)) return String(value);

  return new Intl.NumberFormat('en-PH', {
    style: 'currency',
    currency: 'PHP',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(numeric);
}

export function formatDate(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—';
  const raw = String(value);
  const date = new Date(raw);
  if (Number.isNaN(date.getTime())) return raw;

  return new Intl.DateTimeFormat('en-PH', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    timeZone: 'Asia/Manila',
  }).format(date);
}

export function formatStatus(value: unknown): string {
  if (value === null || value === undefined || value === '') return 'Not set';
  const normalized = String(value).toLowerCase().replaceAll(' ', '_');
  return statusLabels[normalized] ?? normalized.replaceAll('_', ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

export function statusTone(value: unknown): StatusTone {
  const normalized = String(value ?? '').toLowerCase();
  if (['active', 'approved', 'delivered', 'fulfilled', 'issued', 'ready'].includes(normalized)) return 'green';
  if (['gm_approval', 'in_production', 'job_order', 'planning', 'submitted'].includes(normalized)) return 'amber';
  if (['partial_collected', 'production_only'].includes(normalized)) return 'blue';
  if (normalized.includes('reject') || normalized.includes('fail') || normalized.includes('overdue')) return 'red';
  return 'slate';
}
