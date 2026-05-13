-- =====================================================================
-- FutbolTalent Pro - Player Sports Profile Validation
-- Protege altura, peso e experiencia contra valores absurdos.
-- Altura e armazenada em centimetros.
-- =====================================================================

begin;

-- Normaliza registros antigos gravados em metros, como 1.81 -> 181 cm.
update public.players
set altura = round(altura * 100, 1)
where altura is not null
  and altura >= 1
  and altura < 3;

-- Remove valores antigos fora da faixa antes de validar constraints.
update public.players
set altura = null
where altura is not null
  and (altura < 110 or altura > 230);

update public.players
set peso = null
where peso is not null
  and (peso < 25 or peso > 180);

update public.players
set experience = null
where experience is not null
  and (experience < 0 or experience > 40);

alter table public.players
  drop constraint if exists players_altura_valid,
  drop constraint if exists players_peso_valid,
  drop constraint if exists players_experience_valid;

alter table public.players
  add constraint players_altura_valid
    check (altura is null or (altura >= 110 and altura <= 230)),
  add constraint players_peso_valid
    check (peso is null or (peso >= 25 and peso <= 180)),
  add constraint players_experience_valid
    check (experience is null or (experience >= 0 and experience <= 40));

commit;
