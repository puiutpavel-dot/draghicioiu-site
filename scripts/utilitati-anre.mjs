// Comparator utilități – preia zilnic ofertele de curent și gaze din comparatorul oficial ANRE (posf.ro)
// și construiește tabelul cod poștal → localitate → rețea de gaz.
// Rulează în GitHub Actions (.github/workflows/utilitati-anre.yml). Node 20+, fără dependențe.
//
// Scrie în comparator-utilitati/:
//   anre.json            oferte curent pe zone de distribuție + oferte gaz pe județ (zilnic)
//   gaz-localitati.json  localitățile cu rețea de gaz și tariful de distribuție al fiecăreia (o dată pe săptămână)
//   cp/<NN>.json         coduri poștale pe județ (primele 2 cifre) → [localitate, siruta ANRE] (o dată pe săptămână)
//
// Codurile poștale vin din GeoNames (CC BY 4.0, www.geonames.org).

import { readFile, writeFile, rename, mkdir } from "node:fs/promises";
import { inflateRawSync } from "node:zlib";

const DIR = new URL("../comparator-utilitati/", import.meta.url);
const API = "https://posf.ro/api/v1/comparator";
const UA = "Mozilla/5.0 (compatible; draghicioiu.ro comparator utilitati; +https://draghicioiu.ro/comparator-utilitati/)";
const CONSUM_REF = 175; // kWh/lună pentru cererea de curent; prețul variabil nu depinde de consum
const TVA_DEFAULT = 21;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (...a) => console.log(...a);
const fortat = process.argv.includes("--complet");

async function http(url, { tries = 3, json = true } = {}) {
  for (let i = 1; i <= tries; i++) {
    try {
      const r = await fetch(url, { headers: { "User-Agent": UA, Accept: json ? "application/json" : "*/*", Referer: "https://posf.ro/comparator" }, signal: AbortSignal.timeout(45000) });
      if (r.ok) return json ? await r.json() : Buffer.from(await r.arrayBuffer());
      log(`  HTTP ${r.status} ${url.slice(0, 140)}`);
    } catch (e) {
      log(`  eroare (${i}/${tries}) ${url.slice(0, 140)}: ${e.message}`);
    }
    await sleep(1500 * i);
  }
  return null;
}

const azi = new Date(Date.now() + 3 * 3600e3); // ora României (aprox.)
const dd = (n) => String(n).padStart(2, "0");
const ziPosf = `${dd(azi.getUTCDate())}-${dd(azi.getUTCMonth() + 1)}-${azi.getUTCFullYear()}`;
const ziIso = azi.toISOString().slice(0, 10);
const isoDin = (s) => { const m = String(s || "").match(/(\d{2})\.(\d{2})\.(\d{4})/); return m ? `${m[3]}-${m[2]}-${m[1]}` : null; };
const r4 = (v) => Math.round(v * 10000) / 10000;
const r2 = (v) => Math.round(v * 100) / 100;
const num = (v) => { const n = parseFloat(String(v ?? "").replace(",", ".")); return Number.isFinite(n) ? n : 0; };
const curat = (s) => String(s || "").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim();
const norm = (s) => String(s || "").normalize("NFD").replace(/[̀-ͯ]/g, "")
  .replace(/[şș]/gi, "s").replace(/[ţț]/gi, "t").toUpperCase().replace(/[^A-Z0-9]+/g, " ").trim();
const link = (s) => { const u = curat(s); return /^https?:\/\/[^\s]+\.[^\s]+$/i.test(u) && !/\s/.test(u) ? u : null; };

async function citesteJson(nume) { try { return JSON.parse(await readFile(new URL(nume, DIR), "utf8")); } catch { return null; } }
async function scrieJson(nume, data) {
  const f = new URL(nume, DIR), tmp = new URL(nume + ".tmp", DIR);
  await writeFile(tmp, JSON.stringify(data));
  await rename(tmp, f);
}

