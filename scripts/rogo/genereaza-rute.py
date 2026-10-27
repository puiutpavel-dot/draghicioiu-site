#!/usr/bin/env python3
"""Generează paginile cu rutele RoGo pe draghicioiu.ro/rogo/rute/.

Date:
  orase.json  – [id, nume, regiune, firme ARR valabile, mașini ARR] (din rogo_cities + rogo_operators,
                flote cu 5+ mașini importate din răspunsul ARR nr. 29219/15.10.2026)
  rute.json   – [de_la, până_la, km, preț_lei] (din rogo_routes)

Regula: o rută există doar dacă în regiunea orașului de plecare există mașini autorizate ARR
(OUG 49/2019: mașina pleacă din localitatea operatorului). Destinația poate fi orice localitate din rețea.

Rulare: python3 scripts/rogo/genereaza-rute.py  (din rădăcina repo-ului)
"""
import json, os, html
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(ROOT, "rogo", "rute")
DATA_ZI = "27 octombrie 2026"

orase = json.load(open(os.path.join(HERE, "orase.json"), encoding="utf-8"))
rute = json.load(open(os.path.join(HERE, "rute.json"), encoding="utf-8"))

C = {o[0]: {"id": o[0], "nume": o[1], "reg": o[2], "firme": o[3], "masini": o[4]} for o in orase}
# mașinile se numără pe regiune (București + Ilfov + Otopeni = regiunea București)
reg_masini, reg_firme = {}, {}
for o in C.values():
    reg_masini[o["reg"]] = reg_masini.get(o["reg"], 0) + o["masini"]
    reg_firme[o["reg"]] = reg_firme.get(o["reg"], 0) + o["firme"]
for o in C.values():
    o["m"] = reg_masini[o["reg"]]
    o["f"] = reg_firme[o["reg"]]

plecari = [o for o in sorted(C.values(), key=lambda o: (-o["m"], o["nume"])) if o["m"] > 0]
plec_ids = {o["id"] for o in plecari}
fara = sorted([o for o in C.values() if o["m"] == 0], key=lambda o: o["nume"])

R = [r for r in rute if r[0] in plec_ids and C[r[0]]["reg"] != C[r[1]]["reg"]]
R.sort(key=lambda r: (C[r[0]]["nume"], r[2]))


def fmt(n):
    return f"{int(round(n)):,}".replace(",", ".")


def durata(km):
    m = int(round(km / 75 * 60 / 5) * 5)
    if m < 60:
        return f"~{m} min"
    h, mm = divmod(m, 60)
    return f"~{h} h" + (f" {mm:02d}" if mm else "")


def e(s):
    return html.escape(str(s))


