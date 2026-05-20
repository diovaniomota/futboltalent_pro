begin;

alter table if exists public.users
  add column if not exists guardian_status text;

alter table if exists public.users
  add column if not exists visibility_status text;

alter table if exists public.guardians
  add column if not exists status text;

alter table if exists public.guardians
  add column if not exists approved_at timestamptz;

alter table if exists public.guardians
  add column if not exists approval_code text;

alter table if exists public.videos
  add column if not exists moderation_status text;

alter table if exists public.contact_requests
  add column if not exists guardian_id text;

create index if not exists guardians_approval_code_idx
  on public.guardians (approval_code);

update public.users
set guardian_status = case
  when coalesce(is_minor, false) = true and coalesce(has_guardian, false) = true
    then 'approved'
  when coalesce(is_minor, false) = true
    then 'pending'
  else 'approved'
end
where guardian_status is null;

update public.users
set visibility_status = case
  when lower(coalesce(guardian_status, 'approved')) = 'approved'
    then 'active'
  else 'limited'
end
where visibility_status is null;

update public.guardians
set status = 'approved'
where status is null;

update public.guardians
set approval_code = upper('RESP-' || right(md5(random()::text || clock_timestamp()::text), 6))
where coalesce(approval_code, '') = '';

update public.videos
set moderation_status = 'approved'
where moderation_status is null;

create or replace function public.approve_guardian_by_code(
  p_approval_code text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  guardian_row public.guardians%rowtype;
begin
  if coalesce(btrim(p_approval_code), '') = '' then
    raise exception 'approval_code_required';
  end if;

  select *
  into guardian_row
  from public.guardians
  where upper(coalesce(approval_code, '')) = upper(btrim(p_approval_code))
  order by created_at desc nulls last
  limit 1;

  if not found then
    raise exception 'approval_code_not_found';
  end if;

  update public.guardians
  set status = 'approved',
      approved_at = now()
  where id = guardian_row.id;

  update public.users
  set guardian_status = 'approved',
      visibility_status = 'active',
      has_guardian = true
  where coalesce(user_id::text, '') = guardian_row.player_id::text
     or coalesce(id::text, '') = guardian_row.player_id::text;

  update public.videos
  set moderation_status = 'approved'
  where coalesce(user_id::text, '') = guardian_row.player_id::text
    and lower(coalesce(moderation_status, 'pending')) = 'pending';

  return jsonb_build_object(
    'player_id', guardian_row.player_id,
    'guardian_id', guardian_row.id,
    'status', 'approved'
  );
end;
$$;

grant execute on function public.approve_guardian_by_code(text)
  to anon, authenticated;

commit;