// ---------------- CURENT ----------------
async function curent() {
  const judete = await http(`${API}?request=get-judete`);
  if (!Array.isArray(judete) || !judete.length) throw new Error("get-judete a eșuat");
  const zone = new Map(judete.map((j) => [j.id_zona, j.nume_zona]));
  const out = {};
  for (const [id, zona] of zone) {
    const q = new URLSearchParams({
      request: "comparator-electric", tip_oferta: "0", data_start_aplicare: ziPosf, tip_client: "casnic", tip_pret: "nediferentiat",
      consum_anual: String(CONSUM_REF * 12), consum_lunar: String(CONSUM_REF), valoare_factura_curenta: "", nivel_tensiune: "JT_",
      id_zona: String(id), tip_produs: "0", perioada_contract: "", energie_regenerabila: "", factura_electronica: "",
      frecventa_emitere_factura: "", procent_zona_noapte: "", procent_zona_zi: "", frecventa_citire_contor: "", valoare_fixa: "", denumire_furnizor: "",
    });
    const lista = await http(`${API}?${q}`);
    if (!Array.isArray(lista)) { log(`Curent/${zona}: fără răspuns`); continue; }
    const vazute = new Set();
    const oferte = [];
    for (const o of lista) {
      if (String(o.tip_pret_oferta || "").toLowerCase().startsWith("diferentiat")) continue;
      const tva = num(o.tva) || TVA_DEFAULT;
      // preț variabil final lei/kWh = energie + tarife reglementate + taxe, cu TVA
      const pret = (num(o.pret_energie) + num(o.tarif_transport_tl) + num(o.tarif_serviciu_sistem) + num(o.tarif_serviciu_distributie)
        + num(o.taxa_cogenerare_inalta_eficienta) + num(o.contravaloare_certificate_verzi) + num(o.acciza)) * (1 + tva / 100);
      const p = pret > 0.3 ? pret : num(o.pret_final);
      if (!(p > 0)) continue;
      const cheie = `${o.cod_oferta || o.id_oferta}`;
      if (vazute.has(cheie)) continue;
      vazute.add(cheie);
      oferte.push({
        f: curat(o.nume_furnizor), o: curat(o.denumire_oferta), c: curat(o.cod_oferta) || String(o.id_oferta),
        p: r4(p), fz: r2(num(o.valoare_componenta_fixa) * 30 * (1 + tva / 100)), // componenta fixă: lei/zi fără TVA → lei/lună cu TVA
        tip: curat(o.tip_produs), su: /universal/i.test(o.tip_oferta || ""),
        pana: isoDin(o.valabilitate_oferta_stop), dist: r4(num(o.tarif_serviciu_distributie)),
        durata: curat(o.perioada_contract).replace(/^[a-z]\.\s*/i, ""), link: link(o.legatura_oferta) || link(o.furnizor?.website && `https://${String(o.furnizor.website).replace(/^https?:\/\//, "")}`),
        pdf: link(o.oferta_pdf ? encodeURI(o.oferta_pdf) : ""),
      });
    }
    oferte.sort((a, b) => (a.p + a.fz / CONSUM_REF) - (b.p + b.fz / CONSUM_REF));
    out[zona] = oferte.slice(0, 30);
    log(`Curent/${zona}: ${oferte.length} oferte, cea mai ieftină ${oferte[0]?.f} ${oferte[0]?.p}`);
    await sleep(600);
  }
  return { zone: out, judete: judete.map((j) => ({ n: j.nume, zona: j.nume_zona })) };
}

// ---------------- GAZ ----------------
const qGaz = (judet, siruta) => `${API}?` + new URLSearchParams({
  request: "comparator-gaz", tip_client: "casnic", modalitate_racordare: "sistem_de_distributie", transee_de_consum: "b1",
  tip_pret_unitar: "cu_reglementate", id_judet: judet, id_siruta: String(siruta), consum_mwh: "1", pret_furnizare_mwh: "",
  componenta_fixa: "", suplimentar_componenta_fixa: "", termen_plata: "", tip_oferta: "", tip_pret: "", durata_contractului: "",
  garantii: "", frecventa_emitere_factura: "", data_start_aplicare: ziPosf,
});

async function localitatiGaz() {
  const judete = await http(`${API}?request=get-judete-gaz`);
  if (!Array.isArray(judete)) throw new Error("get-judete-gaz a eșuat");
  const rez = {};
  for (const j of judete) {
    const cheie = j.nume.toUpperCase();
    const L = await http(`${API}?request=get-localitati&judet=${encodeURIComponent(cheie)}`);
    rez[cheie] = (Array.isArray(L) ? L : L ? [L] : []).map((l) => ({ s: l.siruta, n: curat(l.localitate_apartinatoare), pr: curat(l.localitate_principala) }));
    await sleep(250);
  }
  return rez;
}

/** Ofertele de gaz pentru o localitate: [{oferta}, t0] */
async function oferteGaz(judet, siruta) {
  const lista = await http(qGaz(judet, siruta));
  if (!Array.isArray(lista)) return null;
  return lista;
}

