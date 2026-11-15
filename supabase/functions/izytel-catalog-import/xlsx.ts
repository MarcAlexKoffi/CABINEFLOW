import { Inflate } from 'fflate';
import { XMLParser, XMLValidator } from 'fast-xml-parser';

export const headers = 'action,code_offre,operateur,famille,type_forfait,nom_affiche,prix_fcfa,volume_data,unite_data,minutes_appels,nombre_sms,duree_valeur,duree_unite,statut,mis_en_avant,ordre_affichage,activable_pour_tiers,canal_activation,reference_operateur,verifie_le,source_url,commentaire'.split(',');
export const maxFileBytes = 5 * 1024 * 1024;
const maxExpanded = 20 * 1024 * 1024;
const decoder = new TextDecoder('utf-8', {fatal:true});
type Obj = Record<string, unknown>;
function obj(value: unknown): Obj { return value && typeof value === 'object' && !Array.isArray(value) ? value as Obj : {}; }
function list(value: unknown): unknown[] { return value === undefined ? [] : Array.isArray(value) ? value : [value]; }
function string(value: unknown): string { return String(obj(value)['#text'] ?? (typeof value === 'object' ? '' : value ?? '')); }
function rich(value: unknown): string { const node=obj(value);return list(node.t).map(string).join('')+list(node.r).map(run=>list(obj(run).t).map(string).join('')).join(''); }
function parse(xml: string): Obj {
  if (/<!DOCTYPE|<!ENTITY/i.test(xml) || XMLValidator.validate(xml)!==true) throw Error('CATALOG_XML_INVALID');
  return new XMLParser({ignoreAttributes:false,removeNSPrefix:true,parseTagValue:false,parseAttributeValue:false,processEntities:false,trimValues:false}).parse(xml);
}
function col(ref: string): number { let index=0;for(const ch of ref.replace(/[0-9]/g,''))index=index*26+ch.charCodeAt(0)-64;return index-1; }

