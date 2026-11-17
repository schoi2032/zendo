'use client';
import {useEffect,useRef,useState} from 'react';
import {Monitor,Sun,Moon,Users,Trash2,LogOut,ShieldCheck} from 'lucide-react';
import {supabase} from '@/lib/supabase';
import {useTheme,type Theme} from './theme-provider';
type Workspace={id:string;name:string;owner_id:string;personal:boolean;icon?:string};
type Props={space:Workspace|undefined;userId:string;email:string;displayName:string;onChanged:()=>Promise<void>;onMembers:()=>void;onNotice:(message:string)=>void};
export default function Settings({space,userId,email,displayName,onChanged,onMembers,onNotice}:Props){
  const {theme,setTheme,error:themeError}=useTheme();
  const [name,setName]=useState(space?.name??'');
  const [profileName,setProfileName]=useState(displayName);
  const [icon,setIcon]=useState(space?.icon??'◻');
  const workspaceIcons=['◻','🏠','💼','📚','🎨','🚀','⭐','🌙','🧩','📁','🎯','☕'];
  useEffect(()=>setProfileName(displayName),[displayName]);
  const [confirmation,setConfirmation]=useState('');
  const [confirming,setConfirming]=useState(false);
  const [busy,setBusy]=useState(false);
  const [error,setError]=useState('');
  const nameInput=useRef<HTMLInputElement>(null);
  const owner=space?.owner_id===userId;
  useEffect(()=>{setName(space?.name??'');setIcon(space?.icon??'◻');setConfirmation('');setConfirming(false);setError('');},[space?.id,space?.name,space?.icon]);
  async function rename(e:React.FormEvent){
    e.preventDefault();if(!supabase||!space||!owner||busy)return;
    setBusy(true);setError('');
    try{const {error}=await supabase.rpc('rename_workspace',{workspace_id:space.id,workspace_name:name.trim()});if(error)throw error;await onChanged();onNotice('Workspace name updated.');}catch(e){setError(e instanceof Error?e.message:(e as {message?:string}).message??'Could not rename this workspace.');}finally{setBusy(false);}
  }
  async function saveIcon(){
    if(!supabase||!space||!owner||busy)return;
    setBusy(true);setError('');
    try{const {error}=await supabase.rpc('set_workspace_icon',{workspace_id:space.id,workspace_icon:icon});if(error)throw error;await onChanged();onNotice('Workspace icon updated.');}catch(e){setError((e as {message?:string}).message??'Could not update workspace icon.');}finally{setBusy(false);}
  }
  async function saveProfile(e:React.FormEvent){
    e.preventDefault();if(!supabase||busy||!profileName.trim())return;
    setBusy(true);setError('');
    try{const {error}=await supabase.auth.updateUser({data:{display_name:profileName.trim()}});if(error)throw error;onNotice('Display name updated.');}catch(e){setError((e as {message?:string}).message??'Could not save your name.');}finally{setBusy(false);}
  }
  async function deleteWorkspace(e:React.FormEvent){
    e.preventDefault();if(!supabase||!space||!owner||space.personal||confirmation!==space.name||busy)return;
    setBusy(true);setError('');
    try{const {error}=await supabase.rpc('delete_workspace',{workspace_id:space.id,confirmation_name:confirmation});if(error)throw error;await onChanged();onNotice('Workspace deleted. You’ve switched to another workspace.');}catch(e){setError(e instanceof Error?e.message:(e as {message?:string}).message??'Could not delete this workspace.');}finally{setBusy(false);}
  }
  async function signOut(){if(!supabase||busy)return;setBusy(true);setError('');try{const {error}=await supabase.auth.signOut();if(error)throw error;}catch{setError('Could not sign out. Please try again.');}finally{setBusy(false);}}
  const themes:{value:Theme;label:string;Icon:typeof Sun}[]=[{value:'light',label:'Light',Icon:Sun},{value:'dark',label:'Dark',Icon:Moon},{value:'system',label:'System',Icon:Monitor}];
  return <><div className="page-heading"><div><h1>Settings<span className="sage">.</span></h1><p>Manage your account, appearance, and workspace.</p></div></div><div className="settings-stack">
    <section className="panel settings-card" aria-labelledby="appearance-title"><h2 id="appearance-title">Appearance</h2><p>System follows your device’s appearance.</p><div className="theme-options" role="group" aria-label="Color theme">{themes.map(({value,label,Icon})=><button key={value} className={`theme-option ${theme===value?'selected':''}`} aria-pressed={theme===value} onClick={()=>setTheme(value)}><span className={`theme-preview ${value}`}><span/><span/><span/></span><span><Icon size={16}/>{label}</span></button>)}</div><p className="settings-caption">Saved in this browser.</p>{themeError&&<p className="save-error" role="alert">{themeError}</p>}</section>
    <section className="panel settings-card" aria-labelledby="workspace-title"><h2 id="workspace-title">Workspace</h2><p>{space?.personal?'Your personal space stays private.':'Workspace details and members.'}</p>{space&&<><form className="settings-form" onSubmit={rename}><label htmlFor="workspace-name">Workspace name</label><div className="settings-input-row"><input ref={nameInput} id="workspace-name" value={name} onChange={e=>setName(e.target.value)} required maxLength={100} disabled={!owner||busy}/>{owner&&<button className="primary" disabled={busy||!name.trim()||name.trim()===space.name}>Save name</button>}</div></form><div className="workspace-icon-settings"><label>Workspace icon</label><div className="icon-options" role="group" aria-label="Workspace icon">{workspaceIcons.map(value=><button type="button" key={value} disabled={!owner||busy} className={icon===value?'selected':''} aria-label={`Use ${value} icon`} aria-pressed={icon===value} onClick={()=>setIcon(value)}>{value}</button>)}</div>{owner&&<button className="secondary" type="button" disabled={busy||icon===(space.icon??'◻')} onClick={()=>void saveIcon()}>Save icon</button>}</div><p className="settings-caption">{space.personal?'Personal workspace':owner?'You own this workspace.':'Only the owner can rename or delete this workspace.'}</p>{!space.personal&&<button className="secondary" onClick={onMembers}><Users size={16}/>Members & invitations</button>}</>}</section>
    <section className="panel settings-card"><h2>Your account</h2><p>{email}</p><form className="settings-form profile-form" onSubmit={saveProfile}><label htmlFor="display-name">Display name</label><div className="settings-input-row"><input id="display-name" value={profileName} onChange={e=>setProfileName(e.target.value)} required maxLength={80} autoComplete="nickname" disabled={busy}/><button className="primary" disabled={busy||!profileName.trim()||profileName.trim()===displayName}>Save name</button></div></form><button className="secondary" disabled={busy} onClick={()=>void signOut()}><LogOut size={16}/>Sign out</button></section>
    {space&&owner&&<section className="panel settings-card danger-zone"><h2>Delete workspace</h2>{space.personal?<p><ShieldCheck size={16}/>Your personal workspace cannot be deleted.</p>:<><p>Permanently delete <strong>{space.name}</strong> and all its tasks, events, notes, documents, lists, and invitations for everyone. This cannot be undone.</p>{!confirming?<button className="danger-button" disabled={busy} onClick={()=>{setConfirming(true);setConfirmation('');setError('');}}><Trash2 size={16}/>Delete workspace</button>:<form className="settings-form" onSubmit={deleteWorkspace}><label htmlFor="delete-confirmation">Type <strong>{space.name}</strong> to confirm</label><input autoFocus id="delete-confirmation" autoComplete="off" value={confirmation} onChange={e=>setConfirmation(e.target.value)} disabled={busy}/><div className="settings-input-row"><button type="button" className="secondary" disabled={busy} onClick={()=>{setConfirming(false);setConfirmation('');}}>Cancel</button><button className="danger-button" disabled={busy||confirmation!==space.name}>{busy?'Deleting…':'Permanently delete workspace'}</button></div></form>}</>}</section>}
    {error&&<div className="settings-error" role="alert">{error}</div>}
  </div></>;
}
