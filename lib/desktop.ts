export type Shortcut = {id:string;name:string;kind:'app'|'file'|'folder'};
export type DesktopState = {desktop:boolean;login:boolean;shortcuts:Shortcut[]};
type DesktopAction = 'getState'|'setDesktop'|'setLogin'|'addShortcut'|'openShortcut'|'removeShortcut'|'signIn';
declare global {
  interface Window { webkit?:{messageHandlers?:{zendo?:{postMessage:(message:Record<string,unknown>)=>Promise<unknown>}}}; }
}
export function hasDesktopBridge(){return typeof window!=='undefined'&&!!window.webkit?.messageHandlers?.zendo;}
export async function desktopRequest<T=DesktopState>(action:DesktopAction='getState',value?:unknown):Promise<T>{
  const bridge=window.webkit?.messageHandlers?.zendo;
  if(!bridge)throw new Error('Open Zendo for Mac to use this feature.');
  return await bridge.postMessage({action,value}) as T;
}
export function nativeAuthPending(){
  if(typeof window==='undefined')return false;
  try{return !!sessionStorage.getItem('zendo-native-auth');}catch{return false;}
}
