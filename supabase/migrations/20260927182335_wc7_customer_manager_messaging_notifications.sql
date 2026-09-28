-- IzyTel WC7 - notifications temps reel Client <-> Manager
-- Le message metier reste prioritaire : un echec de notification ne doit jamais
-- annuler l'envoi d'un message.

create or replace function private.izytel_wc7_customer_message_notification_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_conversation public.customer_conversations;
  v_recipient_uid text;
  v_recipient record;
  v_title text;
  v_body text;
  v_type text;
  v_data jsonb;
  v_preview text := left(regexp_replace(btrim(coalesce(new.body, '')), '\s+', ' ', 'g'), 180);
begin
  begin
    if new.sender_type not in ('client', 'manager') then
      return new;
    end if;

    select *
      into v_conversation
    from public.customer_conversations c
    where c.id = new.conversation_id
    limit 1;

    if not found then
      return new;
    end if;

    if new.sender_type = 'client' then
      v_type := 'customer_message_new';
      v_title := 'Nouveau message client';
      v_body := case
        when nullif(btrim(coalesce(v_conversation.order_reference, '')), '') is not null
          then coalesce(nullif(btrim(v_conversation.customer_name), ''), 'Un client')
               || ' · ' || v_conversation.order_reference || ' : ' || v_preview
        else coalesce(nullif(btrim(v_conversation.customer_name), ''), 'Un client')
             || ' : ' || v_preview
      end;

      v_recipient_uid := nullif(btrim(coalesce(v_conversation.assigned_manager_uid, '')), '');
      if v_recipient_uid is null and v_conversation.zone_id is not null then
        select nullif(btrim(z.manager_id), '')
          into v_recipient_uid
        from public.territory_zones z
        where z.id = v_conversation.zone_id
          and z.is_active = true
        limit 1;
      end if;

      v_data := jsonb_strip_nulls(jsonb_build_object(
        'type', v_type,
        'route', 'customer_messaging',
        'conversationId', v_conversation.id,
        'zoneId', v_conversation.zone_id,
        'orderId', v_conversation.order_id,
        'orderReference', v_conversation.order_reference,
        'senderName', coalesce(nullif(btrim(new.sender_name), ''), v_conversation.customer_name, 'Client')
      ));

      if v_recipient_uid is not null then
        perform private.enqueue_izytel_notification(
          v_recipient_uid,
          v_type,
          v_title,
          v_body,
          v_data,
          'message:' || new.id || ':manager:' || v_recipient_uid
        );
      else
        -- Si une zone n'a exceptionnellement aucun Manager, on alerte les
        -- administrateurs actifs afin qu'aucune demande client ne reste muette.
        for v_recipient in
          select s.firebase_uid
          from public.izytel_staff_access s
          where s.is_active = true
            and s.role = 'admin'
        loop
          perform private.enqueue_izytel_notification(
            v_recipient.firebase_uid,
            v_type,
            v_title,
            v_body,
            v_data,
            'message:' || new.id || ':admin:' || v_recipient.firebase_uid
          );
        end loop;
      end if;

      return new;
    end if;

    -- Reponse Manager -> Client. Le Web client n'a pas encore de token FCM
    -- en arriere-plan, mais l'evenement est mis dans le meme pipeline afin que
    -- tout appareil client enregistre le recoive automatiquement. L'interface
    -- Web ouverte est aussi notifiee via Realtime cote Flutter.
    v_recipient_uid := nullif(btrim(coalesce(v_conversation.customer_auth_uid, '')), '');
    if v_recipient_uid is null then return new; end if;

    v_type := 'manager_message_new';
    v_title := 'IzyTel vous a repondu';
    v_body := v_preview;
    v_data := jsonb_strip_nulls(jsonb_build_object(
      'type', v_type,
      'route', 'customer_messaging',
      'conversationId', v_conversation.id,
      'zoneId', v_conversation.zone_id,
      'orderId', v_conversation.order_id,
      'orderReference', v_conversation.order_reference,
      'senderName', coalesce(nullif(btrim(new.sender_name), ''), 'Manager IzyTel')
    ));

    perform private.enqueue_izytel_notification(
      v_recipient_uid,
      v_type,
      v_title,
      v_body,
      v_data,
      'message:' || new.id || ':client:' || v_recipient_uid
    );
  exception when others then
    raise warning '[IzyTel Messaging Notifications] %', sqlerrm;
  end;

  return new;
end;
$function$;

revoke all on function private.izytel_wc7_customer_message_notification_trigger()
  from public, anon, authenticated;

drop trigger if exists trg_wc7_customer_message_notification
  on public.customer_messages;
create trigger trg_wc7_customer_message_notification
after insert on public.customer_messages
for each row execute function private.izytel_wc7_customer_message_notification_trigger();
