'use client';
import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
export default function Callback() {
 const [error,setError]=useState('');
 useEffect(()=>{ const code=new URLSearchParams(window.location.search).get('code'); if(!supabase || !code){setError('Missing sign-in code. Please try signing in again.');return;} supabase.auth.exchangeCodeForSession(code).then(({error})=>{if(error)setError(error.message);else window.location.replace('/');});},[]);
 return <main className="auth-card"><h1>Welcome to Zendo</h1><p>{error || 'Finishing your sign-in…'}</p>{error && <a href="/">Return to sign in</a>}</main>;
}
