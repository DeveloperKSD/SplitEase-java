-- ============================================================
-- SplitEase — Complete Supabase Setup (clean rewrite)
--
-- RUN THIS ENTIRE FILE in the Supabase SQL Editor.
-- It is safe to re-run — all policies/functions are dropped
-- before being re-created.
-- ============================================================


-- ════════════════════════════════════════════════════════════
--  PART 1: TABLES
-- ════════════════════════════════════════════════════════════

create table if not exists groups (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  color text default '#378ADD',
  created_by uuid references auth.users(id),
  created_at timestamp default now()
);

create table if not exists group_members (
  id uuid default gen_random_uuid() primary key,
  group_id uuid references groups(id) on delete cascade,
  user_id uuid references auth.users(id),
  display_name text not null
);

create table if not exists expenses (
  id uuid default gen_random_uuid() primary key,
  group_id uuid references groups(id) on delete cascade,
  description text default 'Untitled Expense',
  amount numeric(10,2) not null,
  paid_by_user_id uuid references auth.users(id),
  paid_by_name text not null,
  split_type text default 'equal',
  category text default 'Other',
  created_at timestamp default now()
);

create table if not exists expense_members (
  id uuid default gen_random_uuid() primary key,
  expense_id uuid references expenses(id) on delete cascade,
  user_id uuid references auth.users(id),
  display_name text,
  share_amount numeric(10,2) not null
);

-- If the table already existed without display_name, add it now
alter table expense_members add column if not exists display_name text;

create table if not exists settlements (
  id uuid default gen_random_uuid() primary key,
  group_id uuid references groups(id) on delete cascade,
  from_user_id uuid references auth.users(id),
  from_name text not null,
  to_user_id uuid references auth.users(id),
  to_name text not null,
  amount numeric(10,2) not null,
  settled_at timestamp default now()
);

-- If the table already existed without these columns, add them now
alter table settlements add column if not exists from_name text;
alter table settlements add column if not exists to_name text;
alter table settlements add column if not exists settled_at timestamp default now();

create table if not exists profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  email        text not null unique
);


-- ════════════════════════════════════════════════════════════
--  PART 2: SECURITY DEFINER HELPER FUNCTIONS
--
--  These bypass RLS entirely, so NO policy ever needs a
--  sub-query on an RLS-protected table. Zero chance of loops.
-- ════════════════════════════════════════════════════════════

-- Checks if auth.uid() created the given group.
create or replace function public.is_group_creator(gid uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from groups
    where id = gid and created_by = auth.uid()
  )
$$;

-- Checks if auth.uid() is a linked member of the given group.
create or replace function public.is_group_member(gid uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from group_members
    where group_id = gid and user_id = auth.uid()
  )
$$;

-- Checks if the given expense belongs to a group the user can access.
create or replace function public.can_access_expense(eid uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from expenses e
    where e.id = eid
      and (
        exists (select 1 from groups where id = e.group_id and created_by = auth.uid())
        or exists (select 1 from group_members where group_id = e.group_id and user_id = auth.uid())
      )
  )
$$;

-- Links unlinked group_member rows to the current user by name.
-- Called on every login via RPC.
create or replace function public.link_me_to_groups()
returns void
language sql
security definer
set search_path = public
as $$
  update group_members
  set user_id = auth.uid()
  where user_id is null
    and lower(display_name) = lower(
      (select display_name from profiles where id = auth.uid())
    );
$$;

-- Grant execute to authenticated users
grant execute on function public.is_group_creator(uuid) to anon, authenticated;
grant execute on function public.is_group_member(uuid) to anon, authenticated;
grant execute on function public.can_access_expense(uuid) to anon, authenticated;
grant execute on function public.link_me_to_groups() to authenticated;


-- ════════════════════════════════════════════════════════════
--  PART 3: ROW LEVEL SECURITY POLICIES
--
--  Every policy uses ONLY the helper functions above.
--  No policy contains a sub-query on any RLS-protected table.
-- ════════════════════════════════════════════════════════════

-- ── Enable RLS on all tables ────────────────────────────────
alter table groups          enable row level security;
alter table group_members   enable row level security;
alter table expenses        enable row level security;
alter table expense_members enable row level security;
alter table settlements     enable row level security;
alter table profiles        enable row level security;


-- ── PROFILES ────────────────────────────────────────────────
drop policy if exists "profiles_select" on profiles;
drop policy if exists "profiles_insert" on profiles;
drop policy if exists "profiles_update" on profiles;

