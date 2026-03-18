begin;

create table if not exists public.activity_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id text not null,
  recipient_user_type text,
  event_type text not null,
  title text not null,
  body text,
  entity_type text,
  entity_id text,
  action_type text not null default 'none',
  payload jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists activity_notifications_user_created_idx
  on public.activity_notifications (user_id, created_at desc);

create index if not exists activity_notifications_user_unread_idx
  on public.activity_notifications (user_id, is_read, created_at desc);

alter table public.activity_notifications enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'activity_notifications'
      and policyname = 'activity_notifications_select_own'
  ) then
    create policy activity_notifications_select_own
      on public.activity_notifications
      for select
      to authenticated
      using (user_id::text = auth.uid()::text);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'activity_notifications'
      and policyname = 'activity_notifications_update_own'
  ) then
    create policy activity_notifications_update_own
      on public.activity_notifications
      for update
      to authenticated
      using (user_id::text = auth.uid()::text)
      with check (user_id::text = auth.uid()::text);
  end if;
end $$;

create or replace function public.create_activity_notification(
  p_user_id text,
  p_recipient_user_type text default null,
  p_event_type text default 'generic',
  p_title text default '',
  p_body text default '',
  p_entity_type text default null,
  p_entity_id text default null,
  p_action_type text default 'none',
  p_payload jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  inserted_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  if coalesce(trim(p_user_id), '') = '' then
    raise exception 'p_user_id is required';
  end if;

  insert into public.activity_notifications (
    user_id,
    recipient_user_type,
    event_type,
    title,
    body,
    entity_type,
    entity_id,
    action_type,
    payload
  )
  values (
    p_user_id,
    nullif(trim(coalesce(p_recipient_user_type, '')), ''),
    coalesce(nullif(trim(coalesce(p_event_type, '')), ''), 'generic'),
    coalesce(nullif(trim(coalesce(p_title, '')), ''), 'Notificación'),
    nullif(trim(coalesce(p_body, '')), ''),
    nullif(trim(coalesce(p_entity_type, '')), ''),
    nullif(trim(coalesce(p_entity_id, '')), ''),
    coalesce(nullif(trim(coalesce(p_action_type, '')), ''), 'none'),
    coalesce(p_payload, '{}'::jsonb)
  )
  returning id into inserted_id;

  return inserted_id;
end;
$$;

grant execute on function public.create_activity_notification(
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  text,
  jsonb
) to authenticated;

comment on table public.activity_notifications is
  'Centro simples de atividade/notificações por usuário.';

comment on column public.activity_notifications.payload is
  'Dados extras de navegação e contexto da notificação.';

commit;
