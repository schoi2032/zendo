import type { Metadata } from 'next';
import './globals.css';
import {ThemeProvider} from '@/components/theme-provider';
export const metadata: Metadata = { title: 'Zendo — Workspace', description: 'Tasks, events, notes, and documents in one workspace.' };
export default function Layout({children}: {children: React.ReactNode}) { return <html lang="en"><body><ThemeProvider>{children}</ThemeProvider></body></html>; }