CSS = """
:root{--ink:#14213D;--soft:#4A5568;--muted:#6B7280;--bg:#F4F5F8;--card:#FFFFFF;--line:#DDE1E8;
--accent:#F2B705;--on-accent:#14213D;--good:#1F7A4A;--good-bg:#E3F3EA;--hero:#14213D;--on-hero:#F7F5EF;--row:#F8F9FB}
@media (prefers-color-scheme: dark){:root{--ink:#EEF1F7;--soft:#C3C9D4;--muted:#9AA3B2;--bg:#0E1424;--card:#161E33;--line:#27324C;
--good:#5CC38A;--good-bg:#16301F;--hero:#0A1020;--row:#1A2340}}
*{box-sizing:border-box}html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.55 system-ui,-apple-system,"Segoe UI",Roboto,Arial,sans-serif}
a{color:inherit}.wrap{max-width:1040px;margin:0 auto;padding:0 16px}
header.top{background:var(--hero);color:var(--on-hero)}
.bar{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:14px 0;flex-wrap:wrap}
.logo{font-weight:900;font-size:26px;letter-spacing:-.5px;text-decoration:none;color:var(--on-hero)}.logo span{color:var(--accent)}
.bar nav{display:flex;gap:16px;flex-wrap:wrap;font-size:14px}.bar nav a{text-decoration:none;opacity:.85}.bar nav a:hover{opacity:1;text-decoration:underline}
.hero{padding:36px 0 48px}.crumbs{font-size:14px;opacity:.75;margin-bottom:10px}.crumbs a{text-decoration:none}.crumbs a:hover{text-decoration:underline}
h1{font-size:clamp(30px,5.5vw,48px);line-height:1.1;margin:8px 0 12px;letter-spacing:-1px}
.hero p{font-size:clamp(16px,2.2vw,19px);max-width:680px;opacity:.9;margin:0}
.stats{display:flex;gap:28px;flex-wrap:wrap;margin-top:26px}.stats b{display:block;font-size:30px;font-weight:900;color:var(--accent);letter-spacing:-.5px;line-height:1.1}.stats span{font-size:14px;opacity:.8}
section{padding:44px 0}h2{font-size:clamp(24px,3.6vw,30px);margin:0 0 8px;letter-spacing:-.5px}
.lead{color:var(--soft);margin:0 0 22px;max-width:700px}.alt{background:var(--card);border-top:1px solid var(--line);border-bottom:1px solid var(--line)}
.calc{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:20px;display:grid;gap:14px;grid-template-columns:1fr 1fr;align-items:end}
.calc label{display:block;font-size:13px;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px}
select,input[type=search]{width:100%;font:inherit;color:var(--ink);background:var(--bg);border:1px solid var(--line);border-radius:12px;padding:12px}
.res{grid-column:1/-1;display:flex;gap:18px;flex-wrap:wrap;align-items:baseline;border-top:1px solid var(--line);padding-top:14px;min-height:56px}
.res .p{font-size:36px;font-weight:900;letter-spacing:-1px}.res .d{color:var(--soft)}.res a{font-weight:700}
@media (max-width:560px){.calc{grid-template-columns:1fr}}
.cities{display:grid;gap:10px;grid-template-columns:repeat(auto-fill,minmax(190px,1fr))}
.city{display:block;background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px 16px;text-decoration:none}
.city:hover{border-color:var(--accent)}.city b{display:block;font-size:17px}.city span{font-size:13px;color:var(--muted)}
.scroll{overflow-x:auto;border:1px solid var(--line);border-radius:16px;background:var(--card)}
table{width:100%;border-collapse:collapse}th,td{padding:10px 14px;text-align:left;border-bottom:1px solid var(--line)}
th{font-size:12px;text-transform:uppercase;letter-spacing:.6px;color:var(--muted);position:sticky;top:0;background:var(--card)}
td.r,th.r{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}tbody tr:nth-child(even){background:var(--row)}tr:last-child td{border-bottom:0}
@media (max-width:560px){th,td{padding:9px 8px;font-size:14px}}
td a{text-decoration:none}td a:hover{text-decoration:underline}.tag{font-size:12px;color:var(--muted)}
.filter{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:12px}.filter>*{flex:1 1 220px}
.note{font-size:14px;color:var(--muted);margin-top:12px}.more{margin-top:12px;text-align:center}
.btn{display:inline-block;padding:12px 18px;border-radius:12px;font-weight:700;text-decoration:none;border:0;font:inherit;font-weight:700;cursor:pointer}
.btn.y{background:var(--accent);color:var(--on-accent)}.btn.o{border:1px solid var(--line);background:var(--card);color:var(--ink)}
.status{background:var(--good-bg);color:var(--good);border-radius:14px;padding:14px 16px;font-weight:600}
footer{padding:28px 0 40px;color:var(--muted);font-size:14px}
"""


def head(title, desc, url):
    return f"""<!doctype html>
<html lang="ro">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(title)}</title>
<meta name="description" content="{e(desc)}">
<meta name="theme-color" content="#14213D">
<link rel="canonical" href="https://draghicioiu.ro{url}">
<meta property="og:title" content="{e(title)}">
<meta property="og:description" content="{e(desc)}">
<meta property="og:url" content="https://draghicioiu.ro{url}">
<meta property="og:type" content="website">
<style>{CSS}</style>
</head>
<body>
<header class="top">
  <div class="wrap">
    <div class="bar">
      <a class="logo" href="/rogo/">Ro<span>Go</span></a>
      <nav aria-label="Navigare">
        <a href="/rogo/rute/">Toate rutele</a>
        <a href="/rogo/#soferi">Șoferi</a>
        <a href="/rogo/#flote">Flote</a>
        <a href="/">draghicioiu.ro</a>
      </nav>
    </div>
"""


