'use client';
import {useEffect,useState} from 'react';
import {authCallback,appHome} from '@/lib/paths';
export default function DesktopAuth(){
 const [error,setError]=useState('');
 useEffect(()=>{
   try{
     const params=new URLSearchParams(window.location.hash.slice(1));
     const target=new URL(params.get('url')||'');
     const configured=new URL(process.env.NEXT_PUBLIC_SUPABASE_URL||'');
     const state=params.get('state')||'';
     const redirect=new URL(authCallback,window.location.origin).href;
     if(target.origin!==configured.origin||target.pathname!=='/auth/v1/authorize'||target.searchParams.get('provider')!=='google'||target.searchParams.get('redirect_to')!==redirect||!/^[-a-zA-Z0-9]{32,64}$/.test(state))throw new Error('Invalid sign-in request. Start again from Zendo for Mac.');
     sessionStorage.setItem('zendo-native-auth',state);
     history.replaceState(null,'',window.location.pathname);
     window.location.replace(target.href);
   }catch(e){setError((e as Error).message);}
 },[]);
 return <main className="auth-card"><h1>Sign in to Zendo for Mac</h1><p role={error?'alert':'status'}>{error||'Opening Google sign-in…'}</p>{error&&<a href={appHome}>Open Zendo</a>}</main>;
}
