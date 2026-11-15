// Limited, read-only XLSX reader for the browser prototype, not a server validator.
import {HEADERS} from './model.mjs';
const FILE_LIMIT=5*1024*1024, EXPANDED_LIMIT=20*1024*1024, ROW_LIMIT=5000;
const decoder=new TextDecoder();
function xml(text){const doc=new DOMParser().parseFromString(text,'application/xml');if(doc.querySelector('parsererror'))throw new Error('XML du classeur invalide.');return doc;}
function elements(root,name){return [...root.getElementsByTagNameNS('*',name)];}
function text(root){return elements(root,'t').map(x=>x.textContent).join('');}
function column(ref){let n=0;for(const ch of ref.replace(/\d+/g,''))n=n*26+ch.charCodeAt(0)-64;return n-1;}
export async function readOffers(file){
  if(!/\.xlsx$/i.test(file.name))throw new Error('Choisissez un fichier .xlsx, sans macro.');
  if(file.size>FILE_LIMIT)throw new Error('Fichier trop volumineux : maximum proposé de 5 Mo.');
  const buffer=await file.arrayBuffer(), view=new DataView(buffer), bytes=new Uint8Array(buffer);
  let eocd=-1;
  for(let i=bytes.length-22;i>=Math.max(0,bytes.length-65557);i--)if(view.getUint32(i,true)===0x06054b50){eocd=i;break;}
  if(eocd<0)throw new Error('Le fichier n’est pas un classeur XLSX lisible.');
  const count=view.getUint16(eocd+10,true), start=view.getUint32(eocd+16,true);
  if(count>2000||view.getUint16(eocd+4,true)!==0||view.getUint16(eocd+6,true)!==0)throw new Error('Structure ZIP non prise en charge.');
  let cursor=start,total=0;const entries=new Map();
  for(let i=0;i<count;i++){
    if(cursor+46>bytes.length||view.getUint32(cursor,true)!==0x02014b50)throw new Error('Archive XLSX endommagée.');
    const flags=view.getUint16(cursor+8,true),method=view.getUint16(cursor+10,true),size=view.getUint32(cursor+24,true),compressed=view.getUint32(cursor+20,true),nameLen=view.getUint16(cursor+28,true),extraLen=view.getUint16(cursor+30,true),commentLen=view.getUint16(cursor+32,true),local=view.getUint32(cursor+42,true);
    const name=decoder.decode(bytes.slice(cursor+46,cursor+46+nameLen));
    if(flags&1)throw new Error('Les classeurs chiffrés ne sont pas acceptés.');
    if(/vbaproject|macrosheet|activex/i.test(name))throw new Error('Les macros et composants actifs ne sont pas acceptés.');
    if(entries.has(name))throw new Error('Archive ambiguë : entrée ZIP répétée.');
    if(![0,8].includes(method))throw new Error('Compression du classeur non prise en charge.');
    total+=size;if(total>EXPANDED_LIMIT)throw new Error('Classeur décompressé trop volumineux (20 Mo maximum proposé).');
    entries.set(name,{local,method,size,compressed});cursor+=46+nameLen+extraLen+commentLen;
  }
  async function read(name){
    const entry=entries.get(name);if(!entry)throw new Error(`Élément XLSX absent : ${name}`);
    const offset=entry.local;
    if(offset+30>bytes.length||view.getUint32(offset,true)!==0x04034b50)throw new Error('Entrée ZIP invalide.');
    const dataStart=offset+30+view.getUint16(offset+26,true)+view.getUint16(offset+28,true);
    if(dataStart+entry.compressed>bytes.length)throw new Error('Entrée ZIP tronquée.');
    const raw=bytes.slice(dataStart,dataStart+entry.compressed);
    let result=raw;
    if(entry.method===8){
      const reader=new Blob([raw]).stream().pipeThrough(new DecompressionStream('deflate-raw')).getReader(), chunks=[];let length=0;
      try{while(true){const {done,value}=await reader.read();if(done)break;length+=value.length;if(length>entry.size||length>EXPANDED_LIMIT){await reader.cancel();throw new Error('Taille décompressée incohérente.');}chunks.push(value);}}finally{reader.releaseLock();}
      result=new Uint8Array(length);let at=0;for(const chunk of chunks){result.set(chunk,at);at+=chunk.length;}
    }
    if(result.length!==entry.size)throw new Error('Taille de l’entrée XLSX incohérente.');
    return decoder.decode(result);
  }
  const workbook=xml(await read('xl/workbook.xml'));
  if(elements(workbook,'workbookPr').some(x=>x.getAttribute('date1904')==='1'||x.getAttribute('date1904')==='true'))throw new Error('Calendrier Excel 1904 non pris en charge par cette maquette. Utiliser des dates texte AAAA-MM-JJ.');
  const sheet=elements(workbook,'sheet').find(x=>x.getAttribute('name')==='OFFRES');
  if(!sheet)throw new Error('La feuille OFFRES est absente. Les autres feuilles ne sont pas importées.');
  const rels=xml(await read('xl/_rels/workbook.xml.rels'));
  const rel=elements(rels,'Relationship').find(x=>x.getAttribute('Id')===sheet.getAttributeNS('http://schemas.openxmlformats.org/officeDocument/2006/relationships','id'));
  if(!rel||rel.getAttribute('TargetMode')==='External')throw new Error('Référence de la feuille OFFRES invalide.');
  const target=rel.getAttribute('Target'),path=target.startsWith('/')?target.slice(1):`xl/${target}`;
  if(path.includes('..'))throw new Error('Chemin XLSX non pris en charge.');
  const shared=entries.has('xl/sharedStrings.xml')?elements(xml(await read('xl/sharedStrings.xml')),'si').map(text):[];
  const sheetDoc=xml(await read(path)), parsed=[];
  const sheetRows=elements(sheetDoc,'row');
  if(sheetRows.length>ROW_LIMIT+1)throw new Error('Maximum proposé : 5 000 lignes d’offres.');
  for(const row of sheetRows){
    const values=[],cells=elements(row,'c');
    if(cells.length>256)throw new Error('Trop de colonnes dans OFFRES.');
    for(const cell of cells){
      if(elements(cell,'f').length)throw new Error(`Formule refusée dans OFFRES, cellule ${cell.getAttribute('r')}. Remplacer par une valeur.`);
      const type=cell.getAttribute('t'),raw=elements(cell,'v')[0]?.textContent??'';
      const value=type==='inlineStr'?text(cell):type==='s'?shared[Number(raw)]??'':raw;
      if(type==='e')throw new Error(`Erreur Excel dans la cellule ${cell.getAttribute('r')}.`);
      const index=column(cell.getAttribute('r')||'');if(index<0||index>255)throw new Error('Référence de cellule invalide.');
      values[index]=value;
    }
    if(values.some(x=>String(x??'').trim()))parsed.push({row:Number(row.getAttribute('r')),values});
  }
  const header=parsed.shift();
  if(!header||header.row!==1)throw new Error('Les en-têtes doivent se trouver à la ligne 1 de OFFRES.');
  const names=header.values.map(x=>String(x??'').trim());
  if(HEADERS.some(h=>names.filter(x=>x===h).length!==1)||names.some(h=>h&&!HEADERS.includes(h)))throw new Error('En-têtes non conformes : utiliser les 22 colonnes du modèle, sans doublon.');
  if(!parsed.length)throw new Error('La feuille OFFRES ne contient aucune offre.');
  const rows=parsed.map(({row,values})=>{
    const item={_row:row};HEADERS.forEach(key=>{item[key]=values[names.indexOf(key)]??'';});
    if(/^\d+(?:\.\d+)?$/.test(String(item.verifie_le))){const serial=Number(item.verifie_le);if(serial>0&&serial<100000)item.verifie_le=new Date(Date.UTC(1899,11,30)+serial*86400000).toISOString().slice(0,10);}
    return item;
  });
  return {rows,sheets:elements(workbook,'sheet').map(x=>x.getAttribute('name')),name:file.name};
}
