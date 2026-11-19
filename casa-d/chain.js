/* Casa D — cod comun pentru legătura cu blockchain-ul (testnet). Necesită vendor/ethers.umd.min.js și vendor/abi.js. */
(function(){
"use strict";
var LS="casad_cfg";
var CD=window.CasaD={};

CD.isAddr=function(a){return typeof a==="string"&&/^0x[0-9a-fA-F]{40}$/.test(a)};
CD.short=function(a){return a.slice(0,8)+"..."+a.slice(-4)};
CD.num=function(v){return Number(ethers.formatUnits(v,6))};   // tUSDC are 6 zecimale
CD.units=function(n){return ethers.parseUnits(String(n),6)};

// config.json este sursa oficială. Dacă nu are încă adrese, se folosesc cele salvate local de pagina de administrare.
CD.loadConfig=function(url){
  return fetch(url,{cache:"no-store"}).then(function(r){return r.json()}).then(function(cfg){
    cfg.local=false;
    if(!CD.isAddr(cfg.market)||!CD.isAddr(cfg.token)){
      try{var l=JSON.parse(localStorage.getItem(LS)||"null");
        if(l&&l.chainId===cfg.chainId&&CD.isAddr(l.market)&&CD.isAddr(l.token)){cfg.market=l.market;cfg.token=l.token;cfg.local=true}}catch(e){}
    }
    cfg.live=CD.isAddr(cfg.market)&&CD.isAddr(cfg.token);
    return cfg;
  });
};
CD.saveLocal=function(cfg){try{localStorage.setItem(LS,JSON.stringify({chainId:cfg.chainId,market:cfg.market,token:cfg.token}))}catch(e){}};
CD.clearLocal=function(){try{localStorage.removeItem(LS)}catch(e){}};

CD.reader=function(cfg){
  return new ethers.JsonRpcProvider(cfg.rpc,cfg.chainId,{staticNetwork:ethers.Network.from(cfg.chainId),batchMaxCount:1,cacheTimeout:-1});
};
CD.contracts=function(cfg,runner){
  return{
    pm:new ethers.Contract(cfg.market,window.CASAD_ART.PredictionMarket.abi,runner),
    token:new ethers.Contract(cfg.token,window.CASAD_ART.MockUSDC.abi,runner)
  };
};

CD.hasWallet=function(){return !!window.ethereum};

// Conectează portofelul și îl trece pe rețeaua de test.
CD.connect=function(cfg){
  if(!window.ethereum)return Promise.reject(new Error("NO_WALLET"));
  var eth=window.ethereum, hexId="0x"+cfg.chainId.toString(16);
  return eth.request({method:"eth_requestAccounts"}).then(function(){
    return eth.request({method:"wallet_switchEthereumChain",params:[{chainId:hexId}]}).catch(function(e){
      if(e&&(e.code===4902||(e.data&&e.data.originalError&&e.data.originalError.code===4902)||/Unrecognized chain/i.test(e.message||""))){
        return eth.request({method:"wallet_addEthereumChain",params:[{chainId:hexId,chainName:cfg.chainName,
          nativeCurrency:{name:"Ether",symbol:"ETH",decimals:18},rpcUrls:[cfg.rpc],blockExplorerUrls:[cfg.explorer]}]});
      }
      throw e;
    });
  }).then(function(){
    var provider=new ethers.BrowserProvider(eth,cfg.chainId);
    return provider.getSigner().then(function(signer){
      return signer.getAddress().then(function(address){return{provider:provider,signer:signer,address:address}});
    });
  });
};

// Mesaj pe înțeles pentru erorile de portofel / contract.
CD.err=function(e){
  if(!e)return "Eroare necunoscută.";
  var raw=[e.reason,e.shortMessage,e.message,e.info&&e.info.error&&e.info.error.message,e.data&&e.data.message,e.error&&e.error.message].filter(Boolean).join(" | ");
  if(e.message==="NO_WALLET")return "Nu am găsit un portofel. Instalează MetaMask (sau deschide pagina în browserul din aplicația MetaMask).";
  if(e.code===4001||e.code==="ACTION_REJECTED"||/user rejected|user denied/i.test(raw))return "Ai respins cererea în portofel.";
  if(e.code==="INSUFFICIENT_FUNDS"||/insufficient funds/i.test(raw))return "Nu ai destul ETH de test pentru taxa de rețea. Ia câteva dintr-un faucet Base Sepolia.";
  var known=["doar owner","comision prea mare","inchidere in trecut","fara intrebare","piata inchisa","piata rezolvata","suma zero","transfer esuat",
    "inca deschisa","deja rezolvata","rezultat invalid","prea devreme","nimic de revendicat","allowance","balance","zero address"];
  var ro={"doar owner":"Doar portofelul care a publicat contractul poate face asta.","inchidere in trecut":"Ora de închidere trebuie să fie în viitor.",
    "fara intrebare":"Scrie întrebarea.","piata inchisa":"Piața s-a închis, nu se mai pot plasa pronosticuri.","piata rezolvata":"Piața are deja rezultat.",
    "suma zero":"Suma trebuie să fie mai mare decât zero.","inca deschisa":"Piața este încă deschisă; rezultatul se introduce după ora de închidere.",
    "deja rezolvata":"Piața are deja rezultat.","prea devreme":"Se poate anula doar la 7 zile după închidere.","nimic de revendicat":"Nu ai nimic de revendicat la această piață.",
    "allowance":"Aprobarea tokenilor nu a ajuns. Încearcă din nou.","balance":"Nu ai destui tUSDC. Ia tokeni de test din robinet."};
  for(var i=0;i<known.length;i++)if(raw.indexOf(known[i])>-1)return ro[known[i]]||("Contractul a refuzat: "+known[i]+".");
  if(/network|fetch|timeout|ECONN|NETWORK_ERROR/i.test(raw))return "Nu pot ajunge la rețea. Verifică internetul și încearcă din nou.";
  return "Nu a mers: "+(e.shortMessage||e.message||"eroare necunoscută").slice(0,160);
};
})();
