import { formatStatus, statusTone } from '@/lib/formatters';

export function StatusBadge({ value }: { value: unknown }) {
  const label = formatStatus(value);
  return <span className={`status-pill status-${statusTone(value)}`}>{label}</span>;
}
