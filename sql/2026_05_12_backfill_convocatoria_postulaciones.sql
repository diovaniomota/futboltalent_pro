-- =====================================================================
-- FutbolTalent Pro - Crossflow candidates backfill
-- Ref QA: BUG-CLU-001 / BUG-XFL-001
--
-- Garante que candidaturas gravadas em aplicaciones_convocatoria tambem
-- existam em postulaciones, mantendo compatibilidade com paineis legados.
-- =====================================================================

begin;

alter table if exists public.postulaciones
  add column if not exists player_id text;

update public.postulaciones
set player_id = jugador_id::text
where player_id is null
  and jugador_id is not null;

insert into public.postulaciones (
  convocatoria_id,
  jugador_id,
  player_id,
  estado,
  mensaje,
  created_at,
  updated_at
)
select
  ac.convocatoria_id,
  ac.jugador_id,
  ac.jugador_id::text,
  coalesce(nullif(ac.estado, ''), 'pendiente'),
  ac.mensaje,
  coalesce(ac.created_at, now()),
  coalesce(ac.updated_at, now())
from public.aplicaciones_convocatoria ac
where not exists (
  select 1
  from public.postulaciones p
  where p.convocatoria_id = ac.convocatoria_id
    and p.jugador_id = ac.jugador_id
);

update public.postulaciones p
set
  player_id = coalesce(nullif(p.player_id, ''), p.jugador_id::text),
  estado = coalesce(nullif(p.estado, ''), nullif(ac.estado, ''), 'pendiente'),
  mensaje = coalesce(p.mensaje, ac.mensaje),
  updated_at = greatest(
    coalesce(p.updated_at, '-infinity'::timestamptz),
    coalesce(ac.updated_at, '-infinity'::timestamptz)
  )
from public.aplicaciones_convocatoria ac
where p.convocatoria_id = ac.convocatoria_id
  and p.jugador_id = ac.jugador_id;

commit;
