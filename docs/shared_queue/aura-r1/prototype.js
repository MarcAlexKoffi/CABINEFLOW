'use strict';

// AURA R1 — simulation locale uniquement. Aucune API, aucun lien tel: ou USSD.
const icons = {
  refresh:'<path d="M20 7v5h-5M4 17v-5h5"/><path d="M6 7a7 7 0 0 1 12-1l2 3M4 15l2 3a7 7 0 0 0 12-1"/>',
  bell:'<path d="M18 8a6 6 0 0 0-12 0c0 7-3 7-3 9h18c0-2-3-2-3-9M10 21h4"/>',
  home:'<path d="m3 10 9-7 9 7M5 9v12h5v-7h4v7h5V9"/>',
  orders:'<rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4V2h6v2M9 9h6M9 13h6M9 17h4"/>',
  history:'<path d="M3 4v6h6M3 10a9 9 0 1 1 1 8M12 7v5l3 2"/>',
  user:'<circle cx="12" cy="7" r="4"/><path d="M4 21v-2a8 8 0 0 1 16 0v2"/>',
  location:'<path d="M19 9c0 6-7 12-7 12S5 15 5 9a7 7 0 1 1 14 0Z"/><circle cx="12" cy="9" r="2"/>',
  clock:'<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
  arrow:'<path d="M4 12h15m-5-5 5 5-5 5"/>',
  back:'<path d="M20 12H5m5-5-5 5 5 5"/>',
  phone:'<rect x="6" y="2" width="12" height="20" rx="3"/><path d="M10 18h4"/>',
  shield:'<path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6l8-3Z"/><path d="m8 12 3 3 5-6"/>',
  check:'<path d="m5 12 4 4L20 5"/>',
  success:'<circle cx="12" cy="12" r="9"/><path d="m7 12 3 3 7-7"/>',
  warning:'<path d="m12 3 10 18H2L12 3Z"/><path d="M12 9v5m0 3v1"/>',
  offline:'<path d="m3 3 18 18M2 8a16 16 0 0 1 3-2m4-1a17 17 0 0 1 13 3M5 12a11 11 0 0 1 4-2m5 0a11 11 0 0 1 5 2M8 16a6 6 0 0 1 7-1M12 20h.01"/>',
  inbox:'<path d="m3 12 3-8h12l3 8v8H3v-8Z"/><path d="M3 12h5l2 3h4l2-3h5"/>',
  flask:'<path d="M9 2h6M10 2v7L4 19a2 2 0 0 0 2 3h12a2 2 0 0 0 2-3L14 9V2M8 15h8"/>',
  copy:'<rect x="8" y="8" width="13" height="13" rx="2"/><path d="M16 8V3H3v13h5"/>',
  pause:'<path d="M8 5v14M16 5v14"/>',
  cross:'<path d="m6 6 12 12M18 6 6 18"/>',
  info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7h.01"/>'
};
function icon(name){return `<svg class="icon" viewBox="0 0 24 24" aria-hidden="true">${icons[name] || icons.info}</svg>`;}
function hydrateIcons(){document.querySelectorAll('[data-icon]').forEach(el=>{el.innerHTML=icon(el.dataset.icon);});}
const byId=id=>document.getElementById(id);
const money=value=>new Intl.NumberFormat('fr-FR').format(value);
const networkNames={orange:'Orange',mtn:'MTN',moov:'Moov Africa'};
const networkInitials={orange:'O',mtn:'M',moov:'m'};
const DEMO_AGENT='Awa K. (démo)';
const ZONE='Cocody · Riviera';
const availableSeeds=[
  {id:'0418',network:'orange',offer:'Internet · 1 Go',service:'Forfait internet · 7 jours',amount:1000,age:'2 min',beneficiary:'07 •• •• 42 18',fullPhone:'07 00 00 00 18'},
  {id:'0419',network:'mtn',offer:'Transfert d’unités',service:'Crédit de communication',amount:2000,age:'1 min',beneficiary:'05 •• •• 16 32',fullPhone:'05 00 00 00 32'},
  {id:'0420',network:'moov',offer:'Appels · 60 minutes',service:'Forfait voix · 7 jours',amount:500,age:'À l’instant',beneficiary:'01 •• •• 80 24',fullPhone:'01 00 00 00 24'}
];
let state;
let generation=0;
let toastTimer;
const ref=id=>`IZY-DEMO-${id}`;
const clone=data=>JSON.parse(JSON.stringify(data));

