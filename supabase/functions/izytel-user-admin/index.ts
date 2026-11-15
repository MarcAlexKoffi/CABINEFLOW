import { cert, getApps, initializeApp } from 'npm:firebase-admin@13.4.0/app';
import { getAuth } from 'npm:firebase-admin@13.4.0/auth';
import { FieldValue, initializeFirestore } from 'npm:firebase-admin@13.4.0/firestore';
import { createClient } from 'npm:@supabase/supabase-js@2.57.4';
import { execute } from './core.mjs';

// Firebase JWT validation is performed here, not by the Supabase JWT gateway.
Deno.serve(async (request: Request) => {
  const origin = request.headers.get('origin');
  const configuredOrigins = (Deno.env.get('IZYTEL_ADMIN_ALLOWED_ORIGINS') || '')
    .split(',').map(v => v.trim()).filter(Boolean);
  const origins = configuredOrigins.length > 0 ? configuredOrigins : [
    'http://localhost:8080',
    'http://127.0.0.1:8080',
    'https://cabineflow-4bca7.web.app',
    'https://cabineflow-4bca7.firebaseapp.com',
  ];
  const headers: Record<string,string> = {'Content-Type':'application/json','Vary':'Origin'};
  if (origin && !origins.includes(origin)) return new Response(JSON.stringify({ok:false,error:'ORIGIN_DENIED'}),{status:403,headers});
  if (origin) headers['Access-Control-Allow-Origin'] = origin;
  headers['Access-Control-Allow-Headers'] = 'authorization, apikey, content-type, x-client-info';
  headers['Access-Control-Allow-Methods'] = 'POST, OPTIONS';
  const reply = (body: unknown,status=200) => new Response(JSON.stringify(body),{status,headers});
  if (request.method === 'OPTIONS') return reply({ok:true});
  if (request.method !== 'POST') return reply({ok:false,error:'METHOD_NOT_ALLOWED'},405);
  try {
    const raw = await request.text();
    if (raw.length > 16384) return reply({ok:false,error:'REQUEST_TOO_LARGE'},413);
    const bearer = /^Bearer (.+)$/.exec(request.headers.get('authorization') || '')?.[1];
    if (!bearer) return reply({ok:false,error:'AUTH_REQUIRED'},401);
    const account = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') || '{}');
    const app = getApps()[0] || initializeApp({credential:cert(account)});
    const auth = getAuth(app);
    const db = initializeFirestore(app,{preferRest:true});
    const verified = await auth.verifyIdToken(bearer,true);
    const sql = createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
    const rpc = async (name:string,params:Record<string,unknown>) => {
      const {data,error} = await sql.rpc(name,params);
      if (error) throw Error(error.message);
      return data;
    };
    const body = JSON.parse(raw);
    const result = await execute(body,verified.uid,{
      authorize:async (actor:string) => {
        const profile = (await db.doc(`users/${actor}`).get()).data();
        if (profile?.role !== 'admin' || profile?.isActive !== true) throw Error('ADMIN_REQUIRED');
        await rpc('izytel_user_admin_authorize',{p_actor:actor});
      },
      newUid:() => `izy_${body.requestId.replaceAll('-','')}`,
      checkEmail:async (email:string,uid:string) => {
        try {
          const owner = await auth.getUserByEmail(email);
          if (owner.uid !== uid) throw Error('EMAIL_ALREADY_EXISTS');
        } catch (error:any) {
          if (error.code !== 'auth/user-not-found') throw error;
        }
      },
      load:async (uid:string) => {
        const user = await auth.getUser(uid);
        const profile = (await db.doc(`users/${uid}`).get()).data();
        return {email:user.email,name:profile?.name || user.displayName,phoneNumber:profile?.phoneNumber || user.phoneNumber,
          profile:profile || null,disabled:user.disabled,createdAt:user.metadata.creationTime,lastSignInAt:user.metadata.lastSignInTime};
      },
      audit:async (uid:string) => await rpc('izytel_user_admin_history',{p_actor:verified.uid,p_uid:uid}),
      begin:async (command:Record<string,unknown>,actor:string,uid:string,before:unknown) => await rpc('izytel_user_admin_begin',{p_actor:actor,p_uid:uid,p_request_id:command.requestId,p_command:command,p_before:before}),
      deny:async (id:string) => {await rpc('izytel_user_admin_deny',{p_request_id:id});},
      sync:async (id:string,active:boolean) => {await rpc('izytel_user_admin_apply',{p_request_id:id,p_active:active});},
      createAuth:async (uid:string,c:any) => {await auth.createUser({uid,email:c.email,displayName:c.name,disabled:true});},
      disableAuth:async (uid:string) => {await auth.updateUser(uid,{disabled:true});},
      revoke:async (uid:string) => {await auth.revokeRefreshTokens(uid);},
      writeProfile:async (uid:string,c:any,before:any) => {
        // Cabiniste authorization remains exclusively SQL; no fake staff role.
        const reference = db.doc(`users/${uid}`);
        if (c.role === 'cabiniste') {
          if (before?.profile) await reference.update({role:'pending',isActive:false,adminManaged:true,updatedAt:FieldValue.serverTimestamp()});
          return;
        }
        await reference.set({schemaVersion:1,name:c.name,email:c.email,phoneNumber:c.phoneNumber,role:c.role,isActive:false,adminManaged:true,
          createdAt:before?.profile?.createdAt || FieldValue.serverTimestamp(),updatedAt:FieldValue.serverTimestamp()});
      },
      updateAuth:async (uid:string,c:any) => {await auth.updateUser(uid,{email:c.email,displayName:c.name,disabled:true});},
      activateAccess:async (uid:string,c:any) => {
        // Grant Firestore privileges only after SQL synchronization succeeded.
        await auth.updateUser(uid,{disabled:!c.isActive});
        if (c.role !== 'cabiniste') await db.doc(`users/${uid}`).update({isActive:c.isActive,updatedAt:FieldValue.serverTimestamp()});
      },
      denyProfile:async (uid:string) => {
        const reference = db.doc(`users/${uid}`);
        if ((await reference.get()).exists) await reference.update({isActive:false,adminManaged:true,updatedAt:FieldValue.serverTimestamp()});
      },
      reset:async (email:string) => await auth.generatePasswordResetLink(email),
      result:async (id:string) => {
        const {data,error}=await sql.from('izytel_user_admin_operations').select('status').eq('request_id',id).single();
        if(error)throw error;
        return data.status;
      },
      finish:async (id:string) => {await rpc('izytel_user_admin_finish',{p_request_id:id,p_error:null});},
      fail:async (id:string,error:string) => {await rpc('izytel_user_admin_finish',{p_request_id:id,p_error:error});},
    });
    return reply(result,result.ok ? 200 : 409);
  } catch (error) {
    const code = (error as {code?:string})?.code;
    if (code && ['auth/id-token-expired','auth/id-token-revoked','auth/user-disabled','auth/argument-error','auth/invalid-id-token'].includes(code)) {
      return reply({ok:false,error:'AUTH_REQUIRED'},401);
    }
    const message = error instanceof Error ? error.message : '';
    const known = /^(INVALID_[A-Z_]+|UNKNOWN_FIELD|DUPLICATE_VALUE|ZONE_REQUIRED|NETWORK_REQUIRED|ADMIN_REQUIRED|AUTH_REQUIRED|EMAIL_REQUIRED|EMAIL_ALREADY_EXISTS|SELF_ADMIN_OPERATION_FORBIDDEN|REFERENCES_NOT_VERIFIED|OPERATION_REQUIRES_REPAIR|ADMIN_OPERATION_PENDING|LAST_ADMIN|IDEMPOTENCY_CONFLICT|ZONE_OCCUPIED|ACCOUNT_CONFLICT)$/;
    return reply({ok:false,error:known.test(message) ? message : 'ADMIN_OPERATION_FAILED'},403);
  }
});
