-- ControlDeck's own app-shortcut table.
-- Run this in the SQL Editor of a dedicated ControlDeck Supabase project.
-- Does not alter the data belonging to LifeHub, Railways, Notes, Interview, or Portfolio.

create table if not exists public.controldeck_apps (
  id text primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  description text not null default '',
  category text not null default 'Other',
  url text not null,
  admin_url text not null default '',
  icon_key text not null default 'apps',
  accent_hex bigint not null default 4284900966,
  is_favorite boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint controldeck_apps_http_url check (url = '' or url ~* '^https?://'),
  constraint controldeck_apps_admin_url check (admin_url = '' or admin_url ~* '^https?://')
);

create index if not exists controldeck_apps_owner_sort_idx
  on public.controldeck_apps (owner_id, sort_order, name);

alter table public.controldeck_apps enable row level security;

drop policy if exists "Users can read their own ControlDeck apps" on public.controldeck_apps;
create policy "Users can read their own ControlDeck apps"
  on public.controldeck_apps for select to authenticated
  using ((select auth.uid()) = owner_id);

drop policy if exists "Users can add their own ControlDeck apps" on public.controldeck_apps;
create policy "Users can add their own ControlDeck apps"
  on public.controldeck_apps for insert to authenticated
  with check ((select auth.uid()) = owner_id);

drop policy if exists "Users can update their own ControlDeck apps" on public.controldeck_apps;
create policy "Users can update their own ControlDeck apps"
  on public.controldeck_apps for update to authenticated
  using ((select auth.uid()) = owner_id)
  with check ((select auth.uid()) = owner_id);

drop policy if exists "Users can delete their own ControlDeck apps" on public.controldeck_apps;
create policy "Users can delete their own ControlDeck apps"
  on public.controldeck_apps for delete to authenticated
  using ((select auth.uid()) = owner_id);

grant select, insert, update, delete on public.controldeck_apps to authenticated;