function resetState(keepRole=true){
  generation++;
  const role=keepRole && state ? state.role:'agent';
  state={role,scenario:'normal',tab:'available',nav:'orders',agentView:'list',detailId:null,returnTab:'available',busy:null,conflict:false,success:false,managerView:'list',managerFilter:'all',managerDetailId:null,serverNow:0,alerts:[{id:'0406:1:delay',orderId:'0406',version:1,active:true,reason:null}],
    queue:clone(availableSeeds),
    mine:[{id:'0412',network:'orange',offer:'Internet · 2 Go',service:'Forfait internet · 7 jours',amount:2000,beneficiary:'07 •• •• 22 10',fullPhone:'07 00 00 00 10',status:'progress',version:1,agent:DEMO_AGENT,elapsed:132},
      {id:'0413',network:'mtn',offer:'Transfert d’unités',service:'Crédit de communication',amount:500,beneficiary:'05 •• •• 12 80',fullPhone:'05 00 00 00 80',status:'assigned',version:1,agent:DEMO_AGENT,elapsed:null}],
    managerRows:[{id:'0406',network:'orange',offer:'Internet · 1 Go',amount:1000,status:'progress',agent:DEMO_AGENT,elapsed:402,version:1,beneficiary:'07 •• •• 10 06'},
      {id:'0412',network:'orange',offer:'Internet · 2 Go',amount:2000,status:'progress',agent:DEMO_AGENT,elapsed:132,version:1,beneficiary:'07 •• •• 22 10'},
      {id:'0410',network:'mtn',offer:'Transfert d’unités',amount:2000,status:'accepted',agent:'Idriss B. (démo)',elapsed:81,version:1,beneficiary:'05 •• •• 16 32'},
      {id:'0409',network:'moov',offer:'Appels · 60 minutes',amount:500,status:'failed',agent:'Moussa T. (démo)',elapsed:117,version:1,beneficiary:'01 •• •• 80 24'}]
  };
  byId('scenario').value='normal';
  byId('action-dialog').close();
  byId('toast').hidden=true;
  render();
}
function elapsedLabel(seconds){const m=Math.floor(seconds/60),s=seconds%60;return `${String(m).padStart(2,'0')} min ${String(s).padStart(2,'0')} s`;}
function isFinal(row){return ['completed','failed','cancelled','refunded'].includes(row.status);}
function isLate(row){return row.elapsed!==null && row.elapsed>300 && !isFinal(row) && row.status!=='assigned';}
function cycleAlert(row){return state.alerts.find(a=>a.orderId===row.id && a.version===row.version);}
function upsertManager(row){const index=state.managerRows.findIndex(r=>r.id===row.id);if(index<0)state.managerRows.unshift(clone(row));else state.managerRows[index]={...state.managerRows[index],...clone(row)};}
function resolveCycle(row,reason){state.alerts.forEach(a=>{if(a.orderId===row.id && a.active){a.active=false;a.reason=reason;}});}
function syncSla(){state.managerRows.forEach(row=>{if(isLate(row) && !cycleAlert(row))state.alerts.unshift({id:`${row.id}:${row.version}:delay`,orderId:row.id,version:row.version,active:true,reason:null});});}
function toast(message,error=false){clearTimeout(toastTimer);const el=byId('toast');el.className=`toast${error?' error':''}`;el.innerHTML=icon(error?'warning':'success')+`<span>${message}</span>`;el.hidden=false;toastTimer=setTimeout(()=>{el.hidden=true;},4500);}
function openDialog(markup){byId('dialog-content').innerHTML=markup;hydrateIcons();byId('action-dialog').showModal();}
function dialogActions(confirmLabel,action){return `<div class="button-group"><button type="button" class="secondary-button" data-action="close-dialog">Annuler</button><button type="button" class="primary-button" data-action="${action}">${confirmLabel}</button></div>`;}
function network(row){return `<span class="network-label"><span class="network-mark ${row.network}">${networkInitials[row.network]}</span>${networkNames[row.network]}</span>`;}
function badge(status,late=false){const map={assigned:['À accepter','inactive'],accepted:['Acceptée','accepted'],progress:['En cours','progress'],hold:['En attente','hold'],completed:['Terminée','completed'],failed:['Intervention','failed']};const val=late?['En retard','overdue']:(map[status]||['Disponible','available']);return `<span class="status ${val[1]}">${val[0]}</span>`;}
function stateMessage(type,title,body,button=''){const symbol={warning:'warning',error:'warning',success:'success',offline:'offline'}[type]||'info';return `<div class="state-message ${type==='offline'?'warning':type}"${type==='error'?' role="alert"':''}>${icon(symbol)}<div><strong>${title}</strong><p>${body}</p>${button}</div></div>`;}
function emptyState(symbol,title,body,action=''){return `<div class="empty-state"><div class="empty-symbol">${icon(symbol)}</div><h3>${title}</h3><p>${body}</p>${action}</div>`;}

