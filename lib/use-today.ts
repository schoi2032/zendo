'use client';
import {useEffect,useState} from 'react';
import {localDateKey} from './command-center';

// Desktop dashboards can stay open overnight. Update at midnight and after wake.
export function useToday(){
  const [today,setToday]=useState(()=>localDateKey(new Date()));
  useEffect(()=>{
    const update=()=>setToday(localDateKey(new Date()));
    const timer=setInterval(update,30_000);
    window.addEventListener('focus',update);
    document.addEventListener('visibilitychange',update);
    return()=>{clearInterval(timer);window.removeEventListener('focus',update);document.removeEventListener('visibilitychange',update);};
  },[]);
  return today;
}
