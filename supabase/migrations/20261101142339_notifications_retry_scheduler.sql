-- Reveille l'outbox meme lorsqu'aucun nouvel evenement metier n'arrive.
-- Le job appelle uniquement la fonction privee qui cree le ticket nonce et
-- utilise le transport pg_net deja configure par le socle notifications.
create extension if not exists pg_cron with schema pg_catalog;

do $$
begin
  if not exists (
    select 1
    from cron.job
    where jobname = 'izytel-notification-retry-wakeup'
  ) then
    perform cron.schedule(
      'izytel-notification-retry-wakeup',
      '* * * * *',
      'select private.izytel_notification_retry_wakeup();'
    );
  end if;
end
$$;