function queueCard(row){
  const disabled=state.busy!==null || ['offline','unavailable'].includes(state.scenario);
  const pending=state.busy===row.id;
  return `<article class="order-card" data-order="${row.id}">
    <div class="card-top">${network(row)}<span class="status ${state.scenario==='offline'?'inactive':'available'}"><span class="tiny-dot"></span>${state.scenario==='offline'?'À vérifier':'Disponible'}</span></div>
    <p class="order-ref">${ref(row.id)}</p><div class="offer-row"><div><h3>${row.offer}</h3><small>${row.service}</small></div><div class="amount">${money(row.amount)}<small>F CFA</small></div></div>
    <div class="card-meta"><span>${icon('phone')}${row.beneficiary}</span><span>${icon('clock')}${row.age}</span></div>
    <button type="button" class="primary-button block" data-action="accept" data-id="${row.id}"${disabled?' disabled':''}>${pending?'<span class="spinner" aria-hidden="true"></span>Acceptation en cours…':`Accepter et traiter ${icon('arrow')}`}</button>
  </article>`;
}
function mineCard(row){return `<article class="order-card" data-order="${row.id}"><div class="card-top">${network(row)}${badge(row.status)}</div><p class="order-ref">${ref(row.id)}</p><div class="offer-row"><div><h3>${row.offer}</h3><small>${row.status==='assigned'?'Affectation manuelle à confirmer':row.status==='completed'?'Traitement finalisé':'Vous êtes responsable'}</small></div><div class="amount">${money(row.amount)}<small>F CFA</small></div></div><div class="card-meta"><span>${icon('phone')}${row.beneficiary}</span><span>${icon('clock')}${row.elapsed===null?'Non acceptée':elapsedLabel(row.elapsed)}</span></div><button type="button" class="secondary-button block" data-action="open-agent-order" data-id="${row.id}">${row.status==='assigned'?'Ouvrir l’affectation':'Ouvrir le traitement'}${icon('arrow')}</button></article>`;}
function renderAgentList(){
  const available=state.scenario==='empty'?[]:state.queue;
  const mine=state.mine.filter(row=>row.status!=='completed');
  let html=`<div class="greeting">Bonjour Awa <span aria-hidden="true">✦</span></div><div class="page-heading"><div><h2>Commandes</h2><p>Votre zone. Votre prochaine mission.</p></div><span class="live-badge">${state.scenario==='offline'?'Hors ligne':'En ligne'}</span></div><div class="zone-chip">${icon('location')}${ZONE}</div>
    <div class="orders-tabs" role="tablist" aria-label="Files de commandes"><button type="button" id="available-tab" role="tab" aria-selected="${state.tab==='available'}" aria-controls="orders-panel" data-action="tab" data-tab="available">À prendre <span class="count">${available.length}</span></button><button type="button" id="mine-tab" role="tab" aria-selected="${state.tab==='mine'}" aria-controls="orders-panel" data-action="tab" data-tab="mine">Mes commandes <span class="count">${mine.length}</span></button></div><div id="orders-panel" role="tabpanel" aria-labelledby="${state.tab==='available'?'available-tab':'mine-tab'}">`;
  if(state.tab==='mine'){
    html+=`<div class="section-caption"><strong>Vos prises en charge</strong><span>${mine.length} commande${mine.length>1?'s':''}</span></div>`;
    html+=mine.length?mine.map(mineCard).join(''):emptyState('orders','Aucune commande en cours','Les commandes que vous acceptez apparaissent ici.');
  }else{
    if(state.scenario==='offline')html+=stateMessage('offline','Vous êtes hors connexion','La disponibilité des commandes doit être revérifiée. Reconnectez-vous pour accepter une commande.',`<button type="button" class="secondary-button" data-action="retry">Réessayer</button>`);
    if(state.scenario==='unavailable')html+=stateMessage('warning','Vous êtes indisponible','Passez en disponibilité depuis votre profil pour prendre une commande.',`<button type="button" class="secondary-button" data-action="set-available">Me rendre disponible · démo</button>`);
    if(state.conflict)html+=stateMessage('warning','Cette commande a déjà été prise','Un autre Agent a accepté cette commande. Elle a été retirée de la file.');
    if(state.scenario==='loading')html+=`<div aria-busy="true" aria-label="Chargement de la file">${[1,2].map(()=>'<div class="skeleton-card" aria-hidden="true"><div class="skeleton short"></div><div class="skeleton wide"></div><div class="skeleton"></div><div class="skeleton action"></div></div>').join('')}<p class="loading-label">Actualisation des commandes…</p></div>`;
    else if(state.scenario==='error')html+=emptyState('warning','La file est indisponible','Impossible de charger les commandes pour le moment. Vous pouvez réessayer.',`<button type="button" class="primary-button" data-action="retry">${icon('refresh')}Réessayer</button>`);
    else{
      html+=`<div class="section-caption"><strong>${available.length} commande${available.length>1?'s':''} disponible${available.length>1?'s':''}</strong><span>Les plus anciennes d’abord</span></div>`;
      html+=available.length?available.map(queueCard).join(''):emptyState('inbox','Tout est à jour','Aucune commande à prendre dans votre zone. Les nouvelles commandes apparaîtront ici.');
      html+=`<p class="queue-footnote">${icon('shield')}<span>La première acceptation confirmée attribue la commande à un seul Agent.</span></p>`;
    }
  }
  return html+'</div>';
}

