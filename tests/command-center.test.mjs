import {test} from 'node:test';
import assert from 'node:assert/strict';
import {safeLink,centerItems,localDateKey} from '../lib/command-center.ts';

test('saved links reject executable protocols, malformed URLs, and embedded credentials',()=>{
  for(const value of ['javascript:alert(1)','data:text/html,<script>alert(1)</script>','file:///etc/passwd','//example.com','example.com','https://user:password@example.com','']) assert.equal(safeLink(value),null,value);
  assert.equal(safeLink(' https://example.com/docs?q=hello#section '),'https://example.com/docs?q=hello#section');
  assert.equal(safeLink('http://localhost:3000'),'http://localhost:3000/');
});

test('today includes overdue unfinished tasks, while upcoming events omit past events',()=>{
  const items=[
    {id:'overdue',kind:'task',title:'Late',due_date:'2026-11-15',done:false},
    {id:'today',kind:'task',title:'Today',due_date:'2026-11-17',done:false},
    {id:'done',kind:'task',title:'Done',due_date:'2026-11-17',done:true},
    {id:'future',kind:'task',title:'Future',due_date:'2026-11-20',done:false},
    {id:'undated',kind:'task',title:'Undated',due_date:null,done:false},
    {id:'old',kind:'event',due_date:'2026-11-16'},
    {id:'later',kind:'event',due_date:'2026-11-17',event_time:'15:00'},
    {id:'early',kind:'event',due_date:'2026-11-17',event_time:'09:00'},
    {id:'next',kind:'event',due_date:'2026-11-18'},
    {id:'doc',kind:'document',title:'Document',due_date:'2026-11-17'},
  ];
  const result=centerItems(items,'2026-11-17');
  assert.deepEqual(result.tasks.map(i=>i.id),['overdue','today']);
  assert.deepEqual(result.events.map(i=>i.id),['early','later','next']);
  assert.equal(items[0].id,'overdue');
});

test('pins and recents include workspace work, excluding links and events',()=>{
  const result=centerItems([
    {id:'doc',kind:'document',pinned:true,updated_at:'2026-11-17T10:00:00Z'},
    {id:'note',kind:'note',pinned:false,updated_at:'2026-11-17T12:00:00Z'},
    {id:'task',kind:'task',pinned:true},
    {id:'link',kind:'link',pinned:true},
    {id:'event',kind:'event',pinned:true},
  ],'2026-11-17');
  assert.deepEqual(result.pinned.map(i=>i.id),['doc','task']);
  assert.deepEqual(result.recent.map(i=>i.id),['note','doc']);
  assert.deepEqual(result.links.map(i=>i.id),['link']);
});

test('calendar date keys use local day values with padding',()=>{
  assert.equal(localDateKey(new Date(2026,0,3,23,59)),'2026-01-03');
});
