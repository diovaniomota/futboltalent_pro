-- =====================================================================
-- FutbolTalent Pro - Contact request read state
-- Permite que o badge de notificacoes do jogador conte itens nao lidos,
-- sem confundir isso com solicitacoes ainda pendentes de resposta.
-- =====================================================================

begin;

alter table if exists public.contact_requests
  add column if not exists receiver_read_at timestamptz;

create index if not exists contact_requests_receiver_unread_idx
  on public.contact_requests (to_user_id, receiver_read_at, created_at desc);

commit;
