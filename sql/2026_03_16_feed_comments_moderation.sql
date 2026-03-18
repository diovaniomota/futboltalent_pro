begin;

alter table if exists public.comments
  add column if not exists moderation_status text;

alter table if exists public.comments
  add column if not exists moderation_reason text;

alter table if exists public.comments
  add column if not exists deleted_at timestamptz;

alter table if exists public.comments
  add column if not exists deleted_by text;

update public.comments
set moderation_status = 'approved'
where moderation_status is null
   or btrim(moderation_status) = '';

alter table if exists public.comments
  alter column moderation_status set default 'approved';

do $$
begin
  if exists (
    select 1
    from information_schema.tables
    where table_schema = 'public'
      and table_name = 'comments'
  ) and not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.comments'::regclass
      and conname = 'comments_moderation_status_check'
  ) then
    alter table public.comments
      add constraint comments_moderation_status_check
      check (
        lower(coalesce(moderation_status, 'approved')) in
          ('approved', 'flagged', 'rejected')
      );
  end if;
end $$;

create or replace function public.comment_contains_external_contact(
  p_content text
)
returns boolean
language plpgsql
immutable
as $$
declare
  normalized text := coalesce(trim(p_content), '');
begin
  if normalized = '' then
    return false;
  end if;

  return normalized ~* 'whats?\s*app'
    or normalized ~* '\binstagram\b|\binsta\b'
    or normalized ~* '\btelegram\b|\bt\.me\b'
    or normalized ~* 'https?://|www\.'
    or normalized ~* '[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}'
    or normalized ~* '@[A-Za-z0-9_.]{2,}'
    or normalized ~* '\+?\d[\d\s().-]{7,}\d'
    or normalized ~* '\b\d{7,}\b';
end;
$$;

create or replace function public.apply_comment_moderation()
returns trigger
language plpgsql
as $$
begin
  if coalesce(trim(new.content), '') = '' then
    return new;
  end if;

  if public.comment_contains_external_contact(new.content) then
    new.moderation_status := 'flagged';
    new.moderation_reason := 'external_contact';
  elsif lower(coalesce(new.moderation_status, 'approved')) not in
      ('approved', 'flagged', 'rejected') then
    new.moderation_status := 'approved';
    new.moderation_reason := null;
  elsif lower(coalesce(new.moderation_status, 'approved')) = 'approved' then
    new.moderation_reason := null;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_apply_comment_moderation on public.comments;

create trigger trg_apply_comment_moderation
before insert or update of content, moderation_status
on public.comments
for each row
execute function public.apply_comment_moderation();

create table if not exists public.comment_reports (
  id uuid primary key default gen_random_uuid(),
  comment_id text not null,
  reporter_user_id text not null,
  reason text not null default 'other',
  details text,
  created_at timestamptz not null default now()
);

create unique index if not exists comment_reports_comment_user_uidx
  on public.comment_reports (comment_id, reporter_user_id);

create index if not exists comment_reports_comment_created_idx
  on public.comment_reports (comment_id, created_at desc);

alter table public.comment_reports enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'comment_reports'
      and policyname = 'comment_reports_insert_own'
  ) then
    create policy comment_reports_insert_own
      on public.comment_reports
      for insert
      to authenticated
      with check (reporter_user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'comment_reports'
      and policyname = 'comment_reports_select_own'
  ) then
    create policy comment_reports_select_own
      on public.comment_reports
      for select
      to authenticated
      using (reporter_user_id::text = auth.uid()::text);
  end if;
end $$;

alter table public.comments enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'comments'
      and policyname = 'comments_select_visible'
  ) then
    create policy comments_select_visible
      on public.comments
      for select
      to anon, authenticated
      using (
        deleted_at is null
        and lower(coalesce(moderation_status, 'approved')) = 'approved'
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'comments'
      and policyname = 'comments_insert_own'
  ) then
    create policy comments_insert_own
      on public.comments
      for insert
      to authenticated
      with check (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'comments'
      and policyname = 'comments_update_own'
  ) then
    create policy comments_update_own
      on public.comments
      for update
      to authenticated
      using (user_id::text = auth.uid()::text)
      with check (user_id::text = auth.uid()::text);
  end if;
end $$;

drop view if exists public.comments_with_user;

create view public.comments_with_user as
select
  c.id::text as comment_id,
  c.content,
  c.created_at,
  c.video_id::text as video_id,
  c.user_id::text as user_id,
  coalesce(
    nullif(trim(concat_ws(' ', u.name, u.lastname)), ''),
    nullif(trim(u.username), ''),
    'Usuario'
  ) as user_name,
  u.lastname as user_lastname,
  u.photo_url as user_photo,
  u.username as user_username
from public.comments c
left join public.users u
  on u.user_id::text = c.user_id::text
where c.deleted_at is null
  and lower(coalesce(c.moderation_status, 'approved')) = 'approved';

grant select on public.comments_with_user to anon, authenticated;

comment on table public.comment_reports is
  'Reportes de comentarios do feed por usuário autenticado.';

comment on column public.comments.moderation_status is
  'Estado de moderação do comentário: approved, flagged o rejected.';

commit;
