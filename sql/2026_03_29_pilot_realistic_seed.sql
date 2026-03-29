begin;

create extension if not exists pgcrypto;

create temporary table tmp_pilot_users (
  user_id uuid primary key,
  email text not null,
  password text not null,
  name text not null,
  lastname text not null,
  username text not null,
  user_type text not null,
  plan_id integer not null,
  is_verified boolean not null default false,
  city text,
  country text,
  country_id integer not null default 1,
  birthday date,
  posicion text,
  categoria text,
  player_club text,
  dominant_foot text,
  experience integer,
  altura numeric,
  peso numeric,
  scout_bio text,
  scout_phone text,
  scout_club text,
  scout_dni integer,
  club_entity_id uuid,
  club_name text,
  club_short_name text,
  club_league text,
  club_description text,
  club_site text,
  club_logo_url text
);

insert into tmp_pilot_users (
  user_id,
  email,
  password,
  name,
  lastname,
  username,
  user_type,
  plan_id,
  is_verified,
  city,
  country,
  country_id,
  birthday,
  posicion,
  categoria,
  player_club,
  dominant_foot,
  experience,
  altura,
  peso,
  scout_bio,
  scout_phone,
  scout_club,
  scout_dni,
  club_entity_id,
  club_name,
  club_short_name,
  club_league,
  club_description,
  club_site,
  club_logo_url
)
values
  (
    '11111111-1111-4111-8111-111111111101',
    'lucas.silva@futboltalent.test',
    'Piloto2026!',
    'Lucas',
    'Silva',
    'pilot_lucas_silva',
    'jugador',
    1,
    false,
    'Sao Paulo',
    'Brasil',
    1,
    date '2008-05-14',
    'Extremo derecho',
    'Sub-17',
    'Academia Norte FC',
    'derecha',
    4,
    1.73,
    66,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null
  ),
  (
    '11111111-1111-4111-8111-111111111102',
    'mateo.rojas@futboltalent.test',
    'Piloto2026!',
    'Mateo',
    'Rojas',
    'pilot_mateo_rojas',
    'jugador',
    2,
    false,
    'Buenos Aires',
    'Argentina',
    1,
    date '2006-02-09',
    'Delantero centro',
    'Sub-20',
    'Puerto Sur Club',
    'derecha',
    6,
    1.81,
    75,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null
  ),
  (
    '11111111-1111-4111-8111-111111111103',
    'thiago.pereira@futboltalent.test',
    'Piloto2026!',
    'Thiago',
    'Pereira',
    'pilot_thiago_pereira',
    'jugador',
    1,
    false,
    'Rio de Janeiro',
    'Brasil',
    1,
    date '2007-11-22',
    'Portero',
    'Sub-20',
    'Serra Azul FC',
    'derecha',
    5,
    1.86,
    79,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null
  ),
  (
    '11111111-1111-4111-8111-111111111104',
    'juan.cabrera@futboltalent.test',
    'Piloto2026!',
    'Juan',
    'Cabrera',
    'pilot_juan_cabrera',
    'jugador',
    2,
    false,
    'Montevideo',
    'Uruguay',
    1,
    date '2005-08-03',
    'Defensa central',
    'Sub-23',
    'Puerto Sur Club',
    'izquierda',
    7,
    1.84,
    78,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null
  ),
  (
    '11111111-1111-4111-8111-111111111105',
    'enzo.martins@futboltalent.test',
    'Piloto2026!',
    'Enzo',
    'Martins',
    'pilot_enzo_martins',
    'jugador',
    1,
    false,
    'Porto Alegre',
    'Brasil',
    1,
    date '2008-01-18',
    'Mediocentro',
    'Sub-17',
    'Academia Norte FC',
    'derecha',
    4,
    1.76,
    69,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null
  ),
  (
    '22222222-2222-4222-8222-222222222201',
    'sara.mendes@futboltalent.test',
    'Piloto2026!',
    'Sara',
    'Mendes',
    'pilot_sara_mendes',
    'profesional',
    2,
    true,
    'Lisboa',
    'Portugal',
    1,
    date '1991-03-04',
    'Scout senior',
    'Elite',
    null,
    null,
    null,
    null,
    null,
    'Scout internacional especializada en talento Sub-20, seguimiento de extremos y lectura de datos de rendimiento.',
    '+351910000201',
    'Rede Iberica de Scouts',
    2201201,
    null,
    null,
    null,
    null,
    null,
    null,
    null
  ),
  (
    '22222222-2222-4222-8222-222222222202',
    'bruno.costa@futboltalent.test',
    'Piloto2026!',
    'Bruno',
    'Costa',
    'pilot_bruno_costa',
    'profesional',
    2,
    true,
    'Porto',
    'Portugal',
    1,
    date '1988-09-13',
    'Analista de campo',
    'Elite',
    null,
    null,
    null,
    null,
    null,
    'Analista de captacion con foco en laterales, centrales y perfiles listos para salto internacional.',
    '+351910000202',
    'Observatorio Atlantico',
    2201202,
    null,
    null,
    null,
    null,
    null,
    null,
    null
  ),
  (
    '22222222-2222-4222-8222-222222222203',
    'nicolas.duarte@futboltalent.test',
    'Piloto2026!',
    'Nicolas',
    'Duarte',
    'pilot_nicolas_duarte',
    'profesional',
    2,
    true,
    'Montevideo',
    'Uruguay',
    1,
    date '1990-06-25',
    'Scout regional',
    'Elite',
    null,
    null,
    null,
    null,
    null,
    'Especialista en procesos de scouting para cono sur, con experiencia en evaluacion de mediocampistas y delanteros.',
    '+598940000203',
    'Plataforma Rio de la Plata',
    2201203,
    null,
    null,
    null,
    null,
    null,
    null,
    null
  ),
  (
    '22222222-2222-4222-8222-222222222204',
    'camila.rocha@futboltalent.test',
    'Piloto2026!',
    'Camila',
    'Rocha',
    'pilot_camila_rocha',
    'profesional',
    2,
    true,
    'Belo Horizonte',
    'Brasil',
    1,
    date '1992-12-11',
    'Head scout',
    'Elite',
    null,
    null,
    null,
    null,
    null,
    'Responsable de identificacion de talento juvenil, con procesos de evaluacion y seguimiento para clubes formadores.',
    '+5531990000204',
    'Rede Brasil Scout',
    2201204,
    null,
    null,
    null,
    null,
    null,
    null,
    null
  ),
  (
    '33333333-3333-4333-8333-333333333301',
    'academia.norte@futboltalent.test',
    'Piloto2026!',
    'Academia Norte',
    'FC',
    'pilot_academia_norte',
    'club',
    2,
    false,
    'Curitiba',
    'Brasil',
    1,
    date '1998-01-01',
    'Club formador',
    'Sub-20',
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    '44444444-4444-4444-8444-444444444401',
    'Academia Norte FC',
    'ANFC',
    'Liga de Desarrollo Brasil',
    'Club formador enfocado en transicion Sub-17 a Sub-23 y captacion regional.',
    'https://academianorte.test',
    null
  ),
  (
    '33333333-3333-4333-8333-333333333302',
    'puerto.sur@futboltalent.test',
    'Piloto2026!',
    'Puerto Sur',
    'Club',
    'pilot_puerto_sur',
    'club',
    2,
    false,
    'Rosario',
    'Argentina',
    1,
    date '1997-01-01',
    'Club competitivo',
    'Sub-23',
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    '44444444-4444-4444-8444-444444444402',
    'Puerto Sur Club',
    'PSC',
    'Liga Metropolitana',
    'Proyecto competitivo con foco en delanteros, defensas centrales y perfiles listos para pruebas.',
    'https://puertosur.test',
    null
  ),
  (
    '33333333-3333-4333-8333-333333333303',
    'serra.azul@futboltalent.test',
    'Piloto2026!',
    'Serra Azul',
    'FC',
    'pilot_serra_azul',
    'club',
    2,
    false,
    'Florianopolis',
    'Brasil',
    1,
    date '1999-01-01',
    'Club de desarrollo',
    'Sub-20',
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    null,
    '44444444-4444-4444-8444-444444444403',
    'Serra Azul FC',
    'SAFC',
    'Liga Sul Formativa',
    'Club de desarrollo con foco en porteros, laterales y mediocampistas.',
    'https://serraazul.test',
    null
  );

