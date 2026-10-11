// Comparator mobilă – actualizare zilnică prețuri Mobexpert + IKEA
// Rulează în GitHub Actions (.github/workflows/comparator-preturi.yml) și scrie
// comparator-mobila/preturi.json, pe care îl citește pagina comparator-mobila/index.html.
// Dacă un magazin nu răspunde, se păstrează ultimele prețuri bune pentru acel magazin.
// Node 20+, fără dependențe.

import { readFile, writeFile, rename } from "node:fs/promises";

const OUT = new URL("../comparator-mobila/preturi.json", import.meta.url);
const MIN_REDUCERE = 15; // % – sub acest prag produsele nu apar pe pagină

// Colecțiile Mobexpert urmărite. La o campanie nouă, adaugă numele din
// linkul mobexpert.ro/collections/NUME.
const MOBEXPERT_COLECTII = [
  "ce-bine-e-acasa",
  "outlet",
  "oferte-speciale",
  "stl-canapele-reduse",
  "stl-set-vulcano",
];

// Tipurile de oferte IKEA (pagina „Preț mai mic” = reduced_price).
const IKEA_TIPURI = ["reduced_price", "reduced_price_offer"];

const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Safari/537.36";
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const log = (...a) => console.log(...a);

async function http(url, opts = {}, tries = 3) {
  for (let i = 1; i <= tries; i++) {
    try {
      const r = await fetch(url, {
        ...opts,
        headers: { "User-Agent": UA, "Accept-Language": "ro-RO,ro;q=0.9", ...(opts.headers || {}) },
        signal: AbortSignal.timeout(40000),
      });
      if (r.ok) return r;
      log(`  HTTP ${r.status} ${url}`);
    } catch (e) {
      log(`  eroare (${i}/${tries}) ${url}: ${e.message}`);
    }
    await sleep(1500 * i);
  }
  return null;
}

const plain = (s) =>
  String(s).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");

/** Categorie comună pentru ambele magazine. */
function categorie(text) {
  const t = plain(text).trim();
  if (/\bpat$/.test(t)) return "Dormitor (paturi, comode)";
  const reguli = [
    ["Living (comode TV)", ["comoda tv", "comode tv", "mobilier tv", "banca tv"]],
    ["Birouri", ["birou", "scaun gaming", "masa de lucru"]],
    ["Dormitor (paturi, comode)", ["masa de toaleta", "masuta de toaleta", "noptier", "comoda", "pat ", "pat,", "pat tapitat", "cadru pat", "oglinda", "dulap", "dressing", "sifonier"]],
    ["Saltele", ["saltea", "somiera", "topper"]],
    ["Canapele & fotolii", ["canapea", "coltar", "fotoliu", "taburet", "sezlong", "bancheta"]],
    ["Mese & scaune", ["scaun", "masa", "mese ", "set masa"]],
    ["Biblioteci & depozitare", ["bibliotec", "etajer", "polit", "raft", "cutie", "cos ", "depozitare", "suport carti", "pantofi", "corp", "ansamblu"]],
    ["Baie", ["baie", "lavoar", "cada", "dus", "prosop"]],
    ["Bucătărie & veselă", ["pahar", "farfuri", "vase", "tigaie", "oala", "caserol", "carafa", "tacam", "cana", "ceasca", "bol", "cutit"]],
    ["Iluminat", ["lustra", "lampa", "veioza", "lampadar", "plafonier", "aplica", "pendul", "bec"]],
    ["Covoare & textile", ["covor", "perna", "pled", "patura", "pilota", "draperi", "perdea", "lenjerie", "asternut", "husa"]],
  ];
  for (const [cat, chei] of reguli) if (chei.some((c) => (t + " ").includes(c))) return cat;
  return "Altele";
}

