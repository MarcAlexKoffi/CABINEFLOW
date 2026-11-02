-- Local preparation only. Keep the existing FCM/outbox pipeline.
alter table public.izytel_notification_outbox add column if not exists next_attempt_at timestamptz not null default now();
create table public.izytel_notification_deliveries (
  outbox_id uuid not null references public.izytel_notification_outbox(id) on delete cascade,
  device_id uuid not null references public.izytel_notification_devices(id) on delete cascade,
  status text not null check(status in ('sent','failed','invalid')),
  last_error text, updated_at timestamptz not null default now(),
  primary key(outbox_id,device_id)
);
alter table public.izytel_notification_deliveries enable row level security;
revoke all on public.izytel_notification_deliveries from public,anon,authenticated;
grant all on public.izytel_notification_deliveries to service_role;

create function private.izytel_notification_zone_recipients(p_zone text)
returns setof text language sql stable security definer set search_path='' as $$
  with managers as (
    select s.firebase_uid from public.territory_zones z
    join public.izytel_staff_access s on s.firebase_uid=z.manager_id
    where z.id=p_zone and z.is_active and s.is_active and s.role in ('manager','supervisor')
  )
  select firebase_uid from managers
  union all
  select firebase_uid from public.izytel_staff_access
  where is_active and role='admin' and not exists(select 1 from managers);
$$;
revoke all on function private.izytel_notification_zone_recipients(text) from public,anon,authenticated;

-- Reuse the existing, RLS-protected customer messaging inbox for Web delivery.
-- The outbox unique event key is the durable idempotency boundary: this AFTER
-- INSERT projection runs once, in the same transaction, never on dispatch retry.
create function private.izytel_notification_customer_message() returns trigger
language plpgsql security definer set search_path='' as $$
declare reference text;
begin
  select o.order_reference into reference from public.phase4_assignment_orders o
    where o.order_id=new.data->>'orderId' limit 1;
  if nullif(reference,'') is null then
    raise exception 'NOTIFICATION_ORDER_REFERENCE_REQUIRED';
  end if;
  perform private.izytel_wc5_emit_customer_system_message(new.data->>'orderId',reference,new.body);
  return new;
end; $$;
revoke all on function private.izytel_notification_customer_message() from public,anon,authenticated;
create trigger izytel_notification_customer_message after insert on public.izytel_notification_outbox
for each row when (new.event_type in ('payment_confirmed','refund_completed','support_in_progress','support_resolved'))
execute function private.izytel_notification_customer_message();

create or replace function public.izytel_claim_notification_batch(p_limit integer default 25)
returns setof public.izytel_notification_outbox language plpgsql security definer set search_path='' as $$
begin
  update public.izytel_notification_outbox set status='failed',last_error='RETRY_EXHAUSTED',updated_at=now()
    where status in ('pending','processing') and attempt_count>=5
      and (status='pending' or claimed_at<now()-interval '10 minutes');
  return query with picked as (
    select id from public.izytel_notification_outbox
    where attempt_count<5 and ((status='pending' and next_attempt_at<=now())
      or (status='processing' and claimed_at<now()-interval '10 minutes'))
    order by created_at for update skip locked limit greatest(1,least(coalesce(p_limit,25),50))
  ) update public.izytel_notification_outbox o
    set status='processing',attempt_count=o.attempt_count+1,claimed_at=now(),updated_at=now()
    from picked where o.id=picked.id returning o.*;
end; $$;
revoke all on function public.izytel_claim_notification_batch(integer) from public,anon,authenticated;
grant execute on function public.izytel_claim_notification_batch(integer) to service_role;

create or replace function private.izytel_phase4_notification_trigger()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_changed boolean := false;
  v_is_reassignment boolean := false;
  v_type text;
  v_title text;
  v_body text;
  v_staff record;