/** Rulează fn pe toate elementele, câte `n` deodată. */
async function paralel(items, n, fn) {
  let i = 0;
  await Promise.all(Array.from({ length: n }, async () => {
    while (i < items.length) { const k = i++; await fn(items[k], k); }
  }));
}

// ---------------- CODURI POȘTALE (GeoNames) ----------------
function dezarhiveaza(buf, fisier) {
  let eocd = buf.length - 22;
  while (eocd > 0 && buf.readUInt32LE(eocd) !== 0x06054b50) eocd--;
  const n = buf.readUInt16LE(eocd + 10);
  let cd = buf.readUInt32LE(eocd + 16);
  for (let i = 0; i < n; i++) {
    const metoda = buf.readUInt16LE(cd + 10), csize = buf.readUInt32LE(cd + 20);
    const nlen = buf.readUInt16LE(cd + 28), elen = buf.readUInt16LE(cd + 30), clen = buf.readUInt16LE(cd + 32), lho = buf.readUInt32LE(cd + 42);
    const nume = buf.toString("utf8", cd + 46, cd + 46 + nlen);
    if (nume === fisier) {
      const start = lho + 30 + buf.readUInt16LE(lho + 26) + buf.readUInt16LE(lho + 28);
      const date = buf.subarray(start, start + csize);
      return (metoda === 8 ? inflateRawSync(date) : date).toString("utf8");
    }
    cd += 46 + nlen + elen + clen;
  }
  throw new Error(`${fisier} lipsește din arhivă`);
}

async function coduriPostale() {
  const zip = await http("https://download.geonames.org/export/zip/RO.zip", { json: false });
  if (!zip) return null;
  return dezarhiveaza(zip, "RO.txt").trim().split("\n").map((l) => l.split("\t"))
    .filter((r) => /^\d{6}$/.test(r[1])).map((r) => ({ cp: r[1], loc: r[2], judet: r[3] }));
}

// ---------------- RULARE ----------------
await mkdir(new URL("cp/", DIR), { recursive: true });
const vechi = (await citesteJson("anre.json")) || {};
const rez = { actualizat: new Date().toISOString(), zi: ziIso, sursa: "posf.ro (ANRE)", consum_ref: CONSUM_REF };

// 1) Curent
try {
  const c = await curent();
  const nr = Object.values(c.zone).reduce((s, l) => s + l.length, 0);
  if (nr >= 8) { rez.curent = c.zone; rez.judete_curent = c.judete; }
  else throw new Error(`prea puține oferte (${nr})`);
} catch (e) {
  log("Curent: păstrez datele vechi –", e.message);
  rez.curent = vechi.curent; rez.judete_curent = vechi.judete_curent; rez.curent_vechi = true;
}

