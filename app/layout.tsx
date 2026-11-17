import type { Metadata } from 'next';
import './globals.css';
import {ThemeProvider} from '@/components/theme-provider';
export const metadata: Metadata = { title: 'Zendo — Command Center', description: 'A Command Center for your links, tasks, calendar, and documents.' };
export default function Layout({children}: {children: React.ReactNode}) { return <html lang="en"><body><ThemeProvider>{children}</ThemeProvider></body></html>; }
