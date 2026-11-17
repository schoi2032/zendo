import type {Item} from './workspace-types';

export function localDateKey(date:Date):string {
  return `${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
}

export function safeLink(value:string):string|null {
  try {
    const url = new URL(value.trim());
    if (!['https:', 'http:'].includes(url.protocol) || url.username || url.password) return null;
    return url.href;
  } catch { return null; }
}

export function centerItems(items:Item[],today:string){
  return {
    tasks:items.filter(i=>i.kind==='task'&&!i.done&&!!i.due_date&&i.due_date<=today)
      .sort((a,b)=>a.due_date!.localeCompare(b.due_date!)||a.title.localeCompare(b.title)),
    events:items.filter(i=>i.kind==='event'&&!!i.due_date&&i.due_date>=today)
      .sort((a,b)=>`${a.due_date}${a.event_time??''}`.localeCompare(`${b.due_date}${b.event_time??''}`)),
    pinned:items.filter(i=>i.pinned&&['task','note','document'].includes(i.kind)),
    recent:items.filter(i=>['note','document'].includes(i.kind))
      .sort((a,b)=>(b.updated_at??'').localeCompare(a.updated_at??'')),
    links:items.filter(i=>i.kind==='link'),
  };
}