FOOT = f"""
<footer>
  <div class="wrap">
    RoGo · fondator Daniel Drăghicioiu, co-fondator Bogdan Gherghișan · <a href="/rogo/">RoGo</a> · <a href="/">draghicioiu.ro</a><br>
    Mașini autorizate: date ARR (răspuns nr. 29219/15.10.2026), flote cu cel puțin 5 mașini, autorizații valabile la {DATA_ZI}.
  </div>
</footer>
</body>
</html>
"""

STATUS = ('<div class="status">Prețuri orientative pentru pilot. Cursele cu plată pornesc după obținerea avizului '
          'pentru platformă; până atunci nu se pot rezerva curse reale.</div>')


def row(r, show_from=True, show_to=True):
    a, b, km, p = r
    cells = []
    if show_from:
        cells.append(f'<td><a href="/rogo/rute/{a}/">{e(C[a]["nume"])}</a></td>')
    if show_to:
        dest = e(C[b]["nume"])
        if b in plec_ids:
            dest = f'<a href="/rogo/rute/{b}/">{dest}</a>'
        cells.append(f"<td>{dest}</td>")
    cells += [f'<td class="r">{fmt(km)} km</td>', f'<td class="r">{durata(km)}</td>',
              f'<td class="r"><b>{fmt(p)} lei</b></td>']
    return "<tr>" + "".join(cells) + "</tr>"


# ---------- pagina principală /rogo/rute/ ----------
total_m = sum(reg_masini[r] for r in {o["reg"] for o in plecari})
total_f = sum(reg_firme[r] for r in {o["reg"] for o in plecari})
data_js = json.dumps({
    "c": {o["id"]: [o["nume"], o["m"]] for o in sorted(C.values(), key=lambda o: o["nume"])},
    "r": [[a, b, km, p] for a, b, km, p in R],
}, ensure_ascii=False, separators=(",", ":"))

opts_from = "".join(f'<option value="{o["id"]}">{e(o["nume"])}</option>' for o in sorted(plecari, key=lambda o: o["nume"]))
opts_all = "".join(f'<option value="{o["id"]}">{e(o["nume"])}</option>' for o in sorted(C.values(), key=lambda o: o["nume"]))
cards = "".join(
    f'<a class="city" href="/rogo/rute/{o["id"]}/"><b>{e(o["nume"])}</b>'
    f'<span>{fmt(o["m"])} mașini · {sum(1 for r in R if r[0]==o["id"])} rute</span></a>' for o in plecari)
fara_txt = ", ".join(o["nume"] for o in fara)

page = head(f"Toate rutele RoGo – {fmt(len(R))} de curse între orașe | draghicioiu.ro",
            f"{fmt(len(R))} de rute programate între {len(plecari)} de orașe din România în care există mașini autorizate ARR. Preț fix, distanță și durată pentru fiecare rută.",
            "/rogo/rute/")
