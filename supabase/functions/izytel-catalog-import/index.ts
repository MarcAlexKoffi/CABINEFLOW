import {createClient} from '@supabase/supabase-js';
import {maxFileBytes,readOffers} from './xlsx.ts';

// Firebase JWTs are forwarded to the Data API, which verifies their signature
// using the existing Firebase integration. No service-role key is used here.
export async function handle(request:Request):Promise<Response>{
  const origin=request.headers.get('origin');
  const origins=(Deno.env.get('IZYTEL_ADMIN_ALLOWED_ORIGINS')||'http://localhost:8080,http://127.0.0.1:8080,https://cabineflow-4bca7.web.app,https://cabineflow-4bca7.firebaseapp.com').split(',').map(v=>v.trim());
  const headers:Record<string,string>={'Content-Type':'application/json','Vary':'Origin','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS'};
  const reply=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers});
  if(origin&&!origins.includes(origin))return reply({error:'ORIGIN_DENIED'},403);
  if(origin)headers['Access-Control-Allow-Origin']=origin;
  if(request.method==='OPTIONS')return reply({ok:true});
  if(request.method!=='POST')return reply({error:'METHOD_NOT_ALLOWED'},405);
  try{
    const authorization=request.headers.get('authorization');
    if(!authorization?.startsWith('Bearer '))return reply({error:'AUTH_REQUIRED'},401);
    const sql=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
    // Authorize before spending resources on an untrusted archive.
    const access=await sql.rpc('izytel_catalog_configuration');
    if(access.error)return reply({error:'ADMIN_REQUIRED'},403);
    if(Number(request.headers.get('content-length')||0)>7200000)return reply({error:'CATALOG_FILE_TOO_LARGE'},413);
    const reader=request.body?.getReader();if(!reader)throw Error('CATALOG_REQUEST_INVALID');
    const chunks:Uint8Array[]=[];let length=0;
    try{while(true){const {done,value}=await reader.read();if(done)break;length+=value.length;if(length>7200000){await reader.cancel();throw Error('CATALOG_FILE_TOO_LARGE');}chunks.push(value);}}finally{reader.releaseLock();}
    const raw=new Uint8Array(length);let offset=0;for(const chunk of chunks){raw.set(chunk,offset);offset+=chunk.length;}
    const body=JSON.parse(new TextDecoder().decode(raw));
    if(typeof body.name!=='string'||body.name.length>160||!body.name.toLowerCase().endsWith('.xlsx')||typeof body.requestId!=='string'||!/^[a-f0-9-]{36}$/i.test(body.requestId)||typeof body.contentBase64!=='string'||body.contentBase64.length>Math.ceil(maxFileBytes/3)*4||!/^[A-Za-z0-9+/]*={0,2}$/.test(body.contentBase64))throw Error('CATALOG_REQUEST_INVALID');
    const decoded=atob(body.contentBase64),bytes=Uint8Array.from(decoded,c=>c.charCodeAt(0));
    const rows=readOffers(bytes);
    const hash=[...new Uint8Array(await crypto.subtle.digest('SHA-256',bytes))].map(byte=>byte.toString(16).padStart(2,'0')).join('');
    const prepared=await sql.rpc('izytel_catalog_import_prepare',{p_id:body.requestId,p_name:body.name,p_hash:hash,p_rows:rows});
    if(prepared.error)throw Error(prepared.error.message);
    return reply({id:prepared.data});
  }catch(error){
    const message=error instanceof Error?error.message:'';
    const safe=/^(CATALOG_[A-Z0-9_]+)(?:: [A-Z]+[0-9]+)?$/.test(message)?message:'CATALOG_FILE_INVALID';
    return reply({error:safe},safe.includes('TOO_LARGE')?413:400);
  }
}
Deno.serve(handle);