create temporary table tmp_seed_cleanup_ids as
select distinct user_id::text as user_id
from tmp_pilot_users
union
select id::text as user_id
from auth.users
where lower(coalesce(email, '')) like '%@futboltalent.test'
   or lower(coalesce(email, '')) like '%@example.com'
union
select u.user_id::text as user_id
from public.users u
where coalesce(u.is_admin, false) = false
  and (
    lower(coalesce(u.username, '')) like 'pilot_%'
    or lower(coalesce(u.name, '')) like 'piloto %'
    or lower(coalesce(u.username, '')) like 'demo_%'
  );

create temporary table tmp_seed_cleanup_clubs as
select c.id::text as club_id
from public.clubs c
where c.owner_id::text in (select user_id from tmp_seed_cleanup_ids)
union
select p.club_entity_id::text as club_id
from tmp_pilot_users p
where p.club_entity_id is not null;

delete from public.club_staff
where user_id::text in (select user_id from tmp_seed_cleanup_ids)
   or club_id::text in (select club_id from tmp_seed_cleanup_clubs);

delete from public.admin_user_feature_overrides
where user_id::text in (select user_id from tmp_seed_cleanup_ids);

delete from public.players
where id::text in (select user_id from tmp_seed_cleanup_ids);

delete from public.scouts
where id::text in (select user_id from tmp_seed_cleanup_ids);

