-- Add estado (state) and ciudad (city) columns to clubs table
alter table public.clubs add column if not exists estado text;
alter table public.clubs add column if not exists ciudad text;
