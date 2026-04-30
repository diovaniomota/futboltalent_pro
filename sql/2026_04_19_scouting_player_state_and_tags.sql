-- Professional scouting metadata per player inside listas_jugadores.
-- Keeps existing flow and adds richer evaluation data.

ALTER TABLE public.listas_jugadores
ADD COLUMN IF NOT EXISTS scouting_state text;

ALTER TABLE public.listas_jugadores
ADD COLUMN IF NOT EXISTS scouting_tags jsonb;

-- Some environments have a trigger that writes NEW.updated_at on UPDATE.
-- Ensure the column exists before running backfill updates.
ALTER TABLE public.listas_jugadores
ADD COLUMN IF NOT EXISTS updated_at timestamptz;

ALTER TABLE public.listas_jugadores
ALTER COLUMN scouting_state SET DEFAULT 'descubierto';

ALTER TABLE public.listas_jugadores
ALTER COLUMN scouting_tags SET DEFAULT '[]'::jsonb;

UPDATE public.listas_jugadores
SET scouting_state = CASE COALESCE(calificacion, 1)
  WHEN 1 THEN 'descubierto'
  WHEN 2 THEN 'en_acompanamiento'
  WHEN 3 THEN 'prioridad'
  WHEN 4 THEN 'prioridad'
  WHEN 5 THEN 'descartado'
  ELSE 'descubierto'
END
WHERE scouting_state IS NULL OR btrim(scouting_state) = '';

UPDATE public.listas_jugadores
SET scouting_tags = '[]'::jsonb
WHERE scouting_tags IS NULL;

UPDATE public.listas_jugadores
SET updated_at = NOW()
WHERE updated_at IS NULL;

ALTER TABLE public.listas_jugadores
DROP CONSTRAINT IF EXISTS listas_jugadores_scouting_state_check;

ALTER TABLE public.listas_jugadores
ADD CONSTRAINT listas_jugadores_scouting_state_check
CHECK (
  scouting_state IN (
    'descubierto',
    'en_acompanamiento',
    'prioridad',
    'descartado'
  )
);