delete from public.clubs
where id::text in (select club_id from tmp_seed_cleanup_clubs)
   or owner_id::text in (select user_id from tmp_seed_cleanup_ids);

delete from public.users
where user_id::text in (select user_id from tmp_seed_cleanup_ids);

delete from auth.identities
where user_id::text in (select user_id from tmp_seed_cleanup_ids);

delete from auth.users
where id::text in (select user_id from tmp_seed_cleanup_ids);

insert into auth.users (
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
select
  p.user_id,
  'authenticated',
  'authenticated',
  lower(p.email),
  crypt(p.password, gen_salt('bf')),
  now(),
  jsonb_build_object(
    'provider', 'email',
    'providers', jsonb_build_array('email')
  ),
  jsonb_build_object(
    'name', p.name,
    'lastname', p.lastname,
    'userType', p.user_type,
    'seed_profile', 'pilot_2026'
  ),
  now(),
  now()
from tmp_pilot_users p;

insert into auth.identities (
  provider_id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
select
  p.user_id::text,
  p.user_id,
  jsonb_build_object(
    'sub', p.user_id::text,
    'email', lower(p.email)
  ),
  'email',
  now(),
  now(),
  now()
from tmp_pilot_users p;

insert into public.users (
  user_id,
  name,
  lastname,
  username,
  "userType",
  plan_id,
  role_id,
  country_id,
  created_at,
  updated_at,
  birthday,
  city,
  country,
  pais,
  posicion,
  categoria,
  full_profile,
  is_test_account,
  verification_status,
  is_verified,
  is_admin,
  banned_until
)
select
  p.user_id,
  p.name,
  p.lastname,
  p.username,
  p.user_type,
  p.plan_id,
  case when p.user_type = 'club' then 2 else 1 end,
  p.country_id,
  now(),
  now(),
  p.birthday::timestamptz,
  p.city,
  p.country,
  p.country,
  p.posicion,
  p.categoria,
  false,
  false,
  case when p.is_verified then 'verified' else 'pending' end,
  p.is_verified,
  false,
  null
from tmp_pilot_users p;

insert into public.players (
  id,
  created_at,
  dominant_foot,
  club,
  experience,
  altura,
  peso
)
select
  p.user_id,
  now(),
  p.dominant_foot,
  p.player_club,
  p.experience,
  p.altura,
  p.peso
from tmp_pilot_users p
where p.user_type = 'jugador';

insert into public.scouts (
  id,
  created_at,
  biography,
  telephone,
  club,
  dni
)
select
  p.user_id,
  now(),
  p.scout_bio,
  coalesce(p.scout_phone, ''),
  coalesce(p.scout_club, ''),
  p.scout_dni
from tmp_pilot_users p
where p.user_type = 'profesional';

insert into public.clubs (
  id,
  owner_id,
  nombre,
  nombre_corto,
  pais,
  liga,
  descripcion,
  sitio_web,
  logo_url,
  max_staff,
  created_at,
  updated_at
)
select
  p.club_entity_id,
  p.user_id,
  p.club_name,
  p.club_short_name,
  p.country,
  p.club_league,
  p.club_description,
  p.club_site,
  p.club_logo_url,
  10,
  now(),
  now()
from tmp_pilot_users p
where p.user_type = 'club';

commit;

select
  user_type,
  email,
  password,
  name || ' ' || lastname as full_name,
  plan_id,
  is_verified
from tmp_pilot_users
order by
  case user_type
    when 'club' then 1
    when 'profesional' then 2
    else 3
  end,
  full_name;
