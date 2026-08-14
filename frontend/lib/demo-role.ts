export const demoRoles = [
  ['administrator', 'Administrator'],
  ['general_manager', 'General Manager'],
  ['disbursing_check_signing_officer', 'DCS Officer'],
  ['project_manager', 'Project Manager'],
  ['procurement_officer', 'Procurement Officer'],
  ['fabrication_supervisor', 'Fabrication Supervisor'],
  ['finance_staff', 'Finance Staff'],
  ['billing_clerk', 'Billing Clerk'],
  ['inventory_clerk', 'Inventory Clerk'],
  ['viewer', 'Viewer'],
] as const;

export type DemoRole = (typeof demoRoles)[number][0];

export type DemoModule = 'dashboard' | 'projects' | 'fabrication' | 'procurement' | 'inventory' | 'billing' | 'finance' | 'reports' | 'settings';

type DemoRolePermissions = {
  modules: readonly DemoModule[];
  canCreate: boolean;
  canApprove: boolean;
  summary: string;
};

export const demoRolePermissions: Record<DemoRole, DemoRolePermissions> = {
  administrator: { modules: ['dashboard', 'projects', 'fabrication', 'procurement', 'inventory', 'billing', 'finance', 'reports', 'settings'], canCreate: true, canApprove: true, summary: 'Full navigation is visible; workflow writes remain unavailable in this preview.' },
  general_manager: { modules: ['dashboard', 'projects', 'fabrication', 'procurement', 'inventory', 'billing', 'finance', 'reports'], canCreate: false, canApprove: true, summary: 'Approval views are visible; creation and approval actions are read-only in this preview.' },
  disbursing_check_signing_officer: { modules: ['dashboard', 'procurement', 'inventory', 'billing', 'finance', 'reports'], canCreate: false, canApprove: true, summary: 'Finance and approval views are visible; payment actions are not connected.' },
  project_manager: { modules: ['dashboard', 'projects', 'fabrication', 'inventory', 'reports'], canCreate: true, canApprove: false, summary: 'Project and field views are visible; record creation is not connected.' },
  procurement_officer: { modules: ['dashboard', 'procurement', 'inventory', 'reports'], canCreate: true, canApprove: false, summary: 'Procurement views are visible; purchase workflows are read-only.' },
  fabrication_supervisor: { modules: ['dashboard', 'fabrication', 'inventory', 'reports'], canCreate: true, canApprove: false, summary: 'Shop-floor views are visible; job-order actions are not connected.' },
  finance_staff: { modules: ['dashboard', 'billing', 'finance', 'reports'], canCreate: true, canApprove: false, summary: 'Finance views are visible; payment and liquidation actions are not connected.' },
  billing_clerk: { modules: ['dashboard', 'projects', 'billing', 'reports'], canCreate: true, canApprove: false, summary: 'Billing views are visible; billing submission is not connected.' },
  inventory_clerk: { modules: ['dashboard', 'procurement', 'inventory', 'reports'], canCreate: true, canApprove: false, summary: 'Inventory views are visible; stock mutation actions are not connected.' },
  viewer: { modules: ['dashboard', 'projects', 'fabrication', 'reports'], canCreate: false, canApprove: false, summary: 'Read-only navigation is visible for this role.' },
};

const defaultDemoRole: DemoRole = 'general_manager';
export const demoRoleStorageKey = 'padang_demo_role';

export function isDemoRole(value: string): value is DemoRole {
  return demoRoles.some(([role]) => role === value);
}

export function getDemoRole(): DemoRole {
  if (typeof window === 'undefined') return defaultDemoRole;
  const stored = window.sessionStorage.getItem(demoRoleStorageKey);
  return stored && isDemoRole(stored) ? stored : defaultDemoRole;
}

export function setDemoRole(value: string): DemoRole {
  const role = isDemoRole(value) ? value : defaultDemoRole;
  if (typeof window !== 'undefined') {
    window.sessionStorage.setItem(demoRoleStorageKey, role);
    window.dispatchEvent(new Event('padang-demo-role-change'));
  }
  return role;
}

export function subscribeDemoRole(callback: () => void): () => void {
  if (typeof window === 'undefined') return () => undefined;
  window.addEventListener('storage', callback);
  window.addEventListener('padang-demo-role-change', callback);
  return () => {
    window.removeEventListener('storage', callback);
    window.removeEventListener('padang-demo-role-change', callback);
  };
}

export function demoRoleLabel(role: DemoRole): string {
  return demoRoles.find(([value]) => value === role)?.[1] ?? 'General Manager';
}

export function demoPermissions(role: DemoRole): DemoRolePermissions {
  return demoRolePermissions[role];
}

export function demoCanAccess(role: DemoRole, module: DemoModule): boolean {
  return demoRolePermissions[role].modules.includes(module);
}