export function readOffers(bytes: Uint8Array): Obj[] {
  if(bytes.length>maxFileBytes)throw Error('CATALOG_FILE_TOO_LARGE');
  const view=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
  let end=-1;
  for(let at=bytes.length-22;at>=Math.max(0,bytes.length-65557);at--)if(view.getUint32(at,true)===0x06054b50){end=at;break;}
  if(end<0)throw Error('CATALOG_XLSX_INVALID');
  const count=view.getUint16(end+10,true),start=view.getUint32(end+16,true);
  if(count>2000||view.getUint16(end+4,true)!==0||view.getUint16(end+6,true)!==0)throw Error('CATALOG_ZIP_UNSUPPORTED');
  const entries=new Map<string,{offset:number,method:number,size:number,compressed:number}>();
  let cursor=start,total=0;
  for(let index=0;index<count;index++){
    if(cursor+46>bytes.length||view.getUint32(cursor,true)!==0x02014b50)throw Error('CATALOG_ZIP_INVALID');
    const flags=view.getUint16(cursor+8,true),method=view.getUint16(cursor+10,true),size=view.getUint32(cursor+24,true),compressed=view.getUint32(cursor+20,true),nameLen=view.getUint16(cursor+28,true),extra=view.getUint16(cursor+30,true),comment=view.getUint16(cursor+32,true);
    if(cursor+46+nameLen+extra+comment>bytes.length)throw Error('CATALOG_ZIP_INVALID');
    const name=decoder.decode(bytes.subarray(cursor+46,cursor+46+nameLen));
    if(flags&1||!([0,8].includes(method))||size===0xffffffff||compressed===0xffffffff)throw Error('CATALOG_ZIP_UNSUPPORTED');
    if(/vbaproject|macrosheet|activex/i.test(name))throw Error('CATALOG_MACRO_FORBIDDEN');
    if(name.includes('..')||name.startsWith('/')||entries.has(name))throw Error('CATALOG_ZIP_INVALID');
    total+=size;if(total>maxExpanded)throw Error('CATALOG_EXPANDED_TOO_LARGE');
    entries.set(name,{offset:view.getUint32(cursor+42,true),method,size,compressed});cursor+=46+nameLen+extra+comment;
  }
  function read(name:string):string{
    const entry=entries.get(name);if(!entry)throw Error('CATALOG_XLSX_PART_MISSING');
    const at=entry.offset;
    if(at+30>bytes.length||view.getUint32(at,true)!==0x04034b50)throw Error('CATALOG_ZIP_INVALID');
    const data=at+30+view.getUint16(at+26,true)+view.getUint16(at+28,true);
    if(data+entry.compressed>bytes.length)throw Error('CATALOG_ZIP_INVALID');
    const raw=bytes.subarray(data,data+entry.compressed);let result=raw;
    if(entry.method===8){
      const chunks:Uint8Array[]=[];let length=0;
      const stream=new Inflate((chunk)=>{length+=chunk.length;if(length>entry.size||length>maxExpanded)throw Error('CATALOG_EXPANDED_TOO_LARGE');chunks.push(chunk);});
      for(let offset=0;offset<raw.length;offset+=1024)stream.push(raw.subarray(offset,offset+1024),offset+1024>=raw.length);
      result=new Uint8Array(length);let offset=0;for(const chunk of chunks){result.set(chunk,offset);offset+=chunk.length;}
    }
    if(result.length!==entry.size)throw Error('CATALOG_ZIP_SIZE_MISMATCH');
    return decoder.decode(result);
  }
  const book=obj(parse(read('xl/workbook.xml')).workbook);
  if(['true','1'].includes(string(obj(book.workbookPr)['@_date1904'])))throw Error('CATALOG_DATE1904_UNSUPPORTED');
  const sheets=list(obj(book.sheets).sheet).map(obj),sheet=sheets.find(s=>s['@_name']==='OFFRES');
  if(!sheet)throw Error('CATALOG_OFFRES_MISSING');
  const relationships=obj(parse(read('xl/_rels/workbook.xml.rels')).Relationships);
  const rel=list(relationships.Relationship).map(obj).find(r=>r['@_Id']===sheet['@_id']);
  if(!rel||rel['@_TargetMode']==='External')throw Error('CATALOG_SHEET_RELATION_INVALID');
  const target=string(rel['@_Target']);
  const shared=entries.has('xl/sharedStrings.xml')?list(obj(parse(read('xl/sharedStrings.xml')).sst).si).map(rich):[];
  const sheetDoc=obj(parse(read(target.startsWith('/')?target.slice(1):`xl/${target}`)).worksheet);
  const rows=list(obj(sheetDoc.sheetData).row);
  if(rows.length>5001)throw Error('CATALOG_TOO_MANY_ROWS');
  const parsed:{line:number,values:string[]}[]=[];
  for(const raw of rows){
    const row=obj(raw),cells=list(row.c),values:string[]=[];
    if(cells.length>256)throw Error('CATALOG_TOO_MANY_COLUMNS');
    for(const rawCell of cells){
      const cell=obj(rawCell),ref=string(cell['@_r']),index=col(ref);
      if(Object.hasOwn(cell,'f'))throw Error(`CATALOG_FORMULA_FORBIDDEN: ${ref}`);
      if(cell['@_t']==='e')throw Error(`CATALOG_CELL_ERROR: ${ref}`);
      if(index<0||index>255)throw Error('CATALOG_CELL_INVALID');
      const value=string(cell.v);
      values[index]=cell['@_t']==='inlineStr'?rich(cell.is):cell['@_t']==='s'?shared[Number(value)]??'':value;
      if(values[index].length>2000)throw Error(`CATALOG_FIELD_TOO_LONG: ${ref}`);
    }
    if(values.some(value=>value?.trim()))parsed.push({line:Number(row['@_r']),values});
  }
  const first=parsed.shift();
  if(!first||first.line!==1)throw Error('CATALOG_HEADERS_MISSING');
  const names=first.values.map(value=>value.trim());
  if(headers.some(h=>names.filter(n=>n===h).length!==1)||names.some(n=>n&&!headers.includes(n)))throw Error('CATALOG_HEADERS_INVALID');
  if(!parsed.length)throw Error('CATALOG_OFFRES_EMPTY');
  const seen=new Set<number>();
  return parsed.map(({line,values})=>{
    if(!Number.isInteger(line)||line<2||line>100000||seen.has(line))throw Error('CATALOG_LINE_INVALID');seen.add(line);
    const result:Obj={_row:line};headers.forEach(key=>result[key]=values[names.indexOf(key)]??'');
    if(/^\d+(?:\.\d+)?$/.test(String(result.verifie_le))){const serial=Number(result.verifie_le);if(serial>0&&serial<100000)result.verifie_le=new Date(Date.UTC(1899,11,30)+serial*86400000).toISOString().slice(0,10);}
    return result;
  });
}