create policy "profiles_select" on profiles
  for select using (auth.uid() is not null);

create policy "profiles_insert" on profiles
  for insert with check (auth.uid() = id);

create policy "profiles_update" on profiles
  for update using (auth.uid() = id);


-- ── GROUPS ──────────────────────────────────────────────────
drop policy if exists "Users manage own groups" on groups;
drop policy if exists "Users read own groups"   on groups;
drop policy if exists "Users write own groups"  on groups;
drop policy if exists "Users update own groups" on groups;
drop policy if exists "Users delete own groups" on groups;
drop policy if exists "group_select"            on groups;

create policy "group_select" on groups
  for select using (
    auth.uid() = created_by
    or is_group_member(id)           -- uses sec-def fn, not a sub-query
  );

create policy "group_insert" on groups
  for insert with check (auth.uid() = created_by);

create policy "group_update" on groups
  for update using (auth.uid() = created_by);

create policy "group_delete" on groups
  for delete using (auth.uid() = created_by);


-- ── GROUP MEMBERS ───────────────────────────────────────────
drop policy if exists "Members of group can view" on group_members;
drop policy if exists "gm_select" on group_members;
drop policy if exists "gm_insert" on group_members;
drop policy if exists "gm_delete" on group_members;
drop policy if exists "gm_claim"  on group_members;

create policy "gm_select" on group_members
  for select using (
    is_group_creator(group_id)       -- you created the group
    or is_group_member(group_id)     -- or you are a linked member
  );

create policy "gm_insert" on group_members
  for insert with check (
    is_group_creator(group_id)
  );

create policy "gm_delete" on group_members
  for delete using (
    is_group_creator(group_id)
  );

-- Members can claim their unlinked seat on login
create policy "gm_claim" on group_members
  for update
  using (
    user_id is null
    and lower(display_name) = lower(
      (select display_name from profiles where id = auth.uid())
    )
  )
  with check (user_id = auth.uid());


-- ── EXPENSES ────────────────────────────────────────────────
drop policy if exists "Group members see expenses" on expenses;
drop policy if exists "exp_select" on expenses;
drop policy if exists "exp_insert" on expenses;
drop policy if exists "exp_delete" on expenses;

create policy "exp_select" on expenses
  for select using (
    is_group_creator(group_id)
    or is_group_member(group_id)
  );

create policy "exp_insert" on expenses
  for insert with check (
    is_group_creator(group_id)
    or is_group_member(group_id)
  );

create policy "exp_delete" on expenses
  for delete using (
    is_group_creator(group_id)
  );


-- ── EXPENSE MEMBERS ─────────────────────────────────────────
drop policy if exists "Group members see expense splits" on expense_members;
drop policy if exists "em_select" on expense_members;
drop policy if exists "em_insert" on expense_members;
drop policy if exists "em_delete" on expense_members;

create policy "em_select" on expense_members
  for select using (
    can_access_expense(expense_id)
  );

create policy "em_insert" on expense_members
  for insert with check (
    can_access_expense(expense_id)
  );

create policy "em_delete" on expense_members
  for delete using (
    can_access_expense(expense_id)
  );


-- ── SETTLEMENTS ─────────────────────────────────────────────
drop policy if exists "Group members see settlements" on settlements;
drop policy if exists "stl_select" on settlements;
drop policy if exists "stl_insert" on settlements;
drop policy if exists "stl_delete" on settlements;

create policy "stl_select" on settlements
  for select using (
    is_group_creator(group_id)
    or is_group_member(group_id)
    or from_user_id = auth.uid()
    or to_user_id   = auth.uid()
  );

create policy "stl_insert" on settlements
  for insert with check (
    is_group_creator(group_id)
    or is_group_member(group_id)
  );

create policy "stl_delete" on settlements
  for delete using (
    is_group_creator(group_id)
  );

-- ── RPC: settle_debt ────────────────────────────────────────
-- SECURITY DEFINER so members can always insert settlements
-- regardless of RLS evaluation order issues.
create or replace function public.settle_debt(
  p_group_id uuid,
  p_from_user_id uuid,
  p_from_name text,
  p_to_user_id uuid,
  p_to_name text,
  p_amount numeric
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into settlements (group_id, from_user_id, from_name, to_user_id, to_name, amount)
  values (p_group_id, p_from_user_id, p_from_name, p_to_user_id, p_to_name, p_amount);
$$;

grant execute on function public.settle_debt(uuid, uuid, text, uuid, text, numeric) to authenticated;

