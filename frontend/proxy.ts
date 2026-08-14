import { NextResponse, type NextRequest } from 'next/server';

const basePath = (process.env.NEXT_PUBLIC_BASE_PATH ?? '').replace(/\/+$/, '');
const protectedModules = new Set(['projects', 'fabrication', 'procurement', 'inventory', 'billing', 'finance', 'reports', 'settings']);

function withoutBasePath(pathname: string) {
  if (basePath && (pathname === basePath || pathname.startsWith(`${basePath}/`))) {
    return pathname.slice(basePath.length) || '/';
  }
  return pathname || '/';
}

function isProtectedRoute(route: string) {
  if (route === '/') return true;
  const moduleName = route.split('/')[1];
  return protectedModules.has(moduleName);
}

export function proxy(request: NextRequest) {
  // Demo is intentionally public. The shell labels demo data and the API
  // validates the X-Demo-Role header before returning anything.
  if (process.env.NEXT_PUBLIC_APP_ENV === 'demo') return NextResponse.next();

  const route = withoutBasePath(request.nextUrl.pathname);
  if (route === '/login' || route.startsWith('/_next') || route.startsWith('/api/') || !isProtectedRoute(route)) {
    return NextResponse.next();
  }

  if (!request.cookies.get('padang_refresh_token')?.value) {
    const login = request.nextUrl.clone();
    login.pathname = `${basePath}/login` || '/login';
    login.searchParams.set('next', `${route}${request.nextUrl.search}`);
    return NextResponse.redirect(login);
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|assets/).*)'],
};
