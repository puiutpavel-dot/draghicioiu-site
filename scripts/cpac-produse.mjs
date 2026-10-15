// Preia catalogul CPAC (AFIR) și scrie produse-traditionale/produse.json, grupat pe puncte de lucru.
// Rulare: node scripts/cpac-produse.mjs
import { writeFile, mkdir } from "node:fs/promises";

const BASE = "https://cpac.afir.info/GetListaProduseData";
const CAT = [0, 1, 2, 3, 4, 5, 6, 7, 9, 10, 13];
const TA = [0, 1, 2, 3, 4, 5, 6, 7, 18, 19, 20, 21];
const PS = 250;
const OUT = "produse-traditionale/produse.json";

const url = (pn) =>
  `${BASE}?q=all&${CAT.map((c) => "fCp=" + c).join("&")}&${TA.map((t) => "fTa=" + t).join("&")}&ps=${PS}&pn=${pn}`;

async function page(pn) {
  for (let i = 0; i < 4; i++) {
    try {
      const r = await fetch(url(pn), {
        headers: { Accept: "application/json", "X-Requested-With": "XMLHttpRequest", "User-Agent": "draghicioiu.ro/1.0 (+https://draghicioiu.ro/produse-traditionale/)" },
      });
      if (!r.ok) throw new Error("HTTP " + r.status);
      return await r.json();
    } catch (e) {
      if (i === 3) throw e;
      await new Promise((s) => setTimeout(s, 1500 * (i + 1)));
    }
  }
}

const norm = (s) => (s || "").replace(/ş/g, "ș").replace(/ţ/g, "ț").replace(/Ş/g, "Ș").replace(/Ţ/g, "Ț").trim();
const fold = (s) => norm(s).normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();

const REGIONS = {
  transilvania: ["Alba", "Brașov", "Cluj", "Covasna", "Harghita", "Hunedoara", "Mureș", "Sibiu", "Bistrița-Năsăud", "Sălaj"],
  maramures: ["Maramureș", "Satu Mare"],
  crisana: ["Bihor", "Arad"],
  banat: ["Timiș", "Caraș-Severin"],
  oltenia: ["Dolj", "Gorj", "Mehedinți", "Olt", "Vâlcea"],
  muntenia: ["Argeș", "Brăila", "Buzău", "Călărași", "Dâmbovița", "Giurgiu", "Ialomița", "Prahova", "Teleorman"],
  bucuresti: ["București", "Ilfov"],
  dobrogea: ["Constanța", "Tulcea"],
  moldova: ["Bacău", "Galați", "Iași", "Neamț", "Vaslui", "Vrancea"],
  bucovina: ["Suceava", "Botoșani"],
};
const COUNTIES = Object.values(REGIONS).flat();
const regionOf = (c) => Object.keys(REGIONS).find((r) => REGIONS[r].includes(c)) || "md";

function county(addr) {
  const a = norm(addr);
  const m = a.match(/Jude[tț]ul\s+([^,]+)/);
  if (m) {
    const raw = m[1].trim().replace("Satu-Mare", "Satu Mare");
    return COUNTIES.find((c) => fold(c) === fold(raw)) || raw;
  }
  if (/bucuresti|sector \d/.test(fold(a))) return "București";
  return null;
}

function locality(addr) {
  const parts = norm(addr).split(",").map((s) => s.trim());
  const clean = (s) => s.replace(/^(Municipiul|Mun\.|Orașul|Oraș|Oras|Comuna|Com\.|Satul|Sat)\s+/, "").trim();
  const sat = parts.find((p) => p.startsWith("Sat "));
  return clean(sat || parts[0] || "");
}

function coord(lat, lon) {
  let la = parseFloat(String(lat || "").replace(",", "."));
  let lo = parseFloat(String(lon || "").replace(",", "."));
  if (!isFinite(la) || !isFinite(lo)) return null;
  if (la >= 20 && la <= 30.5 && lo >= 43 && lo <= 48.6) [la, lo] = [lo, la];
  if (la < 43.4 || la > 48.6 || lo < 20 || lo > 30.5) return null;
  return [Math.round(la * 1e5) / 1e5, Math.round(lo * 1e5) / 1e5];
}

const CATS = [
  ["leg", /legume|fructe/], ["lap", /lapte/], ["car", /carne/], ["api", /apicol/], ["pan", /panifica/],
  ["pes", /peste/], ["bau", /bauturi/], ["cra", /crame/], ["pgl", /p\.g\.l|gastronomic/],
];
const cat = (s) => (CATS.find(([, re]) => re.test(fold(s))) || ["alt"])[0];

const first = await page(1);
const total = first.TotalPages || 1;
let recs = first.Records;
for (let p = 2; p <= total; p += 4) {
  const batch = await Promise.all([p, p + 1, p + 2, p + 3].filter((n) => n <= total).map(page));
  batch.forEach((b) => (recs = recs.concat(b.Records)));
}
console.log(`CPAC: ${recs.length} înregistrări din ${total} pagini`);

const seen = new Set();
const points = new Map();
for (const r of recs) {
  if (seen.has(r.AtestatId) || !r.ProdusDenumire) continue;
  seen.add(r.AtestatId);
  const addr = norm(r.PunctDeLucruAdresa || r.ProducatorAdrsa);
  const j = county(addr) || county(r.ProducatorAdrsa) || "Necunoscut";
  const c = coord(r.CV1, r.CV2);
  if (!c) continue; // fără coordonate valide nu putem pune pe hartă
  const key = r.PunctDeLucruId || "p" + r.ProducatorId;
  if (!points.has(key)) {
    points.set(key, { la: c[0], lo: c[1], p: norm(r.ProducatorDenumire), a: addr, l: locality(addr), j, r: regionOf(j), x: [] });
  }
  const y = r.AtestatAn >= 1800 && r.AtestatAn <= 2100 ? r.AtestatAn : 0;
  points.get(key).x.push({
    n: norm(r.ProdusDenumire), c: cat(r.ProdusCategorie), t: r.AtestatTipId || 0,
    d: norm(r.ProdusDescriere).replace(/\s+/g, " "), nr: norm(r.AtestatNr), y, s: r.ProdusRating ? Math.round(r.ProdusRating * 100) / 100 : 0,
  });
}

const data = { updated: new Date().toISOString().slice(0, 10), points: [...points.values()] };
await mkdir("produse-traditionale", { recursive: true });
await writeFile(OUT, JSON.stringify(data));
console.log(`Scris ${OUT}: ${data.points.length} puncte, ${seen.size} produse`);
