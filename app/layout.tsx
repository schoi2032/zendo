import type { Metadata } from 'next';
import './globals.css';
import {ThemeProvider} from '@/components/theme-provider';
export const metadata: Metadata = { title: 'Zendo — A little space for everything', description: 'A calm workspace for your tasks, dates, and ideas.' };
export default function Layout({children}: {children: React.ReactNode}) { return <html lang="en"><body><ThemeProvider>{children}</ThemeProvider></body></html>; }
