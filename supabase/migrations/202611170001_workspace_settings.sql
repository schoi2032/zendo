-- Owner-only operations expose just the permitted changes, not owner or privacy fields.
create function public.rename_workspace(workspace_id uuid, workspace_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  if workspace_name is null or length(trim(workspace_name)) not between 1 and 100 then
    raise exception 'Workspace name must contain 1 to 100 characters';
  end if;
  update public.workspaces set name = trim(workspace_name)
    where id = workspace_id and owner_id = auth.uid();
  if not found then raise exception 'Only the workspace owner can rename this workspace'; end if;
end;
$$;

create function public.delete_workspace(workspace_id uuid, confirmation_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Sign in required'; end if;
  delete from public.workspaces
    where id = workspace_id and owner_id = auth.uid()
      and not personal and name = confirmation_name;
  if not found then
    raise exception 'Only the owner can delete a shared workspace with its exact name';
  end if;
end;
$$;

revoke all on function public.rename_workspace(uuid, text) from public;
revoke all on function public.delete_workspace(uuid, text) from public;
grant execute on function public.rename_workspace(uuid, text) to authenticated;
grant execute on function public.delete_workspace(uuid, text) to authenticated;
