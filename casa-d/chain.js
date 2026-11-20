/* Casa D — cod comun pentru legătura cu blockchain-ul TRON (testnet Nile).
   Citirea se face direct din nodul public (HTTP API), fără portofel. Scrierea se face prin TronLink.
   Necesită vendor/ethers.umd.min.js (doar pentru codarea ABI și adrese) și vendor/abi.js. */
(function(){
"use strict";
var LS="casad_tron_cfg";
var CD=window.CasaD={};
var IF={};
function iface(which){
  if(!IF[which])IF[which]=new ethers.Interface(window.CASAD_ART[which==="pm"?"PredictionMarket":"MockUSDC"].abi);
  return IF[which];
}
CD.abi=function(which){return window.CASAD_ART[which==="pm"?"PredictionMarket":"MockUSDC"].abi};

/* ---- adrese TRON: base58check(0x41 + 20 octeți) ---- */
CD.toBase58=function(h){
  h=String(h).replace(/^0x/,"");
  if(h.length===40)h="41"+h;
  if(h.length!==42)throw new Error("adresa hex invalida");
  var body="0x"+h,chk=ethers.sha256(ethers.sha256(body)).slice(2,10);
  return ethers.encodeBase58(body+chk);
};
CD.toHex20=function(b58){
  var n=ethers.decodeBase58(b58),h=n.toString(16);
  while(h.length<50)h="0"+h;                       // 21 octeți + 4 octeți de control
  var body=h.slice(0,42),chk=h.slice(42);
  if(body.slice(0,2)!=="41"||ethers.sha256(ethers.sha256("0x"+body)).slice(2,10)!==chk)throw new Error("adresa invalida");
  return "0x"+body.slice(2);
};
CD.isAddr=function(a){
  if(typeof a!=="string"||!/^T[1-9A-HJ-NP-Za-km-z]{33}$/.test(a))return false;
  try{CD.toHex20(a);return true}catch(e){return false}
};
CD.short=function(a){return a.slice(0,6)+"..."+a.slice(-4)};
CD.num=function(v){return Number(ethers.formatUnits(v,6))};   // tUSDC are 6 zecimale
CD.units=function(n){return ethers.parseUnits(String(n),6)};

/* ---- configurare ---- */
// config.json este sursa oficială. Dacă nu are încă adrese, se folosesc cele salvate local de pagina de administrare.
CD.loadConfig=function(url){
  return fetch(url,{cache:"no-store"}).then(function(r){return r.json()}).then(function(cfg){
    cfg.local=false;
    if(!CD.isAddr(cfg.market)||!CD.isAddr(cfg.token)){
      try{var l=JSON.parse(localStorage.getItem(LS)||"null");
        if(l&&l.network===cfg.network&&CD.isAddr(l.market)&&CD.isAddr(l.token)){cfg.market=l.market;cfg.token=l.token;cfg.local=true}}catch(e){}
    }
    cfg.live=CD.isAddr(cfg.market)&&CD.isAddr(cfg.token);
    return cfg;
  });
};
CD.saveLocal=function(cfg){try{localStorage.setItem(LS,JSON.stringify({network:cfg.network,market:cfg.market,token:cfg.token}))}catch(e){}};
CD.clearLocal=function(){try{localStorage.removeItem(LS)}catch(e){}};

/* ---- nodul public ---- */
CD.api=function(cfg,path,body){
  return fetch(cfg.api+path,{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(body)})
    .then(function(r){if(!r.ok)throw new Error("NETWORK_ERROR "+r.status);return r.json()});
};
function hexToText(h){
  if(!h)return "";
  if(!/^[0-9a-fA-F]+$/.test(h)||h.length%2)return String(h);
  try{return ethers.toUtf8String("0x"+h)}catch(e){return String(h)}
}
function revertReason(hex){
  hex=String(hex||"").replace(/^0x/,"");
  if(hex.slice(0,8)==="08c379a0"){try{return ethers.AbiCoder.defaultAbiCoder().decode(["string"],"0x"+hex.slice(8))[0]}catch(e){}}
  if(hex.slice(0,8)==="4e487b71")return "eroare interna (panic)";
  return "";
}
function evmArgs(which,fn,args){
  var ins=iface(which).getFunction(fn).inputs;
  return (args||[]).map(function(a,i){return ins[i].type==="address"&&typeof a==="string"&&a.charAt(0)==="T"?CD.toHex20(a):a});
}
// Apel de citire (sau probă înaintea unei tranzacții, cu `from`). Întoarce rezultatul decodat.
CD.call=function(cfg,which,fn,args,from){
  var I=iface(which),f=I.getFunction(fn),addr=which==="pm"?cfg.market:cfg.token;
  return CD.api(cfg,"/wallet/triggerconstantcontract",{owner_address:from||addr,contract_address:addr,
    function_selector:f.format("sighash"),parameter:I.encodeFunctionData(f,evmArgs(which,fn,args)).slice(10),visible:true})
  .then(function(r){
    var out=r.constant_result&&r.constant_result[0]||"",reason=revertReason(out),m=r.result&&r.result.message?hexToText(r.result.message):"";
    if(reason)throw{reverted:true,reason:reason};
    if(!r.result||r.result.result!==true||/REVERT/i.test(m))throw{reverted:true,reason:m||"apel respins de nod"};
    if(!f.outputs.length)return null;
    var d=I.decodeFunctionResult(f,"0x"+out);
    return f.outputs.length===1?d[0]:d;
  });
};

/* ---- portofel (TronLink) ---- */
function provider(){return window.tronLink||window.tron||null}
function injectedTronWeb(){var p=provider();return (p&&p.tronWeb)||window.tronWeb||null}
CD.hasWallet=function(){return !!provider()};
CD.connect=function(cfg){
  var p=provider();
  if(!p)return Promise.reject(new Error("NO_WALLET"));
  var req=p===window.tronLink?p.request({method:"tron_requestAccounts"}):p.request({method:"eth_requestAccounts"});
  return Promise.resolve(req).then(function(res){
    if(res&&res.code===4001)throw{code:4001};
    if(res&&res.code===4000)throw new Error("PENDING");
    var tw=injectedTronWeb(),a=tw&&tw.defaultAddress&&tw.defaultAddress.base58;
    if(!a)throw new Error("LOCKED");
    var host=String(tw.fullNode&&tw.fullNode.host||"");
    if(cfg.hostMatch&&host.toLowerCase().indexOf(cfg.hostMatch)<0)throw new Error("WRONG_NET");
    return{tw:tw,address:a};
  });
};
CD.onWalletChange=function(cb){
  window.addEventListener("message",function(e){
    var a=e.data&&e.data.message&&e.data.message.action;
    if(a==="accountsChanged"||a==="setAccount"||a==="setNode"||a==="disconnect")cb(a);
  });
};

// Așteaptă includerea tranzacției într-un bloc și verifică rezultatul.
CD.wait=function(cfg,txid){
  var tries=0;
  return new Promise(function(resolve,reject){
    (function poll(){
      CD.api(cfg,"/wallet/gettransactioninfobyid",{value:txid}).then(function(info){
        if(info&&info.id){
          var res=info.receipt&&info.receipt.result;
          if(info.result==="FAILED"||(res&&res!=="SUCCESS")){
            var why=revertReason(info.contractResult&&info.contractResult[0])||hexToText(info.resMessage)||res||"FAILED";
            return reject({reverted:true,reason:why,receipt:res});
          }
          return resolve(info);
        }
        if(++tries>45)return reject(new Error("TIMEOUT"));
        setTimeout(poll,2000);
      }).catch(function(e){if(++tries>45)return reject(e);setTimeout(poll,2500)});
    })();
  });
};

// Tranzacție către contract: probă (ca să aflăm din timp dacă ar fi respinsă), semnare în portofel, așteptare.
CD.send=function(cfg,w,which,fn,args,onStep){
  var addr=which==="pm"?cfg.market:cfg.token;
  return CD.call(cfg,which,fn,args,w.address).then(function(){
    if(onStep)onStep("sign");
    return w.tw.contract(CD.abi(which),addr);
  }).then(function(c){
    var targs=(args||[]).map(function(a){return typeof a==="bigint"?a.toString():a});
    return c[fn].apply(c,targs).send({feeLimit:cfg.feeLimit||300000000,callValue:0,shouldPollResponse:false});
  }).then(function(txid){
    if(onStep)onStep("wait");
    return CD.wait(cfg,String(txid).replace(/^0x/,""));
  });
};

// Publicarea unui contract. Întoarce adresa (base58).
CD.deploy=function(cfg,w,name,params){
  var art=window.CASAD_ART[name];
  return w.tw.contract().new({abi:art.abi,bytecode:art.bytecode.replace(/^0x/,""),feeLimit:cfg.deployFeeLimit||1500000000,
    callValue:0,userFeePercentage:100,originEnergyLimit:10000000,parameters:params||[]})
  .then(function(c){return CD.toBase58(c.address)});
};

/* ---- mesaje pe înțeles ---- */
CD.err=function(e){
  if(!e)return "Eroare necunoscută.";
  if(typeof e==="string")e={message:e};
  var raw=[e.reason,e.message,e.error,e.receipt].filter(function(x){return typeof x==="string"}).join(" | ");
  if(e.message==="NO_WALLET")return "Nu am găsit portofelul TronLink. Instalează extensia TronLink (sau deschide pagina în browserul din aplicația TronLink).";
  if(e.message==="LOCKED")return "Deblochează TronLink și încearcă din nou.";
  if(e.message==="PENDING")return "Există deja o cerere deschisă în TronLink. Deschide portofelul și aprob-o.";
  if(e.message==="WRONG_NET")return "TronLink este pe altă rețea. Alege „Nile Testnet” din lista de rețele a portofelului și încearcă din nou.";
  if(e.message==="TIMEOUT")return "Tranzacția a fost trimisă, dar confirmarea întârzie. Reîncarcă pagina peste un minut.";
  if(e.code===4001||/declined|rejected|denied|cancel/i.test(raw))return "Ai respins cererea în portofel.";
  if(/OUT_OF_ENERGY|out of energy|feeLimit|fee limit/i.test(raw))return "Tranzacția a rămas fără energie. Ai nevoie de mai mulți TRX de test pentru taxe.";
  if(/balance is not sufficient|insufficient|Account resource|does not exist|account .* not exist/i.test(raw))return "Portofelul nu are TRX de test pentru taxa de rețea. Ia câțiva din faucet-ul Nile.";
  var known=["doar owner","comision prea mare","inchidere in trecut","fara intrebare","piata inchisa","piata rezolvata","suma zero","transfer esuat",
    "inca deschisa","deja rezolvata","rezultat invalid","prea devreme","nimic de revendicat","allowance","balance","zero address"];
  var ro={"doar owner":"Doar portofelul care a publicat contractul poate face asta.","inchidere in trecut":"Ora de închidere trebuie să fie în viitor.",
    "fara intrebare":"Scrie întrebarea.","piata inchisa":"Piața s-a închis, nu se mai pot plasa pronosticuri.","piata rezolvata":"Piața are deja rezultat.",
    "suma zero":"Suma trebuie să fie mai mare decât zero.","inca deschisa":"Piața este încă deschisă; rezultatul se introduce după ora de închidere.",
    "deja rezolvata":"Piața are deja rezultat.","prea devreme":"Se poate anula doar la 7 zile după închidere.","nimic de revendicat":"Nu ai nimic de revendicat la această piață.",
    "allowance":"Aprobarea tokenilor nu a ajuns. Încearcă din nou.","balance":"Nu ai destui tUSDC. Ia tokeni de test din robinet."};
  if(e.reverted)for(var i=0;i<known.length;i++)if(raw.indexOf(known[i])>-1)return ro[known[i]]||("Contractul a refuzat: "+known[i]+".");
  if(e.reverted)return "Contractul a refuzat operațiunea"+(e.reason?": "+String(e.reason).slice(0,120):".");
  if(/NETWORK_ERROR|Failed to fetch|NetworkError|timeout/i.test(raw))return "Nu pot ajunge la rețea. Verifică internetul și încearcă din nou.";
  return "Nu a mers: "+(raw||"eroare necunoscută").slice(0,160);
};
})();