begin
  begin
    if tg_op = 'INSERT' then
      v_changed := true;
    else
      v_changed := old.assignment_state is distinct from new.assignment_state
        or old.assigned_agent_id is distinct from new.assigned_agent_id
        or old.assigned_at is distinct from new.assigned_at;
    end if;

    if new.assignment_state = 'assigned'
       and nullif(btrim(coalesce(new.assigned_agent_id, '')), '') is not null
       and v_changed then
      v_is_reassignment := new.last_refused_agent_id is not null;
      if tg_op = 'UPDATE' and old.assigned_agent_id is distinct from new.assigned_agent_id then
        v_is_reassignment := true;
      end if;
      v_type := case when v_is_reassignment then 'order_reassigned' else 'order_assigned' end;
      v_title := case when v_is_reassignment then 'Commande reaffectee' else 'Nouvelle commande' end;
      v_body := new.order_reference || ' - ' || upper(coalesce(new.network, '')) ||
        ' - ' || new.amount::text || ' F';

      perform private.enqueue_izytel_notification(
        new.assigned_agent_id,
        v_type,
        v_title,
        v_body,
        jsonb_build_object(
          'type', v_type,
          'orderId', new.order_id,
          'orderReference', new.order_reference,
          'route', 'order_detail',
          'assignmentMode', coalesce(new.assignment_mode, 'automatic')
        ),
        'order:' || new.order_id || ':assigned:' || new.assigned_agent_id || ':' ||
          coalesce(extract(epoch from new.assigned_at)::text, extract(epoch from new.updated_at)::text)
      );
    end if;

    if new.assignment_state = 'manual_required' then
      if tg_op = 'INSERT' then
        v_changed := true;
      else
        v_changed := old.assignment_state is distinct from 'manual_required';
      end if;
      if v_changed then
        v_body := new.order_reference || ' - ' || upper(coalesce(new.network, '')) ||
          ' - ' || new.amount::text || ' F';
        for v_staff in
          select s.firebase_uid
          from public.izytel_staff_access s
          where s.firebase_uid in (select private.izytel_notification_zone_recipients(new.zone_id))
        loop
          perform private.enqueue_izytel_notification(
            v_staff.firebase_uid,
            'order_manual_required',
            'Affectation manuelle requise',
            v_body,
            jsonb_build_object(
              'type', 'order_manual_required',
              'orderId', new.order_id,
              'orderReference', new.order_reference,
              'route', 'order_detail'
            ),
            'order:' || new.order_id || ':manual:' || v_staff.firebase_uid || ':' ||
              extract(epoch from new.updated_at)::text
          );
        end loop;
      end if;
    end if;
  exception when others then
    raise warning '[IzyTel Notifications][phase4] %', sqlerrm;
  end;
  return new;
end;
$$;
create or replace function private.izytel_agent_issue_notification_trigger()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_staff record;
  v_label text;
begin
  begin
    if tg_op = 'INSERT' then
      v_label := coalesce(nullif(btrim(new.type), ''), 'Signalement agent');
      for v_staff in
        select s.firebase_uid
        from public.izytel_staff_access s
        where s.firebase_uid in (
            select private.izytel_notification_zone_recipients(scoped.zone_id)
            from (
              select unnest(a.zone_ids) zone_id from public.phase5_agent_capacities a where a.agent_id=new.agent_id
              union all select null::text where not exists(select 1 from public.phase5_agent_capacities a where a.agent_id=new.agent_id and cardinality(a.zone_ids)>0)
            ) scoped
          )
      loop
        perform private.enqueue_izytel_notification(
          v_staff.firebase_uid,
          'agent_issue_new',
          'Nouveau signalement agent',
          v_label,
          jsonb_build_object(
            'type', 'agent_issue_new',
            'issueId', new.id::text,
            'route', 'agent_issues'
          ),
          'issue:' || new.id::text || ':new:' || v_staff.firebase_uid
        );
      end loop;
    elsif tg_op = 'UPDATE'
      and new.status = 'resolved'
      and old.status is distinct from 'resolved' then
      perform private.enqueue_izytel_notification(
        new.agent_id,
        'agent_issue_resolved',
        'Signalement resolu',
        'Ton signalement IzyTel a ete resolu.',
        jsonb_build_object(
          'type', 'agent_issue_resolved',
          'issueId', new.id::text,
          'route', 'agent_issues'
        ),
        'issue:' || new.id::text || ':resolved'
      );
    end if;
  exception when others then
    raise warning '[IzyTel Notifications][issues] %', sqlerrm;
  end;
  return new;
