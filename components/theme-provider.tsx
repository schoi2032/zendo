'use client';
import {createContext, useContext, useEffect, useState} from 'react';
export type Theme = 'light' | 'dark' | 'system';
const ThemeContext = createContext<{theme: Theme; setTheme:(theme:Theme)=>void; error:string}>({theme:'system',setTheme:()=>{},error:''});
export function ThemeProvider({children}:{children:React.ReactNode}) {
  const [theme,setThemeState]=useState<Theme>('system');
  const [loaded,setLoaded]=useState(false);
  const [error,setError]=useState('');
  useEffect(()=>{try{const stored=localStorage.getItem('zendo-theme');if(stored==='light'||stored==='dark'||stored==='system')setThemeState(stored);}catch{setError('Your browser could not load your theme preference.');}setLoaded(true);},[]);
  useEffect(()=>{
    if(!loaded)return;
    const media=window.matchMedia('(prefers-color-scheme: dark)');
    const apply=()=>{document.documentElement.dataset.theme=theme==='system'?(media.matches?'dark':'light'):theme;};
    apply();media.addEventListener('change',apply);
    return()=>media.removeEventListener('change',apply);
  },[theme,loaded]);
  function setTheme(value:Theme){setThemeState(value);try{localStorage.setItem('zendo-theme',value);setError('');}catch{setError('Theme changed, but your browser could not save it for next time.');}}
  return <ThemeContext.Provider value={{theme,setTheme,error}}>{children}</ThemeContext.Provider>;
}
export const useTheme=()=>useContext(ThemeContext);