page += f"""    <div class="hero">
      <div class="crumbs"><a href="/rogo/">RoGo</a> › Rute</div>
      <h1>Toate rutele RoGo</h1>
      <p>Fiecare combinație între orașele în care există mașini autorizate ARR pentru transport alternativ. Pleci dintr-un oraș cu șoferi autorizați și ajungi în oricare localitate din rețea, la preț fix.</p>
      <div class="stats">
        <div><b>{fmt(len(R))}</b><span>rute posibile</span></div>
        <div><b>{len(plecari)}</b><span>orașe de plecare</span></div>
        <div><b>{fmt(total_m)}</b><span>mașini autorizate ARR</span></div>
        <div><b>{fmt(total_f)}</b><span>flote (5+ mașini)</span></div>
      </div>
    </div>
  </div>
</header>
<main>
<section>
  <div class="wrap">
    <h2>Află prețul</h2>
    <p class="lead">Alege orașul de plecare și destinația.</p>
    <div class="calc">
      <div><label for="de">De la</label><select id="de">{opts_from}</select></div>
      <div><label for="la">Până la</label><select id="la">{opts_all}</select></div>
      <div class="res" id="res" aria-live="polite"></div>
    </div>
  </div>
</section>
<section class="alt">
  <div class="wrap">
    <h2>Orașe de plecare</h2>
    <p class="lead">Ordonate după numărul de mașini autorizate din regiune. București, Ilfov și Aeroportul Otopeni formează o singură regiune.</p>
    <div class="cities">{cards}</div>
    <p class="note">Fără plecări deocamdată (nicio flotă cu 5+ mașini autorizate în județ): {e(fara_txt)}. Sunt incluse ca destinații.</p>
  </div>
</section>
<section>
  <div class="wrap">
    <h2>Toate cele {fmt(len(R))} de rute</h2>
    <p class="lead">Caută după oraș sau sortează după preț ori distanță.</p>
    <div class="filter">
      <input type="search" id="q" placeholder="Caută oraș, ex. Brașov" aria-label="Caută oraș">
      <select id="sort" aria-label="Sortare">
        <option value="n">Ordonate după plecare</option>
        <option value="p">Preț crescător</option>
        <option value="pd">Preț descrescător</option>
        <option value="k">Distanță crescătoare</option>
      </select>
    </div>
    <div class="scroll">
      <table>
        <thead><tr><th>De la</th><th>Până la</th><th class="r">Distanță</th><th class="r">Durată</th><th class="r">Preț fix</th></tr></thead>
        <tbody id="tb"><tr><td colspan="5">Se încarcă… Fără JavaScript, vezi rutele pe pagina fiecărui oraș de mai sus.</td></tr></tbody>
      </table>
    </div>
    <div class="more"><button class="btn o" id="more" hidden>Arată mai multe</button></div>
    <p class="note" id="cnt"></p>
    <p class="note">Distanța e pe drum, estimată; durata presupune o medie de 75 km/h. Prețurile pentru București–Brașov, Brașov–Sibiu, București–Sibiu, Otopeni–Brașov și Otopeni–Sibiu sunt stabilite manual, restul sunt calculate din distanță (minimum 200 lei).</p>
    {STATUS}
  </div>
</section>
</main>
<script>
const D={data_js};
const N=id=>D.c[id][0];
const fm=n=>Math.round(n).toLocaleString('ro-RO');
const dur=km=>{{let m=Math.round(km/75*60/5)*5;if(m<60)return '~'+m+' min';const h=Math.floor(m/60),r=m%60;return '~'+h+' h'+(r?' '+String(r).padStart(2,'0'):'');}};
const norm=s=>s.normalize('NFD').replace(/[\\u0300-\\u036f]/g,'').toLowerCase();
const de=document.getElementById('de'),la=document.getElementById('la'),res=document.getElementById('res');
const idx={{}};D.r.forEach(r=>idx[r[0]+'>'+r[1]]=r);
try{{const p=new URLSearchParams(location.search);if(p.get('de')&&D.c[p.get('de')])de.value=p.get('de');if(p.get('la'))la.value=p.get('la');else la.value='brasov';}}catch(e){{}}
if(de.value===la.value)la.value=de.value==='brasov'?'sibiu':'brasov';
function calc(){{const r=idx[de.value+'>'+la.value];
 if(de.value===la.value){{res.innerHTML='<span class="d">Alege o destinație diferită.</span>';return;}}
 if(!r){{res.innerHTML='<span class="d">'+N(de.value)+' și '+N(la.value)+' sunt în aceeași regiune; RoGo face doar curse între orașe.</span>';return;}}
 res.innerHTML='<span class="p">'+fm(r[3])+' lei</span><span class="d">'+fm(r[2])+' km · '+dur(r[2])+' · '+fm(D.c[r[0]][1])+' mașini autorizate în regiunea de plecare</span><a href="/rogo/rute/'+r[0]+'/">Toate rutele din '+N(r[0])+' →</a>';}}
de.onchange=la.onchange=calc;calc();
const tb=document.getElementById('tb'),q=document.getElementById('q'),so=document.getElementById('sort'),more=document.getElementById('more'),cnt=document.getElementById('cnt');
let lim=150;
function draw(){{const t=norm(q.value.trim());let L=D.r.filter(r=>!t||norm(N(r[0])).includes(t)||norm(N(r[1])).includes(t));
 const s=so.value;if(s==='p')L=L.slice().sort((a,b)=>a[3]-b[3]);else if(s==='pd')L=L.slice().sort((a,b)=>b[3]-a[3]);else if(s==='k')L=L.slice().sort((a,b)=>a[2]-b[2]);
 const link=id=>D.c[id][1]>0?'<a href="/rogo/rute/'+id+'/">'+N(id)+'</a>':N(id);
 tb.innerHTML=L.slice(0,lim).map(r=>'<tr><td>'+link(r[0])+'</td><td>'+link(r[1])+'</td><td class="r">'+fm(r[2])+' km</td><td class="r">'+dur(r[2])+'</td><td class="r"><b>'+fm(r[3])+' lei</b></td></tr>').join('')||'<tr><td colspan="5">Nicio rută găsită.</td></tr>';
 more.hidden=L.length<=lim;cnt.textContent=fm(Math.min(lim,L.length))+' din '+fm(L.length)+' rute afișate';}}
q.oninput=()=>{{lim=150;draw();}};so.onchange=()=>{{lim=150;draw();}};more.onclick=()=>{{lim+=300;draw();}};draw();
</script>
""" + FOOT

