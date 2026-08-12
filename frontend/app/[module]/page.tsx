import { ModuleWorkspace, type ModuleKey } from '@/components/module-workspace';
import { WorkspaceFrame } from '@/components/layout/dashboard-shell';

const moduleNames: Record<string, string> = {
  projects: 'Projects',
  fabrication: 'Fabrication',
  procurement: 'Procurement',
  inventory: 'Inventory',
  billing: 'Billing & Collections',
  finance: 'Finance Operations',
  reports: 'Reports',
  settings: 'Settings',
};

export default async function ModulePage({ params }: { params: Promise<{ module: string }> }) {
  const { module } = await params;
  return <WorkspaceFrame><ModuleWorkspace module={(module in moduleNames ? module : 'settings') as ModuleKey} /></WorkspaceFrame>;
}