// ---------- MOBEXPERT (Shopify products.json) ----------
async function mobexpert() {
  const rez = new Map();
  for (const col of MOBEXPERT_COLECTII) {
    let n = 0;
    for (let pag = 1; pag <= 40; pag++) {
      const r = await http(`https://mobexpert.ro/collections/${col}/products.json?limit=250&page=${pag}`);
      if (!r) break;
      const produse = (await r.json()).products || [];
      if (!produse.length) break;
      for (const p of produse) {
        let best = null;
        for (const v of p.variants || []) {
          const pr = +v.price, old = +v.compare_at_price;
          if (!(pr > 0 && old > pr) || v.available === false) continue;
          const pct = (1 - pr / old) * 100;
          if (!best || pct > best.pct) best = { pr, old, pct };
        }
        if (!best) continue;
        const titlu = p.title.trim();
        const m = titlu.match(/^([A-ZĂÂÎȘȚ0-9&'.\- ]{2,}?)\s+(\p{Lu}\p{Ll}.*)$/u);
        rez.set(p.handle, {
          store: "Mobexpert",
          name: m ? m[1].trim() : titlu,
          desc: m ? m[2] : p.product_type || "",
          cat: categorie(`${p.product_type || ""} ${titlu}`),
          price: Math.round(best.pr * 100) / 100,
          old: Math.round(best.old * 100) / 100,
          url: `https://mobexpert.ro/products/${p.handle}`,
        });
        n++;
      }
      if (produse.length < 250) break;
      await sleep(400);
    }
    log(`Mobexpert/${col}: ${n} produse reduse`);
  }
  return [...rez.values()];
}

// ---------- IKEA (API-ul de căutare folosit de ikea.com) ----------
const pretIkea = (p) => (p ? parseFloat(`${String(p.wholeNumber || "0").replace(/\D/g, "")}.${p.decimals || 0}`) : 0);

async function ikea() {
  const rez = new Map();
  for (const tip of IKEA_TIPURI) {
    let n = 0;
    for (let off = 0; off < 2000; off += 100) {
      const body = {
        searchParameters: { input: tip, type: "SPECIAL" },
        components: [{ component: "PRIMARY_AREA", columns: 4, types: { main: "PRODUCT", breakouts: [] }, filterConfig: {}, window: { offset: off, size: 100 } }],
      };
      const r = await http("https://sik.search.blue.cdtapps.com/ro/ro/search?c=listaf&v=20240110", {
        method: "POST",
        headers: { "Content-Type": "application/json", Origin: "https://www.ikea.com", Referer: "https://www.ikea.com/ro/ro/cat/lower-price/" },
        body: JSON.stringify(body),
      });
      if (!r) break;
      const area = (await r.json()).results?.[0];
      const items = area?.items || [];
      for (const { product: p } of items) {
        if (!p?.salesPrice) continue;
        const sp = p.salesPrice;
        const tags = sp.tags || [sp.tag];
        if (tags.includes("FAMILY_PRICE")) continue; // doar pentru membri IKEA Family
        const price = sp.numeral ?? pretIkea(sp.current);
        const old = pretIkea(sp.previous);
        if (!(price > 0 && old > price)) continue;
        rez.set(p.itemNo, {
          store: "IKEA",
          name: p.name,
          desc: [p.typeName, p.itemMeasureReferenceText].filter(Boolean).join(", "),
          cat: categorie(`${p.typeName || ""} ${p.name}`),
          price: Math.round(price * 100) / 100,
          old: Math.round(old * 100) / 100,
          url: p.pipUrl || "https://www.ikea.com/ro/ro/cat/lower-price/",
        });
        n++;
      }
      const max = area?.metadata?.max ?? 0;
      if (!items.length || off + 100 >= max) break;
      await sleep(500);
    }
    log(`IKEA/${tip}: ${n} produse reduse`);
  }
  return [...rez.values()];
}

// ---------- RULARE ----------
let vechi = {};
try { vechi = JSON.parse(await readFile(OUT, "utf8")); } catch {}
const vechiPe = (s) => (vechi.items || []).filter((i) => i.store === s);
const acum = new Date().toISOString();
const actualizat = { ...(vechi.updated_store || {}) };

let mob = await mobexpert();
if (mob.length >= 3) actualizat.Mobexpert = acum;
else { log("Mobexpert: prea puține produse, păstrez datele vechi"); mob = vechiPe("Mobexpert"); }

let ik = await ikea();
if (ik.length >= 3) actualizat.IKEA = acum;
else { log("IKEA: prea puține produse, păstrez datele vechi"); ik = vechiPe("IKEA"); }

const items = [...mob, ...ik].filter((i) => i.old > 0 && i.price > 0 && (1 - i.price / i.old) * 100 >= MIN_REDUCERE);
if (!items.length) { log("Nicio dată – preturi.json rămâne neschimbat"); process.exit(0); }

const out = { updated: acum, updated_store: actualizat, count: items.length, items };
const tmp = new URL("../comparator-mobila/preturi.json.tmp", import.meta.url);
await writeFile(tmp, JSON.stringify(out));
await rename(tmp, OUT);
log(`Salvat preturi.json: ${items.length} produse (Mobexpert ${mob.length}, IKEA ${ik.length})`);
