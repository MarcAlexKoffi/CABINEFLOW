// Pure validation/orchestration: dependencies are injected for deterministic tests.
export const roles = ['admin', 'manager', 'agent', 'cabiniste'];
export function validate(input) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw Error('INVALID_REQUEST');
  const allowed = ['action','requestId','uid','name','email','phoneNumber','role','isActive','zoneIds','authorizedNetworks','reason','confirmUid'];
  if (Object.keys(input).some(k => !allowed.includes(k))) throw Error('UNKNOWN_FIELD');
  if (!['create','update','reset_password','delete','audit','details'].includes(input.action)) throw Error('INVALID_ACTION');
  if (typeof input.requestId !== 'string' || !/^[a-zA-Z0-9-]{16,80}$/.test(input.requestId)) throw Error('INVALID_REQUEST_ID');
  if (input.action !== 'create' && (typeof input.uid !== 'string' || !/^[A-Za-z0-9:_-]{1,128}$/.test(input.uid))) throw Error('INVALID_UID');
  if (input.action === 'create' && input.uid !== undefined) throw Error('INVALID_UID');
  if (['create','update'].includes(input.action)) {
    if (!roles.includes(input.role)) throw Error('INVALID_ROLE');
    if (typeof input.name !== 'string' || input.name.trim().length < 2 || input.name.length > 80) throw Error('INVALID_NAME');
    if (typeof input.email !== 'string' || input.email.length > 180 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(input.email)) throw Error('INVALID_EMAIL');
    if (typeof input.isActive !== 'boolean') throw Error('INVALID_STATUS');
    if (input.phoneNumber !== undefined && (typeof input.phoneNumber !== 'string' || input.phoneNumber.length > 30)) throw Error('INVALID_PHONE');
    for (const key of ['zoneIds','authorizedNetworks']) {
      if (!Array.isArray(input[key]) || input[key].length > 50 || input[key].some(v => typeof v !== 'string' || v.length > 160 || !v.trim())) throw Error('INVALID_' + key.toUpperCase());
      if (new Set(input[key]).size !== input[key].length) throw Error('DUPLICATE_VALUE');
    }
    if (input.authorizedNetworks.some(n => !['orange','mtn','moov'].includes(n))) throw Error('INVALID_NETWORK');
    if (input.role !== 'admin' && !input.zoneIds.length) throw Error('ZONE_REQUIRED');
    if (['agent','cabiniste'].includes(input.role) && !input.authorizedNetworks.length) throw Error('NETWORK_REQUIRED');
  }
  if (input.reason !== undefined && (typeof input.reason !== 'string' || input.reason.length > 1200)) throw Error('INVALID_REASON');
  return {...input, name:input.name?.trim(), email:input.email?.trim().toLowerCase(), phoneNumber:input.phoneNumber?.trim() ?? ''};
}

export async function execute(input, actor, d) {
  const command = validate(input);
  await d.authorize(actor);
  if (command.action === 'audit') return {ok:true,events:await d.audit(command.uid)};
  if (command.action === 'details') {
    const snapshot=await d.load(command.uid);
    return {ok:true,account:{uid:command.uid,email:snapshot.email || '',name:snapshot.name || '',phoneNumber:snapshot.phoneNumber || '',authDisabled:snapshot.disabled,createdAt:snapshot.createdAt,lastSignInAt:snapshot.lastSignInAt}};
  }
  if (command.action === 'delete') throw Error('REFERENCES_NOT_VERIFIED');
  if (command.uid === actor) throw Error('SELF_ADMIN_OPERATION_FORBIDDEN');
  const uid = command.uid || d.newUid();
  const before = command.action === 'create' ? null : await d.load(uid);
  if (before && (!before.email || typeof before.email !== 'string')) throw Error('EMAIL_REQUIRED');
  if (['create','update'].includes(command.action) && d.checkEmail) await d.checkEmail(command.email,uid);
  const operation = await d.begin(command, actor, uid, before);
  if (operation.status === 'completed') return {ok:true,uid,operationId:operation.request_id,replayed:true};
  if (!operation.fresh) throw Error('OPERATION_REQUIRES_REPAIR');
  let ownsAuth = command.action !== 'create';
  let finishStarted=false;
  let resetLink;
  try {
    if (command.action === 'reset_password') {
      resetLink = await d.reset(before.email);
      finishStarted=true;
      await d.finish(operation.request_id);
      return {ok:true,uid,operationId:operation.request_id,resetLink};
    }
    // SQL denial first; all elevated operations remain blocked until final activation.
    await d.deny(operation.request_id);
    if (command.action === 'create') { await d.createAuth(uid, command); ownsAuth=true; }
    else { await d.disableAuth(uid); await d.revoke(uid); }
    await d.writeProfile(uid, command, before);
    await d.updateAuth(uid, command);
    await d.sync(operation.request_id, command.isActive);
    await d.activateAccess(uid, command);
    finishStarted=true;
    await d.finish(operation.request_id);
    return {ok:true,uid,operationId:operation.request_id};
  } catch (error) {
    if (finishStarted) {
      try {
        if (await d.result(operation.request_id) === 'completed') return {ok:true,uid,operationId:operation.request_id,...(resetLink ? {resetLink} : {})};
      } catch {
        // Completion may already have committed. Do not undo a confirmed final
        // state based solely on a lost response; expose the uncertainty.
        return {ok:false,error:'OPERATION_RESULT_UNKNOWN',operationId:operation.request_id,requiresRepair:true};
      }
    }
    // Never report a partial mutation as success. Preserve durable reservation.
    const failures = [];
    const denials = command.action === 'reset_password' ? [] : [() => d.deny(operation.request_id), ...(ownsAuth ? [() => d.disableAuth(uid), () => d.denyProfile(uid)] : [])];
    for (const compensate of denials) {
      try { await compensate(); } catch { failures.push('DENIAL_INCOMPLETE'); }
    }
    try { await d.fail(operation.request_id, failures.length ? 'DENIAL_INCOMPLETE' : 'PARTIAL_FAILURE'); } catch { /* reservation remains pending */ }
    return {ok:false,error:'OPERATION_REQUIRES_REPAIR',operationId:operation.request_id,requiresRepair:true};
  }
}