os.makedirs(OUT, exist_ok=True)
with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as f:
    f.write(page)

# ---------- câte o pagină pe oraș de plecare ----------
for o in plecari:
    din = sorted([r for r in R if r[0] == o["id"]], key=lambda r: r[2])
    spre = sorted([r for r in R if r[1] == o["id"]], key=lambda r: r[2])
    ieftin = min(din, key=lambda r: r[3])
    reg_nota = ""
    if o["reg"] == "bucuresti":
        reg_nota = " (regiunea București: București, Ilfov și Aeroportul Otopeni)"
    p = head(f"Curse din {o['nume']} spre {len(din)} de orașe – RoGo | draghicioiu.ro",
             f"Rute RoGo din {o['nume']}: {len(din)} de destinații, de la {fmt(ieftin[3])} lei. Preț fix, distanță și durată. {fmt(o['m'])} de mașini autorizate ARR în regiune.",
             f"/rogo/rute/{o['id']}/")
    p += f"""    <div class="hero">
      <div class="crumbs"><a href="/rogo/">RoGo</a> › <a href="/rogo/rute/">Rute</a> › {e(o['nume'])}</div>
      <h1>Curse din {e(o['nume'])}</h1>
      <p>Programezi cursa cu cel puțin o oră și cel mult 14 zile înainte. Prețul e fix de la rezervare.</p>
      <div class="stats">
        <div><b>{len(din)}</b><span>destinații</span></div>
        <div><b>{fmt(o['m'])}</b><span>mașini autorizate ARR{e(reg_nota)}</span></div>
        <div><b>{fmt(o['f'])}</b><span>flote (5+ mașini)</span></div>
        <div><b>{fmt(ieftin[3])} lei</b><span>cea mai ieftină: {e(C[ieftin[1]]['nume'])}</span></div>
      </div>
    </div>
  </div>
</header>
<main>
<section>
  <div class="wrap">
    <h2>Din {e(o['nume'])} spre</h2>
    <p class="lead">Toate cele {len(din)} de destinații, ordonate după distanță.</p>
    <div class="scroll"><table>
      <thead><tr><th>Destinație</th><th class="r">Distanță</th><th class="r">Durată</th><th class="r">Preț fix</th></tr></thead>
      <tbody>{''.join(row(r, show_from=False) for r in din)}</tbody>
    </table></div>
  </div>
</section>
<section class="alt">
  <div class="wrap">
    <h2>Spre {e(o['nume'])}</h2>
    <p class="lead">Curse care ajung în {e(o['nume'])}, din {len(spre)} de orașe cu mașini autorizate.</p>
    <div class="scroll"><table>
      <thead><tr><th>De la</th><th class="r">Distanță</th><th class="r">Durată</th><th class="r">Preț fix</th></tr></thead>
      <tbody>{''.join(row(r, show_to=False) for r in spre)}</tbody>
    </table></div>
    <p class="note">Mașina pleacă din orașul firmei autorizate și se întoarce acolo după cursă (OUG 49/2019), de aceea fiecare direcție are șoferii ei.</p>
  </div>
</section>
<section>
  <div class="wrap">
    {STATUS}
    <p style="margin-top:18px"><a class="btn y" href="/rogo/#soferi">Ai Tesla în {e(o['nume'])}? Intră în pilot</a> <a class="btn o" href="/rogo/rute/">Toate rutele</a></p>
  </div>
</section>
</main>
""" + FOOT
    d = os.path.join(OUT, o["id"])
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "index.html"), "w", encoding="utf-8") as f:
        f.write(p)

print(f"{len(R)} rute, {len(plecari)} orașe de plecare, {len(fara)} doar destinații: {fara_txt}")
