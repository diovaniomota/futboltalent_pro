-- =====================================================================
-- FutbolTalent Pro - Notifications Spanish Localization
-- Normaliza textos legados de notificacoes visiveis para espanhol.
-- =====================================================================

begin;

create or replace function pg_temp.notification_text_es(p_text text)
returns text
language plpgsql
as $$
declare
  v text := coalesce(p_text, '');
begin
  v := replace(v, 'Notificações', 'Notificaciones');
  v := replace(v, 'notificações', 'notificaciones');
  v := replace(v, 'Notificação', 'Notificación');
  v := replace(v, 'notificação', 'notificación');
  v := replace(v, 'Solicitações', 'Solicitudes');
  v := replace(v, 'solicitações', 'solicitudes');
  v := replace(v, 'Solicitação', 'Solicitud');
  v := replace(v, 'solicitação', 'solicitud');
  v := replace(v, 'Solicitou contato em', 'Solicitó contacto el');
  v := replace(v, 'Solicitou contato', 'Solicitó contacto');
  v := replace(v, 'solicitou contato em', 'solicitó contacto el');
  v := replace(v, 'solicitou contato', 'solicitó contacto');
  v := replace(v, 'Contato', 'Contacto');
  v := replace(v, 'contato', 'contacto');
  v := replace(v, 'Aprovado', 'Aprobado');
  v := replace(v, 'aprovado', 'aprobado');
  v := replace(v, 'Aprovada', 'Aprobada');
  v := replace(v, 'aprovada', 'aprobada');
  v := replace(v, 'Recusado', 'Rechazado');
  v := replace(v, 'recusado', 'rechazado');
  v := replace(v, 'Recusada', 'Rechazada');
  v := replace(v, 'recusada', 'rechazada');
  v := replace(v, 'Pendente', 'Pendiente');
  v := replace(v, 'pendente', 'pendiente');
  v := replace(v, 'Enviada em', 'Enviada el');
  v := replace(v, 'enviada em', 'enviada el');
  v := replace(v, 'Enviado em', 'Enviado el');
  v := replace(v, 'enviado em', 'enviado el');
  v := replace(v, 'Vídeo', 'Video');
  v := replace(v, 'vídeo', 'video');
  v := replace(v, 'Usuário', 'Usuario');
  v := replace(v, 'usuário', 'usuario');
  return v;
end;
$$;

update public.activity_notifications
set
  title = coalesce(nullif(trim(pg_temp.notification_text_es(title)), ''), title),
  body = nullif(trim(pg_temp.notification_text_es(body)), '')
where coalesce(title, '') ~* '(notifica|solicita|contato|aprov|recus|pendente|enviad|vídeo|usuário)'
   or coalesce(body, '') ~* '(notifica|solicita|contato|aprov|recus|pendente|enviad|vídeo|usuário)';

commit;
