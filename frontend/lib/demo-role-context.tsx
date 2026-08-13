'use client';

import { createContext, type ReactNode, useCallback, useContext, useMemo, useSyncExternalStore } from 'react';
import { getDemoRole, setDemoRole, subscribeDemoRole, type DemoRole } from './demo-role';

type DemoRoleContextValue = {
  role: DemoRole;
  setRole: (value: string) => void;
};

const DemoRoleContext = createContext<DemoRoleContextValue | null>(null);

export function DemoRoleProvider({ children }: { children: ReactNode }) {
  const role = useSyncExternalStore(subscribeDemoRole, getDemoRole, () => 'general_manager' as DemoRole);
  const setRole = useCallback((next: string) => setDemoRole(next), []);

  const value = useMemo(() => ({
    role,
    setRole,
  }), [role, setRole]);

  return <DemoRoleContext.Provider value={value}>{children}</DemoRoleContext.Provider>;
}

export function useDemoRole(): DemoRoleContextValue {
  const context = useContext(DemoRoleContext);
  if (!context) throw new Error('useDemoRole must be used inside DemoRoleProvider');
  return context;
}
