-- This script fixes the Row Level Security (RLS) policies for the club applications tables.
-- Clubs need to be able to SELECT applications made to their convocatorias.

BEGIN;

-- 1. Fix RLS for aplicaciones_convocatoria
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'aplicaciones_convocatoria'
  ) THEN
    ALTER TABLE public.aplicaciones_convocatoria ADD COLUMN IF NOT EXISTS player_id text;
    UPDATE public.aplicaciones_convocatoria
    SET player_id = jugador_id::text
    WHERE player_id IS NULL AND jugador_id IS NOT NULL;

    -- Drop the existing policy if it exists
    DROP POLICY IF EXISTS "Clubs can view applications to their convocatorias" ON public.aplicaciones_convocatoria;
    
    -- Create the new policy
    CREATE POLICY "Clubs can view applications to their convocatorias" 
    ON public.aplicaciones_convocatoria 
    FOR SELECT 
    TO authenticated 
    USING (
      COALESCE(jugador_id::text, player_id::text) = auth.uid()::text 
      OR EXISTS (
        SELECT 1 FROM public.convocatorias c
        LEFT JOIN public.clubs cl ON cl.id::text = c.club_id::text
        LEFT JOIN public.club_staff cs ON cs.club_id::text = cl.id::text AND cs.user_id::text = auth.uid()::text
        WHERE c.id::text = aplicaciones_convocatoria.convocatoria_id::text
        AND (
          c.club_id::text = auth.uid()::text 
          OR cl.owner_id::text = auth.uid()::text 
          OR cs.user_id::text = auth.uid()::text
        )
      )
    );
  END IF;
END $$;

-- 2. Fix RLS for postulaciones
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'postulaciones'
  ) THEN
    ALTER TABLE public.postulaciones ADD COLUMN IF NOT EXISTS player_id text;
    UPDATE public.postulaciones
    SET player_id = jugador_id::text
    WHERE player_id IS NULL AND jugador_id IS NOT NULL;

    -- Drop the existing policy if it exists
    DROP POLICY IF EXISTS "Clubs can view postulaciones to their convocatorias" ON public.postulaciones;
    
    -- Create the new policy
    CREATE POLICY "Clubs can view postulaciones to their convocatorias" 
    ON public.postulaciones 
    FOR SELECT 
    TO authenticated 
    USING (
      COALESCE(jugador_id::text, player_id::text) = auth.uid()::text
      OR EXISTS (
        SELECT 1 FROM public.convocatorias c
        LEFT JOIN public.clubs cl ON cl.id::text = c.club_id::text
        LEFT JOIN public.club_staff cs ON cs.club_id::text = cl.id::text AND cs.user_id::text = auth.uid()::text
        WHERE c.id::text = postulaciones.convocatoria_id::text
        AND (
          c.club_id::text = auth.uid()::text 
          OR cl.owner_id::text = auth.uid()::text 
          OR cs.user_id::text = auth.uid()::text
        )
      )
    );
  END IF;
END $$;

-- 3. Fix RLS for users (if clubs can't see players)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users'
  ) THEN
    DROP POLICY IF EXISTS "Users are viewable by everyone" ON public.users;
    CREATE POLICY "Users are viewable by everyone" 
    ON public.users 
    FOR SELECT 
    TO authenticated 
    USING (true);
  END IF;
END $$;

COMMIT;