// 2) Localități gaz + coduri poștale (săptămânal sau la cerere)
let loc = await citesteJson("gaz-localitati.json");
const vechimeZile = loc?.actualizat ? (Date.now() - Date.parse(loc.actualizat)) / 864e5 : 999;
const complet = fortat || vechimeZile > 6.5;
if (complet) {
  log("Actualizare completă: localități gaz + tarife de distribuție + coduri poștale");
  const L = await localitatiGaz();
  const toate = Object.entries(L).flatMap(([j, arr]) => arr.map((l) => ({ j, ...l })));
  log(`Localități cu rețea de gaz: ${toate.length}`);
  const t0 = new Map();
  const oferteJudet = {};
  await paralel(toate, 3, async (l, k) => {
    const lista = await oferteGaz(l.j, l.s);
    if (lista?.length) {
      const v = lista.map((o) => num(o.t0)).filter((x) => x > 0);
      if (v.length) t0.set(`${l.j}|${l.s}`, r2(v.sort((a, b) => a - b)[Math.floor(v.length / 2)]));
      if (!oferteJudet[l.j] || lista.length > oferteJudet[l.j].length) oferteJudet[l.j] = lista;
    }
    if (k % 250 === 0) log(`  ${k}/${toate.length}`);
    await sleep(120);
  });
  const judeteGaz = {};
  for (const [j, arr] of Object.entries(L)) {
    judeteGaz[j] = arr.map((l) => [l.s, l.n, l.pr, t0.get(`${j}|${l.s}`) ?? null]);
  }
  log(`Tarife de distribuție găsite: ${t0.size}/${toate.length}`);
  const nou = t0.size > toate.length * 0.6;
  if (nou) loc = { actualizat: new Date().toISOString(), judete: judeteGaz, resedinte: loc?.resedinte || {} };
  else log("Prea puține tarife – păstrez gaz-localitati.json vechi");

  // Coduri poștale → localitate ANRE
  const cp = await coduriPostale();
  if (cp?.length > 30000 && loc?.judete) {
    const judetPosf = new Map(Object.keys(loc.judete).map((j) => [norm(j), j]));
    const pePrefix = {};
    const voturi = {}; // reședința de județ = localitatea codurilor „XX0xxx”
    loc.resedinte ||= {};
    let potrivite = 0, total = 0;
    for (const r of cp) {
      const pref = r.cp.slice(0, 2);
      if (/^0[1-6]$/.test(pref)) continue; // București: o singură localitate
      const j = judetPosf.get(norm(r.judet));
      const arr = j ? loc.judete[j] : [];
      const n = norm(r.loc);
      const cand = arr.filter((x) => norm(x[1]) === n);
      const ales = cand.find((x) => norm(x[2]) === n) || cand[0];
      (pePrefix[pref] ||= { judet: j || r.judet, cp: {} }).cp[r.cp] = ales ? [r.loc, ales[0]] : [r.loc];
      total++; if (ales) potrivite++;
      if (ales && j && r.cp[2] === "0") { const v = (voturi[j] ||= {}); v[ales[0]] = (v[ales[0]] || 0) + 1; }
    }
    for (const [j, v] of Object.entries(voturi)) loc.resedinte[j] = +Object.entries(v).sort((a, b) => b[1] - a[1])[0][0];
    for (const [pref, d] of Object.entries(pePrefix)) await scrieJson(`cp/${pref}.json`, d);
    log(`Coduri poștale: ${total} (fără București), ${potrivite} legate de o localitate cu rețea de gaz, ${Object.keys(pePrefix).length} fișiere`);
  } else log("Coduri poștale: descărcare eșuată, păstrez fișierele vechi");
  if (loc?.judete) { loc.resedinte ||= {}; await scrieJson("gaz-localitati.json", loc); }
}

// 3) Oferte gaz pe județ (zilnic): o cerere pe județ, la reședința de județ
try {
  if (!loc?.judete) throw new Error("lipsește gaz-localitati.json");
  const oferte = new Map();
  const judete = {};
  for (const [j, arr] of Object.entries(loc.judete)) {
    if (!arr.length) continue;
    const siruta = j === "BUCURESTI" ? 999999 : (loc.resedinte?.[j] ?? arr[0][0]);
    const lista = await oferteGaz(j, siruta);
    await sleep(400);
    if (!Array.isArray(lista)) continue;
    const coduri = [];
    for (const o of lista) {
      const cod = curat(o.cod_oferta) || String(o.id_oferta);
      coduri.push(cod);
      if (!oferte.has(cod)) {
        const tva = num(o.tva) || TVA_DEFAULT;
        oferte.set(cod, {
          f: curat(o.nume || o.furnizor?.nume_furnizor), o: curat(o.nume_oferta), c: cod,
          pg: num(o.pg), tt: num(o.tt), acc: num(o.acciza), tva,
          fz: r2(num(o.cf) * 30 * (1 + tva / 100)),
          tip: curat(o.tip_pret), pana: isoDin(o.perioada_oferta_max),
          durata: curat(o.durata_contract), garantii: curat(o.garantii),
          link: link(o.url_oferta) || link(o.url) || link(o.furnizor?.website && `https://${String(o.furnizor.website).replace(/^https?:\/\//, "")}`),
        });
      }
    }
    judete[j] = { oferte: coduri, t0: r2(num(lista[0]?.t0)) };
  }
  if (oferte.size < 5) throw new Error(`prea puține oferte (${oferte.size})`);
  rez.gaz = { oferte: [...oferte.values()], judete };
  const ief = [...oferte.values()].sort((a, b) => (a.pg + a.tt) - (b.pg + b.tt))[0];
  log(`Gaz: ${oferte.size} oferte în ${Object.keys(judete).length} județe; cea mai ieftină ${ief.f} (${ief.pg}+${ief.tt} lei/MWh + distribuție)`);
} catch (e) {
  log("Gaz: păstrez datele vechi –", e.message);
  rez.gaz = vechi.gaz; rez.gaz_vechi = true;
}

if (!rez.curent && !rez.gaz) { log("Nicio dată – anre.json rămâne neschimbat"); process.exit(0); }
await scrieJson("anre.json", rez);
log("Salvat anre.json");
