'use client';
import {useRef,useState} from 'react';
import {FileText,Plus,Search,Upload,ArrowUpRight} from 'lucide-react';
import {supabase} from '@/lib/supabase';
type Document={id:string;title:string;body:string};
export default function Documents({documents,workspaceId,onOpen,onRefresh,onNotice}:{documents:Document[];workspaceId:string;onOpen:(id?:string)=>void;onRefresh:()=>Promise<void>;onNotice:(message:string)=>void}){
  const [search,setSearch]=useState('');
  const filtered=documents.filter(d=>(d.title+' '+d.body).toLowerCase().includes(search.toLowerCase()));
  return <><div className="page-heading"><div><h1>Documents</h1><p>Create and edit documents in this workspace.</p></div><div className="document-actions"><DocumentImport workspaceId={workspaceId} onRefresh={onRefresh} onNotice={onNotice}/><button className="primary" disabled={!workspaceId} onClick={()=>onOpen()}><Plus size={16}/>New document</button></div></div><label className="search note-search"><Search size={17}/><input aria-label="Search documents" placeholder="Search documents…" value={search} onChange={e=>setSearch(e.target.value)}/></label><div className="panel document-list">{filtered.map(d=><button className="document-row" key={d.id} onClick={()=>onOpen(d.id)}><FileText size={22}/><span><strong>{d.title}</strong><small>{d.body.slice(0,150).replace(/\s+/g,' ')||'Empty document'}</small></span><ArrowUpRight size={16}/></button>)}{!filtered.length&&<div className="empty-state"><span className="empty-icon"><FileText size={26}/></span><h3>{search?'No matching documents':'No documents yet'}</h3><p>{search?'Try another search.':'Create a document or import a .txt or .md file (up to 1 MB).'}</p>{!search&&<button className="text-button" onClick={()=>onOpen()}>+ New document</button>}</div>}</div></>;
}

export function DocumentImport({workspaceId,onRefresh,onNotice}:{workspaceId:string;onRefresh:()=>Promise<void>;onNotice:(message:string)=>void}){
  const [busy,setBusy]=useState(false);
  const fileInput=useRef<HTMLInputElement>(null);
  async function importFile(file:File){
    if(!supabase||!workspaceId||busy)return;
    if(!/\.(txt|md)$/i.test(file.name)){onNotice('Choose a .txt or .md file.');return;}
    if(file.size>1024*1024){onNotice('Choose a document smaller than 1 MB.');return;}
    setBusy(true);
    try{const body=await file.text();const {error}=await supabase.from('items').insert({workspace_id:workspaceId,kind:'document',title:file.name.replace(/\.(txt|md)$/i,'').trim().slice(0,500)||'Untitled document',body}).select('id').single();if(error)throw error;await onRefresh();onNotice('Document imported.');}catch(e){onNotice(`Import failed: ${(e as {message?:string}).message??'Please try again.'}`);}finally{setBusy(false);if(fileInput.current)fileInput.current.value='';}
  }
  return <><button className="secondary" disabled={busy||!workspaceId} onClick={()=>fileInput.current?.click()}><Upload size={16}/>{busy?'Importing…':'Import text'}</button><input ref={fileInput} type="file" accept=".txt,.md,text/plain,text/markdown" hidden onChange={e=>{const file=e.target.files?.[0];if(file)void importFile(file);}}/></>;
}