end;
$$;

-- Server transitions, not UI clicks, create durable customer events.
create function private.izytel_notification_business_trigger() returns trigger
language plpgsql security definer set search_path='' as $$
declare v jsonb:=to_jsonb(new); previous jsonb; event text; recipient text; zone text; target record;
begin
  if tg_op='UPDATE' then previous:=to_jsonb(old); end if;
  if tg_table_name='phase4_assignment_orders' then
    if (v->>'assigned_cabiniste_id') is distinct from (previous->>'assigned_cabiniste_id') and nullif(v->>'assigned_cabiniste_id','') is not null then
      select p.firebase_uid into recipient from public.partner_accounts p where p.id::text=v->>'assigned_cabiniste_id' and p.status='active' limit 1;
      perform private.enqueue_izytel_notification(recipient,'order_assigned','Nouvelle commande','Une commande vous a été confiée.',jsonb_build_object('type','order_assigned','orderId',v->>'order_id','orderReference',v->>'order_reference','route','order_detail'),'partner_assigned:'||(v->>'order_id')||':'||(v->>'assigned_cabiniste_id')||':'||coalesce(v->>'assigned_at',v->>'updated_at'));
    end if;
    if tg_op='UPDATE' and old.assigned_agent_id is distinct from new.assigned_agent_id and old.assigned_agent_id is not null then
      perform private.enqueue_izytel_notification(old.assigned_agent_id,'order_withdrawn','Affectation mise à jour','Une commande a été retirée de votre file.',jsonb_build_object('type','order_withdrawn','route','order_detail','orderId',new.order_id,'orderReference',new.order_reference),
        'withdrawn:'||new.order_id||':'||old.assigned_agent_id||':'||new.updated_at::text);
    end if;
    if tg_op<>'UPDATE' then return new; end if;
    if previous->>'payment_status' is distinct from v->>'payment_status' and v->>'payment_status'='confirmed' then
      perform private.enqueue_izytel_notification(v->>'customer_auth_uid','payment_confirmed','Paiement pris en compte','Votre paiement a été pris en compte.',jsonb_build_object('type','payment_confirmed','orderId',v->>'order_id','route','order_detail'),'payment_confirmed:'||(v->>'order_id'));
    end if;
    event:=case when previous->>'order_status' is distinct from v->>'order_status' and v->>'order_status'='completed' then 'order_completed'
      when previous->>'order_status' is distinct from v->>'order_status' and v->>'order_status'='failed' then 'order_failed_review' else null end;
    if event is null then return new; end if;
    if event='order_failed_review' then
      for target in select private.izytel_notification_zone_recipients(v->>'zone_id') uid loop
        perform private.enqueue_izytel_notification(target.uid,event,'Commande en échec','Une commande nécessite votre analyse.',jsonb_build_object('type',event,'orderId',v->>'order_id','orderReference',v->>'order_reference','route','order_detail'),'failed:'||(v->>'order_id')||':'||target.uid||':'||(v->>'updated_at'));
      end loop;
      return new;
    end if;
    recipient:=v->>'customer_auth_uid';
  elsif tg_table_name='refunds' then
    if v->>'status'<>'refunded' or (tg_op='UPDATE' and previous->>'status'='refunded') then return new; end if;
    event:='refund_completed'; recipient:=v->>'customer_auth_uid';
  else
    if tg_op='UPDATE' then
      if previous->>'status' is not distinct from v->>'status' then return new; end if;
      event:=case v->>'status' when 'inProgress' then 'support_in_progress' when 'resolved' then 'support_resolved' else null end;
      if event is null then return new; end if;
      perform private.enqueue_izytel_notification(v->>'customer_auth_uid',event,'Votre demande IzyTel',case event when 'support_in_progress' then 'Votre demande est prise en charge.' else 'Votre demande a été traitée. Consultez la messagerie IzyTel.' end,
        jsonb_build_object('type',event,'orderId',v->>'order_id','supportRequestId',v->>'id','route','order_detail'),event||':'||(v->>'id'));
      return new;
    end if;
    select o.zone_id into zone from public.phase4_assignment_orders o where o.order_id=v->>'order_id' limit 1;
    for target in select private.izytel_notification_zone_recipients(zone) uid loop
      perform private.enqueue_izytel_notification(target.uid,'support_request_new','Nouvelle demande client','Une demande client nécessite votre attention.',jsonb_build_object('type','support_request_new','orderId',v->>'order_id','orderReference',v->>'order_reference','supportRequestId',v->>'id','route','order_detail'),'support:'||(v->>'id')||':'||target.uid);
    end loop;
    return new;
  end if;
  perform private.enqueue_izytel_notification(recipient,event,'Mise à jour IzyTel',case event when 'refund_completed' then 'Votre remboursement a été effectué.' else 'Votre commande a été réalisée avec succès.' end,
    jsonb_build_object('type',event,'orderId',v->>'order_id','orderReference',v->>'order_reference','route','order_detail'),event||':'||(v->>'order_id'));
  return new;
