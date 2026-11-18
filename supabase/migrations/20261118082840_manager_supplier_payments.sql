-- Managers may settle only their own suppliers; no financial row is changed by
-- installing this function. Existing Admin, balance and history checks remain.
CREATE OR REPLACE FUNCTION private.phase5_record_supplier_payment(p_supplier_id text, p_amount bigint, p_channel text, p_reference text, p_note text, p_staff_name text, p_legacy_id text DEFAULT NULL::text, p_operation_key text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid text := (select auth.jwt()->>'sub');
  v_account public.phase5_supplier_accounts;
  v_supplier public.finance_suppliers;
  v_existing public.phase5_supplier_payments;
  v_id uuid := gen_random_uuid();
  v_now timestamptz := now();
  v_reference text := upper(btrim(coalesce(p_reference,'')));
begin
  if not public.is_izytel_firebase_jwt() or v_uid is null then raise exception 'AUTH_REQUIRED' using errcode='42501'; end if;
  if not private.is_izytel_finance_admin() then
    if private.izytel_current_staff_role() is distinct from 'manager' or not private.izytel_manager_owns_supplier(p_supplier_id) then
      raise exception 'SUPPLIER_SCOPE_DENIED' using errcode='42501';
    end if;
    if nullif(btrim(coalesce(p_legacy_id,'')),'') is not null then raise exception 'ADMIN_REQUIRED' using errcode='42501'; end if;
    p_staff_name := coalesce(nullif((select display_name from public.manager_profiles where firebase_uid=v_uid),''),'Manager');
  end if;
  if p_amount is null or p_amount <= 0 then raise exception 'INVALID_AMOUNT'; end if;
  if p_channel is null or p_channel not in ('wave','cash','bank','other') then raise exception 'INVALID_CHANNEL'; end if;
  if char_length(v_reference) < 3 or char_length(v_reference) > 120 then raise exception 'INVALID_REFERENCE'; end if;

  select * into v_supplier from public.finance_suppliers
  where id=btrim(p_supplier_id) and is_deleted=false;
  if not found then raise exception 'SUPPLIER_NOT_FOUND'; end if;

  -- Serialize payments on one supplier before checking duplicate references.
  -- The same intent must never credit an unrelated supplier or a different amount.
  select * into v_account from public.phase5_supplier_accounts
  where supplier_id=v_supplier.id for update;
  if not found then raise exception 'SUPPLIER_ACCOUNT_NOT_FOUND'; end if;
  if p_operation_key is not null then
    select * into v_existing from public.phase5_supplier_payments
    where operation_key=btrim(p_operation_key);
    if found then
      if v_existing.supplier_id<>v_supplier.id or v_existing.amount<>p_amount or
         v_existing.payment_channel<>p_channel or v_existing.payment_reference<>v_reference then
        raise exception 'DUPLICATE_REFERENCE';
      end if;
      return v_existing.id::text;
    end if;
  end if;
  if p_legacy_id is not null then
    select * into v_existing from public.phase5_supplier_payments
    where source_firestore_id=btrim(p_legacy_id);
    if found then return v_existing.id::text; end if;
  end if;

  select * into v_existing from public.phase5_supplier_payments
  where supplier_id=v_supplier.id and payment_reference=v_reference;
  if found then
    if v_existing.amount=p_amount and v_existing.payment_channel=p_channel then
      return v_existing.id::text;
    end if;
    raise exception 'DUPLICATE_REFERENCE';
  end if;

  if p_amount > v_account.total_owed-v_account.total_paid then raise exception 'PAYMENT_EXCEEDS_BALANCE'; end if;

  insert into public.phase5_supplier_payments(
    id,source_firestore_id,operation_key,supplier_id,supplier_name,amount,
    payment_channel,payment_reference,note,paid_at,created_by_uid,created_by_name,created_at
  ) values (
    v_id,nullif(btrim(coalesce(p_legacy_id,'')),''),
    coalesce(nullif(btrim(coalesce(p_operation_key,'')),''),'payment:'||v_id::text),
    v_supplier.id,v_supplier.name,p_amount,p_channel,v_reference,
    nullif(btrim(coalesce(p_note,'')),''),v_now,v_uid,nullif(btrim(p_staff_name),''),v_now
  );

  update public.phase5_supplier_accounts
  set total_paid=total_paid+p_amount,last_payment_id=v_id,updated_at=v_now
  where supplier_id=v_supplier.id;
  return v_id::text;
end; $function$
