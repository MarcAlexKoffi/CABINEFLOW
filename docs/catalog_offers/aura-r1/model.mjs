// Model of the isolated prototype. No network, database or production credentials.
export const HEADERS = 'action,code_offre,operateur,famille,type_forfait,nom_affiche,prix_fcfa,volume_data,unite_data,minutes_appels,nombre_sms,duree_valeur,duree_unite,statut,mis_en_avant,ordre_affichage,activable_pour_tiers,canal_activation,reference_operateur,verifie_le,source_url,commentaire'.split(',');
export const FAMILIES = {ORANGE:['INTERNET','MIX','MAXIT','OZEN'],MTN:['INTERNET','MIX','CCHIC','SOCIAL'],MOOV:['INTERNET','MIX','FOLIE','MAXI_DATA']};
export const LABELS = {create:'Création',update:'Mise à jour',deactivate:'Désactivation',unchanged:'Inchangée',error:'Erreur',ACTIF:'Actif',BROUILLON:'Brouillon',INACTIF:'Inactif'};
const enums = {action:['UPSERT','DESACTIVER'],operateur:Object.keys(FAMILIES),type_forfait:['INTERNET','MIXTE','APPELS','SOCIAL'],unite_data:['','MO','GO'],duree_unite:['JOUR','HEURE','MOIS'],statut:['BROUILLON','ACTIF','INACTIF'],mis_en_avant:['OUI','NON'],activable_pour_tiers:['OUI','NON','A_VERIFIER'],canal_activation:['MANUEL','USSD','API','APP_OPERATEUR','A_VERIFIER']};
const numeric = ['prix_fcfa','volume_data','minutes_appels','nombre_sms','duree_valeur','ordre_affichage'];
export const money = value => Number(value).toLocaleString('fr-FR');
export function normalize(raw){
  const result = {_row:raw._row};
  for(const key of HEADERS){
    let value=String(raw[key]??'').trim();
    if(enums[key]||['code_offre','famille'].includes(key)) value=value.toUpperCase();
    if(numeric.includes(key)&&value!==''&&/^\d+(?:[.,]\d+)?$/.test(value)) value=String(Number(value.replace(',','.')));
    result[key]=value;
  }
  return result;
}
export function validateRow(row,existing){
  const errors=[];
  if(!row.code_offre)errors.push('code_offre obligatoire.');
  else if(!/^[A-Z0-9][A-Z0-9._-]{0,79}$/.test(row.code_offre))errors.push('Code : 80 caractères maximum, lettres, chiffres, point, tiret ou souligné.');
  if(!enums.action.includes(row.action)) errors.push('Action attendue : UPSERT ou DESACTIVER.');
  if(row.action==='DESACTIVER'){
    if(!existing) errors.push('Code inconnu : aucune offre à désactiver.');
    if(row.operateur&&existing&&row.operateur!==existing.operateur)errors.push('Collision : ce code appartient à un autre opérateur.');
    return errors;
  }
  for(const [key,values] of Object.entries(enums))if(key!=='action'&&!values.includes(row[key]))errors.push(`${key} : valeur non reconnue.`);
  if(!FAMILIES[row.operateur]?.includes(row.famille))errors.push('Famille incompatible avec cet opérateur.');
  if(existing&&row.operateur!==existing.operateur)errors.push('Collision : ce code appartient à un autre opérateur.');
  if(!row.nom_affiche||row.nom_affiche.length>120)errors.push('Nom obligatoire, limité à 120 caractères.');
  for(const key of numeric){
    const required=['prix_fcfa','duree_valeur','ordre_affichage'].includes(key);
    const value=Number(row[key]);
    if(row[key]===''&&!required)continue;
    if(row[key]===''||!Number.isFinite(value)||value<0||(['prix_fcfa','duree_valeur'].includes(key)&&value===0)||(['prix_fcfa','minutes_appels','nombre_sms','ordre_affichage'].includes(key)&&!Number.isInteger(value)))errors.push(`${key} : nombre ${['prix_fcfa','duree_valeur'].includes(key)?'strictement positif':'positif ou nul'}${key==='volume_data'?'':' et cohérent'} attendu.`);
  }
  if((row.volume_data!==''&&!row.unite_data)||(row.volume_data===''&&row.unite_data))errors.push('Le volume de données et son unité doivent être renseignés ensemble.');
  if(row.volume_data!==''&&Number(row.volume_data)===0)errors.push('Le volume de données doit être strictement positif.');
  if(row.verifie_le&&!/^\d{4}-\d{2}-\d{2}$/.test(row.verifie_le))errors.push('verifie_le : date attendue au format AAAA-MM-JJ.');
  else if(row.verifie_le){const date=new Date(`${row.verifie_le}T00:00:00Z`);if(!Number.isFinite(+date)||date.toISOString().slice(0,10)!==row.verifie_le||row.verifie_le>new Date().toISOString().slice(0,10))errors.push('Date de vérification invalide ou future.');}
  if(row.statut==='ACTIF'){
    if(row.activable_pour_tiers!=='OUI')errors.push('Publication bloquée : activation pour un tiers non confirmée.');
    if(row.canal_activation==='A_VERIFIER')errors.push('Publication bloquée : canal d’activation non confirmé.');
    if(!row.verifie_le)errors.push('Publication bloquée : date de vérification absente.');
    errors.push('Publication à valider côté serveur : délai de fraîcheur et preuve de livraison à définir. Conserver BROUILLON pour cette revue.');
  }
  for(const key of HEADERS)if(String(row[key]).length>2000)errors.push(`${key} : texte trop long (2 000 caractères maximum dans la maquette).`);
  return errors;
}
export function preview(rows,catalog){
  const normalized=rows.map(normalize), codes=new Map();
  normalized.forEach(row=>{const list=codes.get(row.code_offre)||[];list.push(row._row);codes.set(row.code_offre,list);});
  return normalized.map(row=>{
    const before=catalog.get(row.code_offre);
    const errors=validateRow(row,before);
    if(row.code_offre&&codes.get(row.code_offre).length>1)errors.unshift(`Code répété aux lignes ${codes.get(row.code_offre).join(', ')} : toutes ces lignes sont bloquées.`);
    let after=row.action==='DESACTIVER'?{...before,statut:'INACTIF'}:{...row};
    const changes=HEADERS.filter(key=>!['action','code_offre'].includes(key)&&String(before?.[key]??'')!==String(after[key]??''));
    let kind=errors.length?'error':!before?'create':!changes.length?'unchanged':row.action==='DESACTIVER'?'deactivate':'update';
    return {row,before:before?structuredClone(before):null,after,changes,kind,errors,expectedVersion:before?before._version:null};
  });
}
export function counts(entries){const result={create:0,update:0,deactivate:0,unchanged:0,error:0};entries.forEach(x=>result[x.kind]++);return result;}
export function createState(fixtures){
  const codes=['OR-DAT-001','OR-DAT-002','OR-DAT-003','MT-DAT-004','MT-CHC-001','MT-MIX-004','MO-FOL-001','MO-DAT-004'];
  const selected=codes.map(code=>fixtures.find(row=>row.code_offre===code));
  const catalog=new Map();
  selected.forEach((raw,index)=>{const row=normalize(raw);Object.assign(row,{_id:`demo-offer-${index+1}`,_version:1,_updated:Date.now()-index*3600000,_created:'2026-10-01T10:00:00Z',_history:[]});if(index%3!==2){row.statut=index===6?'INACTIF':'ACTIF';row.activable_pour_tiers='OUI';row.canal_activation='MANUEL';row.verifie_le='2026-11-15';row.commentaire='Exemple fictif pour la conception ; aucune donnée commerciale vérifiée.';}catalog.set(row.code_offre,row);});
  const sample=[...catalog.values()][2];
  return {catalog,imports:[],orders:[{id:'CMD-DEMO-001',offerId:sample._id,code:sample.code_offre,label:sample.nom_affiche,price:sample.prix_fcfa,volume:sample.volume_data,unit:sample.unite_data,fees:25,createdAt:'2026-11-14T12:30:00Z'}]};
}
export function makeBatch(entries,name){return {id:`DEMO-${crypto.randomUUID().slice(0,8).toUpperCase()}`,name,entries:structuredClone(entries),cursor:0,applied:[],conflicts:[],status:'pending',at:new Date().toISOString(),admin:'Admin · démonstration'};}
export function applyNext(state,batch,size=50){
  if(batch.status==='restored')throw new Error('Cette révision a été restaurée. Préparer un nouvel aperçu.');
  if(batch.status==='complete')return batch;
  const end=Math.min(batch.entries.length,batch.cursor+size);
  while(batch.cursor<end){
    const entry=batch.entries[batch.cursor++];
    if(entry.kind==='error'||entry.kind==='unchanged')continue;
    const current=state.catalog.get(entry.row.code_offre);
    if((current?current._version:null)!==entry.expectedVersion){batch.conflicts.push({code:entry.row.code_offre,row:entry.row._row,error:'Version modifiée depuis l’aperçu. Aucune écriture.'});continue;}
    const after={...entry.after,_id:current?current._id:`demo-${crypto.randomUUID()}`,_version:(current?current._version:0)+1,_created:current?current._created:new Date().toISOString(),_updated:Date.now(),_history:[...(current?current._history:[]),{at:new Date().toISOString(),label:`${LABELS[entry.kind]} · ${batch.id}`} ]};
    state.catalog.set(entry.row.code_offre,after);
    batch.applied.push({code:entry.row.code_offre,before:current?structuredClone(current):null,after:structuredClone(after)});
  }
  batch.status=batch.cursor===batch.entries.length?'complete':'running';
  if(!state.imports.includes(batch))state.imports.push(batch);
  return batch;
}
export function restore(state,batch){
  if(batch.status==='restored')throw new Error('Cette révision est déjà restaurée.');
  const conflicts=batch.applied.filter(x=>state.catalog.get(x.code)?._version!==x.after._version);
  if(conflicts.length)throw new Error(`Restauration bloquée : ${conflicts.map(x=>x.code).join(', ')} a été modifié depuis cet import.`);
  for(const change of batch.applied){
    // A newly created offer is retained, made inactive, and remains auditable.
    const base=change.before||{...change.after,statut:'INACTIF'};
    state.catalog.set(change.code,{...base,_version:change.after._version+1,_updated:Date.now(),_history:[...change.after._history,{at:new Date().toISOString(),label:`Restauration · ${batch.id}${change.before?'':' · création rendue inactive'}`} ]});
  }
  batch.status='restored';batch.restoredAt=new Date().toISOString();
  return batch;
}