end; $$;
revoke all on function private.izytel_notification_business_trigger() from public,anon,authenticated;
create trigger izytel_business_order_notification after insert or update on public.phase4_assignment_orders for each row execute function private.izytel_notification_business_trigger();
create trigger izytel_business_refund_notification after insert or update on public.refunds for each row execute function private.izytel_notification_business_trigger();
create trigger izytel_business_support_notification after insert or update on public.support_requests for each row execute function private.izytel_notification_business_trigger();

create or replace function private.izytel_notification_retry_wakeup()
returns void
language plpgsql
security definer
set search_path to ''
as $$
declare ticket record;
begin
  select id,dispatch_nonce into ticket from public.izytel_notification_outbox
  where (status='pending' and next_attempt_at<=now())
    or (status='processing' and claimed_at<now()-interval '10 minutes')
  order by created_at limit 1;
  if not found then return; end if;
  begin
    perform net.http_post(
      url := 'https://zrxeztxaxnzxevjuhzcc.supabase.co/functions/v1/izytel-notification-dispatch',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', 'sb_publishable_6i0SKdOpBIAdTJj-TdepsA_LyB9dGeX'
      ),
      body := jsonb_build_object(
        'outboxId', ticket.id::text,
        'nonce', ticket.dispatch_nonce::text
      ),
      timeout_milliseconds := 4000
    );
  exception when others then
    -- L'echec du webhook n'annule jamais l'evenement metier qui a cree l'outbox.
    raise warning '[IzyTel Notifications][dispatch] %', sqlerrm;
  end;
  return;
end;
$$;
revoke all on function private.izytel_notification_retry_wakeup() from public,anon,authenticated;
-- Do not install extensions automatically. If pg_cron is unavailable, enable it
-- during the authorized deployment, then schedule this same private function.
do $$ begin
  if exists(select 1 from pg_extension where extname='pg_cron') then
    execute $job$select cron.schedule('izytel-notification-retry','* * * * *','select private.izytel_notification_retry_wakeup()')$job$;
  else
    raise notice 'Notifications: pg_cron unavailable; recurring retry wakeup must be configured before production acceptance';
  end if;
end $$;