function renderAgentDetail(){
  const row=state.mine.find(r=>r.id===state.detailId);
  if(!row){state.agentView='list';return renderAgentList();}
  let html=`<button type="button" class="back-link" data-action="agent-back">${icon('back')}Commandes</button><h2 class="detail-heading">Traitement de commande</h2><p class="detail-subtitle">${ref(row.id)}</p>`;
  if(state.success)html+=stateMessage('success','Commande acceptée','Elle vous est attribuée. Vous pouvez maintenant la traiter.');
  if(row.status==='assigned')html+=stateMessage('info','Affectation manuelle','Le Manager vous a attribué cette commande. Elle attend votre acceptation.');
  html+=`<div class="detail-card"><div class="card-top">${network(row)}${badge(row.status)}</div><p class="order-ref">${row.service||'Commande de démonstration'}</p><div class="offer-row"><h3>${row.offer}</h3><div class="amount">${money(row.amount)}<small>F CFA</small></div></div></div>`;
  html+=`<div class="detail-card"><div class="detail-title-row"><h3>Bénéficiaire</h3><span>Numéro fictif</span></div><p class="large-beneficiary">${row.fullPhone}</p><dl class="detail-grid"><dt>Zone</dt><dd>${ZONE}</dd><dt>Responsable</dt><dd>Awa K. · démo</dd><dt>Acceptation</dt><dd>${row.elapsed===null?'En attente':'09:41:42 · démo'}</dd></dl></div>`;
  if(row.status==='assigned')return html+`<button type="button" class="primary-button block" data-action="accept-legacy" data-id="${row.id}">Accepter et traiter${icon('arrow')}</button>`;
  if(isFinal(row))return html+stateMessage(row.status==='completed'?'success':'warning',row.status==='completed'?'Commande terminée':'Échec signalé au Manager',row.status==='completed'?'La finalisation a été confirmée dans ce prototype.':'Le suivi de l’échec reste dans le circuit Manager.');
  html+=`<div class="ussd-card"><div class="ussd-title">${icon('phone')}Raccourci USSD</div><p>Ouvrez le raccourci puis effectuez l’opération. Son ouverture ne confirme pas la réussite.</p><button type="button" class="primary-button block" data-action="ussd">Ouvrir le raccourci${icon('arrow')}</button></div>`;
  if(row.status==='accepted')html+=`<button type="button" class="secondary-button block" data-action="start-manual">Démarrer le traitement manuel</button>`;
  html+=`<div class="terminal-actions"><button type="button" class="secondary-button block" data-action="confirm-success">${icon('success')}Confirmer la réussite</button><button type="button" class="danger-button block" data-action="confirm-failure">${icon('warning')}Signaler un échec</button><button type="button" class="secondary-button block" data-action="hold">${icon('pause')}Mettre en attente</button></div><p class="terminal-note">Le statut final dépend de votre confirmation métier.</p>`;
  return html;
}
function renderSecondaryNav(){
  if(state.nav==='history')return `<div class="page-heading"><div><h2>Historique</h2><p>Commandes de démonstration finalisées</p></div></div>${state.mine.filter(r=>isFinal(r)).map(mineCard).join('')||emptyState('history','Aucune finalisation simulée','Finalisez une commande dans ce prototype pour la retrouver ici.')}`;
  if(state.nav==='profile')return `<div class="page-heading"><h2>Mon profil</h2></div><div class="detail-card"><div class="profile-summary"><span class="avatar">AK</span><div><strong>${DEMO_AGENT}</strong><p>Agent IzyTel</p></div></div><div class="simple-row"><span>Zone autorisée</span><strong>${ZONE}</strong></div><div class="simple-row"><span>Disponibilité</span><strong>${state.scenario==='unavailable'?'Indisponible':'Disponible'}</strong></div></div><p class="queue-footnote">Les autres réglages du profil sont hors du périmètre de cette maquette.</p>`;
  return `<div class="greeting">Bonjour Awa</div><div class="page-heading"><div><h2>Votre activité</h2><p>Prête pour votre prochaine commande ?</p></div></div><div class="detail-card"><h3>Commandes de votre zone</h3><p class="detail-subtitle">${state.queue.length} commande${state.queue.length>1?'s':''} à prendre · ${ZONE}</p><button type="button" class="primary-button block" data-action="go-orders">Consulter la file${icon('arrow')}</button></div>`;
}

