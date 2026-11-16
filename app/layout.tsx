import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'Zendo — A little space for everything', description: 'A calm workspace for your tasks, dates, and ideas.' };
export default function Layout({children}: {children: React.ReactNode}) { return <html lang="en"><body>{children}</body></html>; }
