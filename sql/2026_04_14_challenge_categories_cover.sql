alter table if exists public.challenge_categories
  add column if not exists cover_url text;

alter table if exists public.challenge_categories
  add column if not exists image_url text;
