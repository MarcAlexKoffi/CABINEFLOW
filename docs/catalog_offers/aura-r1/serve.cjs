// A local-only server for this isolated design revision. No workspace-wide access.
const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const root=__dirname;
const types={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.json':'application/json; charset=utf-8','.png':'image/png','.ttf':'font/ttf','.xlsx':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'};
const allowed=new Set(['index.html','styles.css','app.mjs','model.mjs','xlsx-reader.mjs','fixtures.json','Modele_import_offres_IzyTel.xlsx']);
const port=Number(process.env.IZYTEL_DESIGN_PORT||4317);
const server=http.createServer((request,response)=>{
  if(!['GET','HEAD'].includes(request.method)){response.writeHead(405);response.end();return;}
  let route;try{route=decodeURIComponent(new URL(request.url,'http://127.0.0.1').pathname).replace(/^\//,'')||'index.html';}catch{response.writeHead(400);response.end();return;}
  const target=path.resolve(root,route);
  if(!target.startsWith(root+path.sep)||(!allowed.has(route)&&!/^assets\/[A-Za-z0-9._-]+\.(png|ttf)$/.test(route))){response.writeHead(404);response.end();return;}
  fs.stat(target,(error,stat)=>{
    if(error||!stat.isFile()){response.writeHead(404);response.end();return;}
    response.writeHead(200,{'Content-Type':types[path.extname(target)]||'application/octet-stream','Content-Length':stat.size,'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",'Referrer-Policy':'no-referrer'});
    if(request.method==='HEAD'){response.end();return;}
    fs.createReadStream(target).pipe(response);
  });
});
server.on('error',error=>{console.error(error.message);process.exitCode=1;});
server.listen(port,'127.0.0.1',()=>console.log(`IzyTel DESIGN_REVIEW R1 : http://127.0.0.1:${port}`));
