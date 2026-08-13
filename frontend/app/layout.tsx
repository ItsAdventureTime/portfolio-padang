import '@fontsource-variable/inter';
import '@fontsource-variable/jetbrains-mono';
import '@fontsource-variable/outfit';
import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Padang ERP Lite',
  description: 'Operations management for Padang Construction and Supplies Corporation',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
