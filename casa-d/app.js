/* Casa D — pagina explorer. Mod DEMO (date simulate) cât timp config.json nu are adrese de contract; altfel mod LIVE (testnet). */
(function(){
"use strict";
var $=function(id){return document.getElementById(id)};
var CD=window.CasaD;
var fmt=new Intl.NumberFormat("ro-RO",{maximumFractionDigits:0});
var fmt2=new Intl.NumberFormat("ro-RO",{minimumFractionDigits:2,maximumFractionDigits:2});
var DAY=864e5;
function esc(s){return String(s).replace(/[&<>"]/g,function(c){return{"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]})}
var B58="123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";
function fakeAddr(){var s="T";while(s.length<34)s+=B58.charAt(Math.floor(Math.random()*58));return s}

// Starea afișată. Aceeași formă în demo și live.
// market: {id,n,cat,q,close(ms),yes,no,status:"open"|"closed"|"yes"|"no"|"invalid",my:{yes,no,due,done}|null}
// bet:    {n,t(ms),a,m(market),side,amt,fresh}
var S={live:false,fee:0.02,markets:[],bets:[],betCount:0,volume:0,wallets:0,me:null,balance:0};
var cfg=null,wallet=null,filter="",busy=false;

/* ---------- afișare ---------- */
function age(t){var s=Math.max(1,Math.round((Date.now()-t)/1000));
  if(s<60)return "acum "+s+"s"; if(s<3600)return "acum "+Math.floor(s/60)+" min";
  if(s<86400)return "acum "+Math.floor(s/3600)+" h"; return "acum "+Math.floor(s/86400)+" zile"}
function closeTxt(m){
  var d=(m.close-Date.now())/DAY;
  if(d>=0&&d<1/24)return "în "+Math.max(1,Math.round(d*1440))+" min";
  if(d>=0&&d<1)return "în "+Math.round(d*24)+" h";
  if(d>=1&&d<60)return "în "+Math.round(d)+" zile";
  return new Date(m.close).toLocaleDateString("ro-RO",{day:"numeric",month:"short",year:"numeric"});
}
function pct(m){var t=m.yes+m.no;return t>0?m.yes/t*100:50}
// cota = cât primește un câștigător la 1 tUSDC mizat (comisionul se ia doar din potul pierzător)
function odds(m,yes){var win=yes?m.yes:m.no,lose=yes?m.no:m.yes;return win>0?fmt2.format(1+lose*(1-S.fee)/win):"—"}
function match(s){return !filter||s.toLowerCase().indexOf(filter)>-1}
var STATUS={open:'<span class="pill o">Deschisă</span>',closed:'<span class="pill c">Închisă · așteaptă rezultatul</span>',
  yes:'<span class="pill c">Rezolvată: DA</span>',no:'<span class="pill c">Rezolvată: NU</span>',invalid:'<span class="pill c">Anulată · mize returnate</span>'};

function actionCell(m){
  if(m.status==="open")return '<button class="btn sm y" data-bet="'+m.id+'" data-side="1">DA</button><button class="btn sm n" data-bet="'+m.id+'" data-side="0">NU</button>';
  if(m.my&&m.my.due>0)return '<button class="btn sm gold" data-claim="'+m.id+'">Revendică '+fmt2.format(m.my.due)+'</button>';
  if(m.my&&m.my.done)return '<span class="muted">Revendicat</span>';
  return '<span class="muted">—</span>';
}
function mineLine(m){
  if(!m.my||(m.my.yes<=0&&m.my.no<=0))return "";
  var p=[];if(m.my.yes>0)p.push("DA "+fmt2.format(m.my.yes));if(m.my.no>0)p.push("NU "+fmt2.format(m.my.no));
  return '<span class="mine num">Miza ta: '+p.join(" · ")+' tUSDC</span>';
}

function render(){
  var sorted=S.markets.slice().sort(function(a,b){return(b.yes+b.no)-(a.yes+a.no)});
  var open=sorted.filter(function(m){return m.status==="open"});
  $("betCount").textContent=fmt.format(S.betCount);
  $("sOpen").textContent=open.length;
  $("sVol").textContent=fmt.format(S.volume);
  $("sWal").textContent=fmt.format(S.wallets);

  $("feat").innerHTML=open.slice(0,3).map(function(m){
    var p=pct(m);
    return '<article class="card fm"><span class="cat">'+esc(m.cat||"FOTBAL")+'</span><h4>'+esc(m.q)+'</h4>'+
      '<div class="split"><i style="width:'+p.toFixed(1)+'%"></i></div>'+
      '<div class="row num"><b>DA '+p.toFixed(0)+'%</b><b>NU '+(100-p).toFixed(0)+'%</b></div>'+
      '<div class="meta num">Pot '+fmt.format(m.yes+m.no)+' tUSDC · se închide '+closeTxt(m)+'</div></article>';
  }).join("");

  var rows=sorted.filter(function(m){return match(m.q+" "+m.cat)}).map(function(m){
    return '<tr><td class="muted num">#'+m.n+'</td><td class="q">'+esc(m.q)+mineLine(m)+'<span class="mact">'+actionCell(m)+'</span></td><td>'+STATUS[m.status]+'</td><td class="num">'+closeTxt(m)+
      '</td><td class="num"><b>'+pct(m).toFixed(0)+'%</b></td><td class="num">'+odds(m,true)+' / '+odds(m,false)+
      '</td><td class="num">'+fmt.format(m.yes+m.no)+' <span class="muted">tUSDC</span></td><td class="act">'+actionCell(m)+'</td></tr>';
  });
  $("tM").innerHTML=rows.join("")||'<tr><td colspan="8" class="empty">'+(S.markets.length?"Nicio piață nu se potrivește căutării.":"Încă nu există piețe. Prima apare imediat ce este creată.")+'</td></tr>';

  var bl=S.bets.filter(function(b){return match(b.a+" "+b.m.q)}).slice(0,12).map(function(b){
    var r='<tr'+(b.fresh?' class="new"':'')+'><td class="muted num">#'+fmt.format(b.n)+'</td><td class="muted num" data-t="'+b.t+'">'+age(b.t)+
      '</td><td class="addr">'+CD.short(b.a)+'</td><td class="q">'+esc(b.m.q)+'</td><td><span class="pill '+(b.side?"y":"n")+'">'+(b.side?"DA":"NU")+
      '</span></td><td class="num">'+fmt2.format(b.amt)+' <span class="muted">tUSDC</span></td></tr>';
    b.fresh=false; return r;
  });
  $("tB").innerHTML=bl.join("")||'<tr><td colspan="6" class="empty">'+(S.bets.length?"Nicio miză nu se potrivește căutării.":"Încă nu s-a plasat niciun pronostic.")+'</td></tr>';

  var l=S.bets[0];
  $("lAddr").textContent=l?CD.short(l.a):"—";
  $("lSide").innerHTML=l?'<span class="pill '+(l.side?"y":"n")+'">'+(l.side?"DA":"NU")+'</span>':"—";
  $("lAmt").textContent=l?fmt2.format(l.amt)+" tUSDC":"—";
  $("lMkt").textContent=l?"#"+l.m.n+(l.m.cat?" · "+l.m.cat:""):"—";

  var slice=S.bets.slice(0,60).reverse();
  var mx=slice.length?Math.log(1+Math.max.apply(null,slice.map(function(b){return b.amt}))):1;
  $("bars").innerHTML=slice.map(function(b){
    return '<i class="'+(b.side?"":"n")+'" style="height:'+Math.max(8,Math.log(1+b.amt)/mx*100).toFixed(0)+'%"></i>'}).join("");

  if(S.live){
    $("walWho").hidden=!S.me; $("btnFaucet").hidden=!S.me; $("btnConnect").hidden=!!S.me;
    if(S.me)$("walWho").innerHTML='<b class="mono">'+CD.short(S.me)+'</b> · <b class="num">'+fmt2.format(S.balance)+'</b> tUSDC';
  }
  if($("dlg").open)updateEstimate();
}

var toastT;
function toast(msg,bad){var t=$("toast");t.textContent=msg;t.className="toast"+(bad?" bad":"");t.hidden=false;clearTimeout(toastT);toastT=setTimeout(function(){t.hidden=true},bad?7000:4500)}

/* ---------- cadranul ---------- */
var prog=$("prog"),C=628.3,nextAt=0,started=0,onDue=function(){},dueLabel="";
function schedule(ms){started=Date.now();nextAt=started+ms}
setInterval(function(){
  var t=Date.now();
  if(nextAt&&t>=nextAt){nextAt=0;onDue()}
  if(nextAt){
    prog.style.strokeDashoffset=(C*(1-Math.min(1,(t-started)/(nextAt-started)))).toFixed(1);
    $("betSub").textContent=dueLabel+" ~"+Math.max(0,Math.ceil((nextAt-t)/1000))+"s";
  }
},100);
setInterval(function(){
  var c=document.querySelectorAll("[data-t]");
  for(var i=0;i<c.length;i++)c[i].textContent=age(+c[i].getAttribute("data-t"));
},1000);
$("q").addEventListener("input",function(e){filter=e.target.value.trim().toLowerCase();render()});

/* ---------- mod DEMO ---------- */
function startDemo(){
  var now=Date.now();
  S.markets=[
   ["SUPERLIGA","Campioana SuperLigii 2026-27 va fi o echipă din București?",190,.52],
   ["NAȚIONALA","România se califică la EURO 2028?",480,.63],
   ["LIGA CAMPIONILOR","Finala Ligii Campionilor 2027 se decide la penalty-uri?",192,.16],
   ["SUPERLIGA","Golgheterul SuperLigii 2026-27 marchează cel puțin 20 de goluri?",185,.31],
   ["CUPA ROMÂNIEI","Finala Cupei României 2027 are peste 2,5 goluri?",178,.46],
   ["LIGA CAMPIONILOR","O echipă din Anglia câștigă Liga Campionilor 2026-27?",192,.38],
   ["EUROPA","O echipă românească ajunge în primăvara europeană 2026-27?",28,.44],
   ["SUPERLIGA","O nou-promovată termină SuperLiga 2026-27 în play-off?",120,.22],
   ["NAȚIONALA","România câștigă primul meci oficial din 2027?",125,.57],
   ["LIGA CAMPIONILOR","Se marchează peste 3,5 goluri în finala Ligii Campionilor 2027?",192,.29]
  ].map(function(m,i){
    var pot=3000+Math.random()*42000*(i<4?1.6:1);
    return{id:i,n:i+1,cat:m[0],q:m[1],close:now+m[2]*DAY+Math.random()*DAY,yes:pot*m[3],no:pot*(1-m[3]),status:"open",my:null};
  });
  S.markets.push({id:10,n:11,cat:"TEST",q:"Piață de test: se marchează în prima repriză?",close:now-40*DAY,yes:9120,no:6480,status:"yes",my:null});
  S.markets.push({id:11,n:12,cat:"TEST",q:"Piață de test: meciul se termină egal?",close:now-12*DAY,yes:14300,no:18750,status:"no",my:null});

  var wallets=[],seen={};for(var w=0;w<140;w++)wallets.push(fakeAddr());
  S.betCount=18342+Math.floor(Math.random()*400);
  S.volume=612400;S.markets.forEach(function(m){S.volume+=m.yes+m.no});
  function pick(){
    var open=S.markets.filter(function(m){return m.status==="open"}),tot=0,r;
    open.forEach(function(m){tot+=Math.sqrt(m.yes+m.no)});
    r=Math.random()*tot;
    for(var i=0;i<open.length;i++){r-=Math.sqrt(open[i].yes+open[i].no);if(r<=0)return open[i]}
    return open[0];
  }
  function makeBet(t){
    var m=pick(),p=m.yes/(m.yes+m.no),side=Math.random()<(p*.8+.1);
    var amt=Math.max(1,Math.round(Math.exp(2.2+Math.random()*3.6)*100)/100);
    if(side)m.yes+=amt;else m.no+=amt;
    var a=wallets[Math.floor(Math.pow(Math.random(),1.6)*wallets.length)];
    seen[a]=1;S.betCount++;S.volume+=amt;S.wallets=1184+Object.keys(seen).length;
    S.bets.unshift({n:S.betCount,t:t||Date.now(),a:a,m:m,side:side,amt:amt,fresh:!t});
    if(S.bets.length>60)S.bets.pop();
  }
  for(var k=40;k>=1;k--)makeBet(Date.now()-k*4200-Math.random()*2500);
  dueLabel="următoarea în";
  onDue=function(){makeBet();render();schedule(2200+Math.random()*4300)};
  schedule(2200+Math.random()*4300);
  render();
}

/* ---------- mod LIVE ---------- */
var POLL=6000,lastCount=-1;
function refresh(){
  var me=S.me;
  var calls=[CD.call(cfg,"pm","getMarkets"),CD.call(cfg,"pm","getRecentBets",[60]),CD.call(cfg,"pm","betCount"),CD.call(cfg,"pm","bettorCount"),CD.call(cfg,"pm","totalVolume")];
  if(me){calls.push(CD.call(cfg,"pm","positions",[me]));calls.push(CD.call(cfg,"token","balanceOf",[me]))}
  return Promise.all(calls).then(function(r){
    var now=Date.now(),pos=me&&S.me===me?r[5]:null;
    S.markets=r[0].map(function(m,i){
      var o=Number(m.outcome),close=Number(m.closeTime)*1000;
      return{id:i,n:i+1,cat:m.category,q:m.question,close:close,yes:CD.num(m.yesPool),no:CD.num(m.noPool),
        status:o===1?"yes":o===2?"no":o===3?"invalid":(now<close?"open":"closed"),
        my:pos?{yes:CD.num(pos.yes[i]),no:CD.num(pos.no[i]),due:CD.num(pos.due[i]),done:pos.done[i]}:null};
    });
    var count=Number(r[2]);
    S.bets=r[1].map(function(b,i){
      var n=count-i;
      return{n:n,t:Number(b.time)*1000,a:CD.toBase58(b.user),m:S.markets[Number(b.marketId)],side:b.yes,amt:CD.num(b.amount),fresh:lastCount>=0&&n>lastCount};
    });
    lastCount=count;S.betCount=count;S.wallets=Number(r[3]);S.volume=CD.num(r[4]);
    if(pos)S.balance=CD.num(r[6]);
    setBanner(false);render();
  }).catch(function(e){setBanner(true);if(window.console)console.warn("Casa D: citire eșuată",e)});
}
function setBanner(bad){
  var b=$("banner");b.className="demo live";
  b.innerHTML=bad?'TESTNET <span>· nu pot citi rețeaua '+esc(cfg.chainName)+' acum; reîncerc automat</span>'
    :'TESTNET · '+esc(cfg.chainName)+' <span>· pronosticuri reale pe blockchain, cu tokeni de test fără valoare · fără bani reali'+(cfg.local?' · contract salvat doar în acest browser':'')+'</span>';
}
function startLive(){
  S.live=true;
  $("walbar").hidden=false;
  $("footL").innerHTML='Casa D · proiect experimental de <a href="/">Daniel Drăghicioiu</a>. Rulează pe rețeaua de test '+esc(cfg.chainName)+'; tokenii tUSDC nu au nicio valoare.';
  $("footR").innerHTML='Contract: <a class="mono" target="_blank" rel="noopener" href="'+esc(cfg.explorer)+'/contract/'+cfg.market+'">'+CD.short(cfg.market)+'</a> · neauditat';
  dueLabel="actualizare în";
  onDue=function(){refresh().then(function(){schedule(POLL)})};
  CD.call(cfg,"pm","feeBps").then(function(f){S.fee=Number(f)/10000}).catch(function(){}).then(function(){return refresh()}).then(function(){schedule(POLL)});
  CD.onWalletChange(function(){if(wallet){wallet=null;S.me=null;render()}});
}

function connect(silent){
  return CD.connect(cfg).then(function(w){wallet=w;S.me=w.address;return refresh()}).then(function(){return wallet})
    .catch(function(e){if(!silent)toast(CD.err(e),true);throw e});
}
function ensureWallet(){return wallet?Promise.resolve(wallet):connect(true)}
function lock(on){busy=on;$("btnFaucet").disabled=on;$("dGo").disabled=on||!S.live}

$("btnConnect").addEventListener("click",function(){connect().catch(function(){})});
$("btnFaucet").addEventListener("click",function(){
  if(busy)return;lock(true);toast("Confirmă în portofel…");
  ensureWallet().then(function(w){return CD.send(cfg,w,"token","faucet",[],function(st){if(st==="wait")toast("Se trimit tokenii de test…")})})
    .then(function(){return refresh()}).then(function(){toast("Ai primit 1.000 tUSDC de test.")})
    .catch(function(e){toast(CD.err(e),true)}).then(function(){lock(false)});
});

/* ---------- fereastra de pronostic ---------- */
var D={m:null,side:true};
function dmsg(t,bad){var e=$("dMsg");e.textContent=t||"";e.className="dmsg"+(bad?" bad":"")}
function setSide(yes){D.side=yes;$("dYes").classList.toggle("on",yes);$("dNo").classList.toggle("on",!yes);updateEstimate()}
function updateEstimate(){
  var m=D.m&&S.markets[D.m.id]||D.m;if(!m)return;
  var a=parseFloat($("dAmt").value);
  if(!(a>0)){$("dEst").textContent="Scrie suma pe care vrei să o pui.";return}
  var win=(D.side?m.yes:m.no)+a,lose=D.side?m.no:m.yes,pay=a+lose*(1-S.fee)*a/win;
  $("dEst").innerHTML='Dacă iese <b>'+(D.side?"DA":"NU")+'</b>, primești aproximativ <b>'+fmt2.format(pay)+' tUSDC</b> (cota '+fmt2.format(pay/a)+
    '). Suma finală depinde de mizele puse până la închidere, dar nu scade sub miza ta.';
}
function openBet(id,yes){
  var m=S.markets[id];if(!m)return;
  D.m=m;$("dCat").textContent=m.cat||"FOTBAL";$("dQ").textContent=m.q;
  dmsg(S.live?"":"Aceasta este versiunea demo: plasarea devine activă după publicarea contractului pe testnet.");
  $("dGo").disabled=!S.live||busy;
  setSide(yes);$("dlg").showModal();
}
$("dYes").addEventListener("click",function(){setSide(true)});
$("dNo").addEventListener("click",function(){setSide(false)});
$("dAmt").addEventListener("input",updateEstimate);
$("dCancel").addEventListener("click",function(){$("dlg").close()});
document.querySelectorAll("#dlg [data-a]").forEach(function(b){b.addEventListener("click",function(){$("dAmt").value=b.getAttribute("data-a");updateEstimate()})});

$("dGo").addEventListener("click",function(){
  if(busy||!S.live||!D.m)return;
  var a=parseFloat($("dAmt").value),amt,id=D.m.id,side=D.side;
  if(!(a>0)){dmsg("Scrie o sumă mai mare decât zero.",true);return}
  try{amt=CD.units(a.toFixed(6))}catch(e){dmsg("Sumă nevalidă.",true);return}
  lock(true);dmsg("Conectez portofelul…");
  var w;
  ensureWallet().then(function(x){
    w=x;
    return Promise.all([CD.call(cfg,"token","balanceOf",[w.address]),CD.call(cfg,"token","allowance",[w.address,cfg.market])]);
  }).then(function(r){
    if(r[0]<amt)throw{friendly:"Ai doar "+fmt2.format(CD.num(r[0]))+" tUSDC. Apasă „+ 1.000 tUSDC de test” și încearcă din nou."};
    if(r[1]>=amt)return;
    dmsg("Pasul 1 din 2: aprobă suma în portofel…");
    return CD.send(cfg,w,"token","approve",[cfg.market,amt],function(st){if(st==="wait")dmsg("Pasul 1 din 2: se confirmă aprobarea…")});
  }).then(function(){
    dmsg("Confirmă pronosticul în portofel…");
    return CD.send(cfg,w,"pm","bet",[id,side,amt],function(st){if(st==="wait")dmsg("Se înregistrează pe blockchain…")});
  })
  .then(function(){return refresh()})
  .then(function(){$("dlg").close();toast("Pronostic plasat: "+(side?"DA":"NU")+" cu "+fmt2.format(a)+" tUSDC.")})
  .catch(function(e){dmsg(e&&e.friendly||CD.err(e),true)})
  .then(function(){lock(false)});
});

document.addEventListener("click",function(e){
  var b=e.target.closest&&e.target.closest("[data-bet],[data-claim]");if(!b)return;
  if(b.hasAttribute("data-bet")){openBet(+b.getAttribute("data-bet"),b.getAttribute("data-side")==="1");return}
  if(busy)return;
  var id=+b.getAttribute("data-claim");lock(true);toast("Confirmă în portofel…");
  ensureWallet().then(function(w){return CD.send(cfg,w,"pm","claim",[id],function(st){if(st==="wait")toast("Se trimite câștigul…")})})
    .then(function(){return refresh()}).then(function(){toast("Suma a ajuns în portofelul tău.")})
    .catch(function(e){toast(CD.err(e),true)}).then(function(){lock(false)});
});

/* ---------- pornire ---------- */
CD.loadConfig("config.json").then(function(c){cfg=c;if(c.live&&window.ethers&&window.CASAD_ART)startLive();else startDemo()})
  .catch(function(){startDemo()});
})();