function managerRow(row){return `<tr class="${isLate(row)?'overdue-row':''}"><td><span class="table-ref">${ref(row.id)}</span><span class="table-secondary">${networkNames[row.network]} · ${money(row.amount)} F CFA</span></td><td><span class="agent-name"><span class="small-avatar">${row.agent.startsWith('Awa')?'AK':row.agent.startsWith('Idriss')?'IB':'MT'}</span>${row.agent.replace(' (démo)','')}</span><span class="table-secondary">${row.offer}</span></td><td>${badge(row.status,isLate(row))}</td><td><span class="elapsed ${isLate(row)?'late':''}">${row.elapsed===null?'—':elapsedLabel(row.elapsed)}</span><span class="table-secondary">${row.status==='assigned'?'Acceptation attendue':'Depuis acceptation'}</span></td><td><button type="button" class="table-open" data-action="manager-detail" data-id="${row.id}" aria-label="Ouvrir la commande ${ref(row.id)}">Ouvrir →</button></td></tr>`;}
function renderManagerList(){
  const counts={all:state.managerRows.length,accepted:state.managerRows.filter(r=>r.status==='accepted').length,progress:state.managerRows.filter(r=>['progress','hold'].includes(r.status)).length,overdue:state.managerRows.filter(isLate).length,intervention:state.managerRows.filter(r=>r.status==='failed').length};
  let rows=state.managerRows;
  if(state.managerFilter==='accepted')rows=rows.filter(r=>r.status==='accepted');
  if(state.managerFilter==='progress')rows=rows.filter(r=>['progress','hold'].includes(r.status));
  if(state.managerFilter==='overdue')rows=rows.filter(isLate);
  if(state.managerFilter==='intervention')rows=rows.filter(r=>r.status==='failed');
  const active=state.alerts.filter(a=>a.active);
  let html=`<div class="manager-heading"><span class="eyebrow">ESPACE MANAGER</span><h2>Suivi des commandes</h2><p>Gardez le fil de chaque prise en charge.</p></div><div class="manager-toolbar"><span class="manager-scope">${icon('location')}${ZONE}</span><span class="server-time">Actualisé · heure serveur simulée</span></div>`;
  if(state.scenario==='offline')html+=stateMessage('offline','Connexion interrompue','Les données affichées peuvent être anciennes. Les actions attendent une reconnexion.',`<button type="button" class="secondary-button" data-action="retry">Réessayer</button>`);
  if(state.scenario==='loading')return html+`<div aria-busy="true" aria-label="Chargement de la supervision"><div class="skeleton-card"><div class="skeleton short"></div><div class="skeleton"></div><div class="skeleton wide"></div></div><p class="loading-label">Chargement du suivi…</p></div>`;
  if(state.scenario==='error')return html+emptyState('warning','Le suivi est indisponible','Vos commandes seront rechargées dès que la connexion le permettra.',`<button type="button" class="primary-button" data-action="retry">Réessayer</button>`);
  if(state.scenario==='empty')return html+emptyState('orders','Aucune commande à suivre','Les commandes acceptées de votre zone apparaîtront ici.');
  if(active.length)html+=`<div class="sla-banner">${icon('clock')}<div><strong>${active.length} commande${active.length>1?'s':''} au-delà de cinq minutes</strong><p>Une prise en charge attend votre attention.</p></div><button type="button" class="secondary-button" data-action="manager-alerts">Voir les alertes${icon('arrow')}</button></div>`;
  html+=`<div class="manager-filters" role="group" aria-label="Filtrer la supervision">${[['all','Toutes'],['accepted','Acceptées'],['progress','En cours'],['overdue','En retard'],['intervention','Intervention']].map(([key,label])=>`<button type="button" data-action="manager-filter" data-filter="${key}" aria-pressed="${state.managerFilter===key}">${label}<span>${counts[key]}</span></button>`).join('')}</div>`;
  html+=rows.length?`<div class="table-scroll" role="region" aria-label="Commandes de la zone"><table class="orders-table"><caption class="sr-only">Suivi des commandes de démonstration de ${ZONE}</caption><thead><tr><th scope="col">Commande</th><th scope="col">Agent</th><th scope="col">État</th><th scope="col">Durée</th><th scope="col"><span class="sr-only">Action</span></th></tr></thead><tbody>${rows.map(managerRow).join('')}</tbody></table></div>`:emptyState('check','Aucune commande dans cet état','Les autres commandes restent accessibles avec le filtre Toutes.');
  return html+`<p class="table-note">${icon('shield')}Les commandes et alertes affichées appartiennent à votre zone.</p>`;
}
function renderAlerts(){
  return `<button type="button" class="back-link" data-action="manager-list">${icon('back')}Suivi des commandes</button><div class="manager-heading"><span class="eyebrow">SUPERVISION · ${ZONE.toUpperCase()}</span><h2>Alertes de prise en charge</h2><p>Retrouvez les alertes, même sans notification push.</p></div>${state.alerts.map(a=>{const row=state.managerRows.find(r=>r.id===a.orderId);return `<button type="button" class="alert-card${a.active?'':' inactive-alert'}" data-action="manager-detail" data-id="${a.orderId}"><div class="alert-card-header"><span class="status ${a.active?'overdue':'inactive'}">${icon(a.active?'clock':'check')}${a.active?'Délai dépassé':a.reason==='reassigned'?'Obsolète · réaffectée':'Résolue · finalisée'}</span><span class="table-secondary">Cycle ${a.version} · démo</span></div><h3>${ref(a.orderId)}</h3><p>${row.agent}<br>${a.active?`${elapsedLabel(row.elapsed)} depuis l’acceptation · ${row.status==='hold'?'En attente':'En cours de traitement'}`:'Le suivi de cette acceptation n’est plus actif.'}</p><span class="table-open">Ouvrir la commande${icon('arrow')}</span></button>`;}).join('')||emptyState('success','Aucune alerte de retard','Les commandes finalisées avant cinq minutes ne déclenchent pas d’alerte.')}<p class="table-note">${icon('info')}L’ouverture d’une alerte ne la résout pas. La fin du traitement ou la réaffectation met à jour son état.</p>`;
}
function renderManagerDetail(){
  const row=state.managerRows.find(r=>r.id===state.managerDetailId);
  if(!row){state.managerView='list';return renderManagerList();}
  let html=`<button type="button" class="back-link" data-action="manager-back">${icon('back')}${state.managerReturn==='alerts'?'Alertes':'Suivi des commandes'}</button><div class="manager-heading"><span class="eyebrow">${ZONE.toUpperCase()}</span><h2>${ref(row.id)}</h2><p>Suivi de la prise en charge · ${row.offer}</p></div>`;
  if(isLate(row))html+=`<div class="sla-banner" style="margin-top:20px">${icon('clock')}<div><strong>Le délai de cinq minutes est dépassé</strong><p>${elapsedLabel(row.elapsed)} depuis l’acceptation. La commande n’est pas finalisée.</p></div></div>`;
  else if(row.status==='assigned')html+=stateMessage('info','Réaffectation effectuée','La commande attend l’acceptation du nouvel Agent. Le nouveau suivi commencera à son acceptation.');
  else html+='<div style="height:20px"></div>';
  html+=`<div class="manager-detail-layout"><div class="detail-card"><h3>Commande</h3><dl class="detail-grid"><dt>Opérateur</dt><dd>${networkNames[row.network]}</dd><dt>Service et offre</dt><dd>${row.offer}</dd><dt>Montant</dt><dd>${money(row.amount)} F CFA</dd><dt>Bénéficiaire · fictif</dt><dd>${row.beneficiary}</dd><dt>État actuel</dt><dd>${badge(row.status,isLate(row))}</dd></dl></div><div class="detail-card"><h3>Prise en charge</h3><dl class="detail-grid"><dt>Agent responsable</dt><dd>${row.agent}</dd><dt>Durée depuis acceptation</dt><dd>${row.elapsed===null?'Acceptation attendue':elapsedLabel(row.elapsed)}</dd><dt>Cycle de suivi</dt><dd>${row.version} · démonstration</dd><dt>Alerte de ce cycle</dt><dd>${cycleAlert(row)?.active?'Active':cycleAlert(row)?'Résolue / obsolète':'Aucune'}</dd></dl></div></div>`;
  html+=`<div class="detail-card"><h3>Activité de la commande</h3><ol class="timeline"><li>Paiement validé<small>Commande confirmée · démo</small></li><li>${row.status==='assigned'?'Réaffectation manuelle':'Commande acceptée'}<small>${row.agent}</small></li>${isLate(row)?'<li>Alerte de retard créée<small>Une seule alerte pour cette acceptation</small></li>':''}<li>${isFinal(row)?'Traitement finalisé':row.status==='assigned'?'En attente d’acceptation':'Traitement non finalisé'}<small>${row.status==='failed'?'Échec à analyser par le Manager':'État de démonstration'}</small></li></ol></div>`;
  const disabled=state.scenario==='offline'?' disabled':'';
  html+=`<div class="manager-actions">${!isFinal(row)?`<button type="button" class="primary-button" data-action="reassign"${disabled}>Réaffecter la commande</button>`:''}<button type="button" class="secondary-button" data-action="existing-actions"${disabled}>Ouvrir les actions de supervision${icon('arrow')}</button></div>`;
  return html;
}
function render(){
  document.body.classList.toggle('manager-mode',state.role==='manager');
  document.querySelectorAll('[data-role]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.role===state.role)));
  byId('agent-preview').hidden=state.role!=='agent';byId('manager-preview').hidden=state.role!=='manager';
  byId('time-skip').hidden=state.role!=='manager';
  byId('preview-title').textContent=state.role==='agent'?'AGENT · COMMANDES':'MANAGER · SUPERVISION';
  byId('preview-description').textContent=state.role==='agent'?'Mobile · thème clair IzyTel':'Mobile / Web · périmètre territorial';
  byId('agent-content').innerHTML=state.agentView==='detail'?renderAgentDetail():state.nav==='orders'?renderAgentList():renderSecondaryNav();
  byId('manager-content').innerHTML=state.managerView==='alerts'?renderAlerts():state.managerView==='detail'?renderManagerDetail():renderManagerList();
  byId('manager-bell-dot').hidden=!state.alerts.some(a=>a.active);
  document.querySelectorAll('[data-nav]').forEach(b=>{if(b.dataset.nav===state.nav)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');});
  document.querySelectorAll('.journey li').forEach((el,index)=>el.classList.toggle('current',index===(state.role==='manager'?2:state.agentView==='detail'?1:0)));
  hydrateIcons();
}
function openAgentOrder(id,success=false){state.detailId=id;state.returnTab=state.tab;state.agentView='detail';state.nav='orders';state.success=success;render();byId('agent-content').querySelector('.detail-heading')?.scrollIntoView({block:'nearest'});}
function agentBack(){if(byId('action-dialog').open){byId('action-dialog').close();return;}if(state.agentView==='detail'){state.agentView='list';state.tab=state.returnTab;state.success=false;render();}else if(state.nav!=='orders'){state.nav='orders';render();}else toast('Dans l’application, Retour conserve le parcours puis demande confirmation avant la sortie.');}
async function accept(id){
  if(state.busy || ['offline','unavailable'].includes(state.scenario))return;
  const row=state.queue.find(r=>r.id===id);if(!row)return;
  const stamp=generation;state.busy=id;render();
  await new Promise(resolve=>setTimeout(resolve,1000));
  if(generation!==stamp)return;
  state.busy=null;
  state.queue=state.queue.filter(r=>r.id!==id);
  if(state.scenario==='taken'){
    state.conflict=true;state.scenario='normal';byId('scenario').value='normal';render();toast('Cette commande a déjà été acceptée par un autre Agent.',true);return;
  }
  const claimed={...row,status:'accepted',elapsed:0,agent:DEMO_AGENT,version:1};
  state.mine.unshift(claimed);upsertManager(claimed);state.returnTab=state.tab;
  // Le statut reste accepted : ni startProcessing, ni dialer, ni finalisation.
  openAgentOrder(id,true);toast('Commande acceptée. Vous pouvez la traiter.');
}
function updateAgentStatus(status){const row=state.mine.find(r=>r.id===state.detailId);if(!row)return;row.status=status;upsertManager(row);if(isFinal(row))resolveCycle(row,'finalized');state.success=false;render();}

document.addEventListener('click',event=>{
  const b=event.target.closest('button');if(!b || b.disabled)return;
  if(b.dataset.role){state.role=b.dataset.role;render();return;}
  if(b.dataset.nav){state.nav=b.dataset.nav;state.agentView='list';state.success=false;render();return;}
  const action=b.dataset.action,id=b.dataset.id;
  switch(action){
    case 'close-dialog':byId('action-dialog').close();break;
    case 'tab':state.tab=b.dataset.tab;state.agentView='list';state.success=false;render();break;
    case 'retry':case 'set-available':state.scenario='normal';byId('scenario').value='normal';render();toast(action==='set-available'?'Disponibilité mise à jour · démonstration.':'Connexion rétablie · démonstration.');break;
    case 'accept':accept(id);break;
    case 'open-agent-order':openAgentOrder(id);break;
    case 'agent-back':agentBack();break;
    case 'go-orders':state.nav='orders';state.agentView='list';render();break;
    case 'accept-legacy':{const row=state.mine.find(r=>r.id===id);if(row){row.status='accepted';row.elapsed=0;upsertManager(row);state.success=true;render();toast('Affectation acceptée.');}break;}
    case 'ussd':openDialog(`<h2>Raccourci USSD</h2><p>Dans l’application, cette action ouvre le raccourci existant et attend votre intervention. Aucun appel ni code USSD ne sera exécuté par ce prototype.</p><div class="button-group"><button type="button" class="primary-button" data-action="close-dialog">Revenir au traitement</button></div>`);break;
    case 'start-manual':updateAgentStatus('progress');toast('Traitement manuel démarré · démonstration.');break;
    case 'hold':updateAgentStatus('hold');toast('Commande mise en attente. Le suivi Manager continue.');break;
    case 'confirm-success':openDialog(`<h2>Confirmer la réussite ?</h2><p>Confirmez uniquement après avoir réellement effectué l’opération. Dans ce prototype, cette confirmation simule la finalisation de ${ref(state.detailId)}.</p>${dialogActions('Confirmer la réussite','finish-success')}`);break;
    case 'finish-success':byId('action-dialog').close();updateAgentStatus('completed');toast('Commande terminée · démonstration.');break;
    case 'confirm-failure':openDialog(`<h2>Signaler un échec</h2><p>Le signalement sera présenté au Manager. Il garde son circuit d’analyse propre.</p><label for="failure-reason" class="dialog-label">Motif</label><select id="failure-reason"><option>Réseau indisponible</option><option>Numéro incorrect</option><option>Solde insuffisant</option><option>Erreur technique</option></select>${dialogActions('Confirmer le signalement','finish-failure')}`);break;
    case 'finish-failure':byId('action-dialog').close();updateAgentStatus('failed');toast('Échec signalé au Manager · démonstration.');break;
    case 'manager-filter':state.managerFilter=b.dataset.filter;render();break;
    case 'manager-alerts':state.managerView='alerts';render();break;
    case 'manager-list':state.managerView='list';render();break;
    case 'manager-detail':state.managerReturn=state.managerView==='alerts'?'alerts':'list';state.managerDetailId=id;state.managerView='detail';render();break;
    case 'manager-back':state.managerView=state.managerReturn||'list';render();break;
    case 'reassign':openDialog(`<h2>Réaffecter la commande</h2><p>L’alerte de l’ancienne acceptation deviendra obsolète. Le nouveau suivi commencera quand le nouvel Agent aura accepté.</p><label for="new-agent" class="dialog-label">Agent autorisé de ${ZONE}</label><select id="new-agent"><option value="Idriss B. (démo)">Idriss B. · Agent de démonstration</option><option value="Moussa T. (démo)">Moussa T. · Agent de démonstration</option></select>${dialogActions('Confirmer la réaffectation','finish-reassign')}`);break;
    case 'finish-reassign':{const row=state.managerRows.find(r=>r.id===state.managerDetailId);if(row){resolveCycle(row,'reassigned');row.agent=byId('new-agent').value;row.version++;row.status='assigned';row.elapsed=null;state.mine=state.mine.filter(r=>r.id!==row.id);}byId('action-dialog').close();render();toast('Réaffectation simulée. Acceptation du nouvel Agent attendue.');break;}
    case 'existing-actions':openDialog(`<h2>Actions de supervision</h2><p>Dans l’application, ce point d’entrée ouvre le détail autorisé et les actions déjà disponibles au Manager. Les paiements, remboursements et opérations financières restent dans leurs parcours existants.</p><div class="button-group"><button type="button" class="primary-button" data-action="close-dialog">Revenir à la commande</button></div>`);break;
    case 'notification-order':byId('action-dialog').close();state.nav='orders';state.tab='available';state.agentView='list';render();toast('Ouverture de la file de votre zone · démonstration.');break;
  }
});
byId('scenario').addEventListener('change',event=>{generation++;state.busy=null;state.scenario=event.target.value;state.conflict=false;state.agentView='list';state.nav='orders';state.tab='available';state.managerView='list';render();});
byId('reset').addEventListener('click',()=>resetState());
byId('android-back').addEventListener('click',agentBack);
byId('manager-bell').addEventListener('click',()=>{state.managerView=state.managerView==='alerts'?'list':'alerts';render();});
byId('agent-bell').addEventListener('click',()=>openDialog(`<h2>Nouvelle commande disponible</h2><p>Une commande validée est disponible dans votre zone. La prise en charge reste à confirmer.</p><div class="button-group"><button type="button" class="secondary-button" data-action="close-dialog">Fermer</button><button type="button" class="primary-button" data-action="notification-order">Voir les commandes</button></div>`));
byId('time-skip').addEventListener('click',()=>{state.serverNow+=360;state.managerRows.forEach(row=>{if(row.elapsed!==null && !isFinal(row))row.elapsed+=360;});state.mine.forEach(row=>{const m=state.managerRows.find(r=>r.id===row.id);if(m)row.elapsed=m.elapsed;});syncSla();render();toast('Heure serveur simulée avancée de six minutes.');});
byId('action-dialog').addEventListener('click',event=>{if(event.target===byId('action-dialog')){const r=event.target.getBoundingClientRect();if(event.clientX<r.left||event.clientX>r.right||event.clientY<r.top||event.clientY>r.bottom)event.target.close();}});
document.addEventListener('keydown',event=>{if(event.key==='Escape' && !byId('action-dialog').open && state.role==='agent' && state.agentView==='detail')agentBack();});
resetState(false);
