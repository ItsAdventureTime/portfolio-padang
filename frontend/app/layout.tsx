import '@fontsource-variable/inter';
import '@fontsource-variable/jetbrains-mono';
import '@fontsource-variable/outfit';
import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Padang ERP Lite',
  applicationName: 'Padang ERP Lite',
  description: 'Operations management for Padang Construction and Supplies Corporation',
  icons: {
    icon: `${(process.env.NEXT_PUBLIC_BASE_PATH ?? '').replace(/\/+$/, '')}/assets/padang-logo.jpg`,
    apple: `${(process.env.NEXT_PUBLIC_BASE_PATH ?? '').replace(/\/+$/, '')}/assets/padang-logo.jpg`,
  },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
