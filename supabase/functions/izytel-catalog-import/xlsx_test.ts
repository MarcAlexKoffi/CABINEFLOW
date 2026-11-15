import {zipSync,unzipSync,strToU8,strFromU8} from 'fflate';
import {readOffers,maxFileBytes} from './xlsx.ts';
const original=await Deno.readFile(new URL('../../../assets/templates/Modele_import_offres_IzyTel.xlsx',import.meta.url));
function assert(condition:unknown,message='Assertion failed'):asserts condition{if(!condition)throw Error(message);}
function rejects(fn:()=>unknown,pattern:RegExp){try{fn();}catch(error){assert(pattern.test(String(error)),String(error));return;}throw Error('Expected rejection');}
function edit(file:string,transform:(xml:string)=>string){const entries=unzipSync(original);entries[file]=strToU8(transform(strFromU8(entries[file])));return zipSync(entries);}
Deno.test('real supplied workbook: exactly 40 drafts, other sheets ignored, decimal unit preserved',()=>{const rows=readOffers(original);assert(rows.length===40);assert(rows.every(r=>r.statut==='BROUILLON'));assert(rows[3].volume_data==='1.5');assert(rows[3].unite_data==='GO');assert(rows[0]._row===2);});
Deno.test('formula in OFFRES is rejected without execution',()=>rejects(()=>readOffers(edit('xl/worksheets/sheet1.xml',xml=>xml.replace(/(<c[^>]+r="G2"[^>]*>)/,'$1<f>1+1</f>'))),/FORMULA_FORBIDDEN/));
Deno.test('macro, missing OFFRES, bad headers, oversized data rejected',()=>{
  const entries=unzipSync(original);entries['xl/vbaProject.bin']=strToU8('not executed');rejects(()=>readOffers(zipSync(entries)),/MACRO_FORBIDDEN/);
  rejects(()=>readOffers(edit('xl/workbook.xml',xml=>xml.replace('name="OFFRES"','name="AUTRE"'))),/OFFRES_MISSING/);
  rejects(()=>readOffers(edit('xl/worksheets/sheet1.xml',xml=>xml.replace('code_offre','wrong_header'))),/HEADERS_INVALID/);
  rejects(()=>readOffers(new Uint8Array(maxFileBytes+1)),/FILE_TOO_LARGE/);
});
Deno.test('XML entity declarations refused',()=>{rejects(()=>readOffers(edit('xl/workbook.xml',xml=>xml.replace('<workbook','<!DOCTYPE workbook [<!ENTITY x "bad">]><workbook'))),/XML_INVALID/);});
Deno.test('URLs and HTML are data; precision is never converted from GO to MO',()=>{const result=readOffers(edit('xl/worksheets/sheet1.xml',xml=>xml.replace('220 MO','&lt;img src=x onerror=alert(1)&gt;')));assert(typeof result[0].nom_affiche==='string');assert(result[3].volume_data==='1.5'&&result[3].unite_data==='GO');});
