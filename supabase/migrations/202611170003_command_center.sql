begin;

alter table public.items add column if not exists pinned boolean not null default false;
alter table public.items add column if not exists link_url text;
alter table public.items add column if not exists link_group text not null default 'General';
alter table public.items add column if not exists link_icon text not null default '🔗';

alter table public.items drop constraint if exists items_kind_check;
alter table public.items add constraint items_kind_check check (kind in ('task','event','note','document','link'));
alter table public.items drop constraint if exists items_link_fields;
alter table public.items add constraint items_link_fields check (
  (kind <> 'link' or (link_url is not null and link_url ~ '^https?://[^[:space:]]+$' and char_length(link_url) <= 2048))
  and char_length(trim(link_group)) between 1 and 80
  and char_length(link_icon) between 1 and 32
);

-- These fields use the existing items RLS policies. Links and pins belong to
-- their workspace, so outsiders cannot read them and members may edit them.
-- No integration credentials or external calendar data are stored here.
commit;
