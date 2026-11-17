begin;

alter table public.workspaces add column if not exists icon text not null default '◻';
alter table public.workspaces add constraint workspace_icon_length check (char_length(icon) between 1 and 32);

create or replace function public.set_workspace_icon(workspace_id uuid, workspace_icon text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if workspace_icon is null or char_length(trim(workspace_icon)) not between 1 and 32 then
    raise exception 'Choose a workspace icon';
  end if;
  update public.workspaces set icon = trim(workspace_icon)
    where id = workspace_id and owner_id = auth.uid();
  if not found then raise exception 'Only the owner can change this workspace icon'; end if;
end;
$$;
revoke all on function public.set_workspace_icon(uuid, text) from public;
grant execute on function public.set_workspace_icon(uuid, text) to authenticated;

-- Documents inherit the same workspace membership policies as tasks and notes.
alter table public.items drop constraint items_kind_check;
alter table public.items add constraint items_kind_check check (kind in ('task', 'event', 'note', 'document'));

commit;
