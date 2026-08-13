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
