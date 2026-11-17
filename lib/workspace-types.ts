export type Item = {
  id: string;
  workspace_id: string;
  kind: 'task' | 'event' | 'note' | 'document' | 'link';
  title: string;
  body: string;
  due_date: string | null;
  event_time: string | null;
  done: boolean;
  list_id: string | null;
  assignee: string | null;
  updated_at?: string;
  pinned?: boolean;
  link_url?: string | null;
  link_group?: string;
  link_icon?: string;
};
