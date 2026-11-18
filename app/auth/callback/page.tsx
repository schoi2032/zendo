'use client';
import { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase';
import { appHome } from '@/lib/paths';
import { nativeAuthPending } from '@/lib/desktop';

export default function Callback() {
  const [error, setError] = useState('');

  useEffect(() => {
    let active = true;
    async function finishSignIn() {
      // The browser returns only the one-use PKCE code. The verifier and session
      // remain in the Mac app's web view; no tokens cross this custom URL.
      if (nativeAuthPending()) {
        const state = sessionStorage.getItem('zendo-native-auth')!;
        sessionStorage.removeItem('zendo-native-auth');
        const query = new URLSearchParams(window.location.search);
        const code = query.get('code');
        const result = new URL('zendo://auth/callback');
        result.searchParams.set('state', state);
        if (code) result.searchParams.set('code', code);
        else result.searchParams.set('error', query.get('error_description') || 'Sign-in was cancelled.');
        window.location.replace(result.href);
        return;
      }
      if (!supabase) {
        setError('Sign-in is not configured yet.');
        return;
      }
      // detectSessionInUrl already exchanges the one-use OAuth code. Await that
      // same initialization promise instead of exchanging it a second time.
      const { error: initializationError } = await supabase.auth.initialize();
      if (!active) return;
      if (initializationError) {
        setError('We couldn’t finish this sign-in. Return to sign in and try again in the same browser.');
        return;
      }
      const { data, error: sessionError } = await supabase.auth.getSession();
      if (!active) return;
      if (sessionError || !data.session) {
        setError('This sign-in has expired. Return to sign in and start again.');
        return;
      }
      window.location.replace(appHome);
    }
    void finishSignIn().catch(() => {
      if (active) setError('Sign-in could not finish. Check your connection and try again.');
    });
    return () => { active = false; };
  }, []);

  return <main className="auth-card"><h1>Welcome to Zendo</h1><p role={error ? 'alert' : 'status'}>{error || 'Finishing your sign-in…'}</p>{error && <a href={appHome}>Return to sign in</a>}</main>;
}
