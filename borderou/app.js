(function () {
  "use strict";
  var O = window.OPIS, LS = "borderou_lucrari_v1";
  var db = null, dl = null, lucrari = [], curent = null, msg = "";
  var timers = {}, writing = {}, dirty = {};
  var $ = function (id) { return document.getElementById(id); };

  function h(tag, attrs, kids) {
    var e = document.createElement(tag), k;
    for (k in attrs || {}) {
      if (k === "on") { for (var ev in attrs.on) e.addEventListener(ev, attrs.on[ev]); }
      else if (k === "text") e.textContent = attrs[k];
      else if (attrs[k] === true) e.setAttribute(k, "");
      else if (attrs[k] !== false && attrs[k] != null) e.setAttribute(k, attrs[k]);
    }
    (kids || []).forEach(function (c) { if (c) e.appendChild(typeof c === "string" ? document.createTextNode(c) : c); });
    return e;
  }
  function setSave(t) { $("saveState").textContent = t; }
  function get(id) { return lucrari.filter(function (l) { return l.id === id; })[0] || null; }
  function sortList() { lucrari.sort(function (a, b) { return (a.scurt || a.denumire || "").localeCompare(b.scurt || b.denumire || "", "ro"); }); }

  /* ---------- stocare ---------- */
  function timeout(p, ms) {
    return Promise.race([p, new Promise(function (_, rej) { setTimeout(function () { rej({ code: "timeout" }); }, ms); })]);
  }
  async function load() {
    if (db) {
      try {
        var snap = await timeout(db.collection("lucrari").get(), 10000);
        lucrari = snap.docs.map(function (d) { var x = JSON.parse(JSON.stringify(d.data() || {})); x.id = d.id; x.rows = x.rows || {}; return x; });
        setSave("Salvat în aplicație");
      } catch (e) {
        msg = "Lucrările salvate nu pot fi citite acum. Reîncarcă pagina peste câteva momente.";
        setSave("Fără legătură cu datele");
      }
    } else {
      try { lucrari = JSON.parse(localStorage.getItem(LS) || "[]"); } catch (e) { lucrari = []; }
      setSave("Salvat doar în acest browser");
    }
    sortList();
    curent = lucrari.length ? lucrari[0].id : null;
    renderList(); renderMain();
  }
  function saveLocal() { try { localStorage.setItem(LS, JSON.stringify(lucrari)); } catch (e) { setSave("Nu se poate salva în acest browser"); } }
  function queueSave(l) {
    l.actualizat = new Date().toISOString();
    if (!db) { saveLocal(); return; }
    setSave("Se salvează…");
    clearTimeout(timers[l.id]);
    timers[l.id] = setTimeout(function () { flush(l.id); }, 700);
  }
  async function flush(id) {
    if (writing[id]) { dirty[id] = true; return; }
    var l = get(id); if (!l) return;
    writing[id] = true;
    try {
      var body = JSON.parse(JSON.stringify(l)); delete body.id;
      await db.collection("lucrari").doc(id).set(body);
      setSave("Salvat");
    } catch (e) {
      setSave(e && e.code === "invalid_argument" ? "Nu ai drept de scriere pe această pagină" : "Nesalvat. Mai modifică o dată ca să reîncerc.");
    }
    writing[id] = false;
    if (dirty[id]) { dirty[id] = false; flush(id); }
  }

  /* ---------- lista ---------- */
  function renderList() {
    var ul = $("list"); ul.textContent = "";
    if (!lucrari.length) ul.appendChild(h("li", { class: "hint", style: "padding:6px 10px", text: "Nicio lucrare încă." }));
    lucrari.forEach(function (l) {
      var s = O.stats(l), sub = [];
      if (s.lipsa) sub.push(s.lipsa + " lipsă");
      if (s.probleme) sub.push(s.probleme + " cu probleme");
      if (s.neverificat) sub.push(s.neverificat + " neverificate");
      if (!sub.length) sub.push("complet");
      ul.appendChild(h("li", {}, [h("button", { type: "button", "aria-current": l.id === curent ? "true" : "false",
        on: { click: function () { curent = l.id; renderList(); renderMain(); } } }, [
        h("span", { class: "nm", text: l.scurt || l.denumire || "Lucrare fără nume" }),
        h("span", { class: "sub" }, [h("span", { class: "tag " + l.faza.toLowerCase(), text: l.faza }), h("span", { text: sub.join(" · ") })])
      ])]));
    });
  }
  function nou(faza) {
    var l = { id: "l" + Date.now().toString(36) + Math.floor(Math.random() * 1296).toString(36), faza: faza, scurt: "", denumire: "",
      proiectant: "", revizie: "", cuNr: "", cuData: "", acNr: "", acData: "", atr: "", note: "", rows: {} };
    lucrari.push(l); curent = l.id; queueSave(l); renderList(); renderMain();
    var f = $("f_scurt"); if (f) f.focus();
  }

  /* ---------- fișa ---------- */
  function field(l, key, label, cls, opts) {
    opts = opts || {};
    var id = "f_" + key, el;
    if (opts.select) {
      el = h("select", { id: id }, opts.select.map(function (o) { return h("option", { value: o, text: o, selected: l[key] === o }); }));
    } else if (opts.area) {
      el = h("textarea", { id: id, placeholder: opts.ph || "" }); el.value = l[key] || "";
    } else {
      el = h("input", { id: id, type: "text", placeholder: opts.ph || "" }); el.value = l[key] || "";
    }
    el.addEventListener(opts.select ? "change" : "input", function () {
      l[key] = el.value; queueSave(l);
      if (key === "faza") { renderList(); renderMain(); return; }
      if (key === "scurt" || key === "denumire") renderList();
      if (key === "scurt" || key === "denumire" || key === "acNr" || key === "acData") updateTree(l);
    });
    return h("div", { class: "f " + (cls || "") }, [h("label", { for: id, text: label }), el]);
  }

  /* ---------- rând de borderou ---------- */
  function preview(l, r) {
    var c = O.cellsFor(l.faza, r, l.rows[r.k]), p = h("div", { class: "prev" });
    if (!c.obs.length) { p.textContent = l.rows[r.k] && l.rows[r.k].stare ? "Observații în OPIS: (gol)" : ""; return p; }
    p.appendChild(document.createTextNode("Observații în OPIS: "));
    c.obs.forEach(function (o, i) {
      if (i) p.appendChild(document.createTextNode("; "));
      p.appendChild(h("span", { class: o.red ? "r" : "", text: o.text }));
    });
    return p;
  }
  function changed(l, r, rebuild) {
    queueSave(l); updateSum(l); renderList();
    if (rebuild) { var old = $("row_" + r.k); old.parentNode.replaceChild(rowEl(l, r), old); }
    else { var pv = $("prev_" + r.k), n = preview(l, r); n.id = "prev_" + r.k; pv.parentNode.replaceChild(n, pv); }
  }
  function rowEl(l, r) {
    var st = l.rows[r.k] || (l.rows[r.k] = {});
    st.flags = st.flags || {};
    function segBtn(val, text, cls) {
      return h("button", { type: "button", class: cls || "", "aria-pressed": st.stare === val ? "true" : "false", text: text,
        on: { click: function () { st.stare = st.stare === val ? "" : val; changed(l, r, true); } } });
    }
    var seg = h("div", { class: "seg", role: "group", "aria-label": "Stare " + r.den }, [
      segBtn("ok", "Există"), r.inMem ? segBtn("mem", "În memoriu") : null, segBtn("lipsa", "Lipsește", "l")]);

    var fileCell = h("td", { class: "file" });
    if (st.stare === "ok") {
      var fi = h("input", { id: "file_" + r.k, type: "number", min: "0", placeholder: "nr. file", "aria-label": "Număr file " + r.den });
      fi.value = st.file || "";
      fi.addEventListener("input", function () { st.file = fi.value; changed(l, r); });
      fileCell.appendChild(fi);
    } else if (st.stare === "mem") {
      var pg = h("input", { id: "pag_" + r.k, type: "text", placeholder: "pag. 12–54", "aria-label": "Pagini în memoriu " + r.den });
      pg.value = st.pag || "";
      pg.addEventListener("input", function () { st.pag = pg.value; changed(l, r); });
      fileCell.appendChild(pg);
    } else fileCell.appendChild(h("span", { class: "hint", text: st.stare === "lipsa" ? "–" : "" }));

    var obs = h("td", {});
    if (st.stare === "ok") {
      obs.appendChild(h("div", { class: "flags" }, O.flagsFor(l.faza, r.kind).map(function (f) {
        var cb = h("input", { type: "checkbox", id: "fl_" + r.k + "_" + f });
        cb.checked = !!st.flags[f];
        cb.addEventListener("change", function () { st.flags[f] = cb.checked; changed(l, r); });
        return h("label", { for: cb.id }, [cb, O.FLAGS[f]]);
      })));
    }
    if (st.stare) {
      var nt = h("input", { id: "nota_" + r.k, type: "text", "aria-label": "Notă " + r.den,
        placeholder: r.kind === "plan" ? "notă scurtă, ex. codurile planșelor" : "notă scurtă (opțional)" });
      nt.value = st.nota || "";
      nt.addEventListener("input", function () { st.nota = nt.value; changed(l, r); });
      obs.appendChild(nt);
    }
    var pv = preview(l, r); pv.id = "prev_" + r.k; obs.appendChild(pv);

    var src = h("td", {});
    if (st.stare === "ok" || st.stare === "mem") {
      var si = h("input", { id: "sursa_" + r.k, type: "text", placeholder: "fișier sau folder sursă", "aria-label": "Sursa " + r.den });
      si.value = st.sursa || "";
      si.addEventListener("input", function () { st.sursa = si.value; queueSave(l); });
      src.appendChild(si);
    }
    return h("tr", { id: "row_" + r.k, "data-st": st.stare || "" }, [
      h("td", { class: "nr", text: r.nr }), h("td", { class: "den", text: r.den }), h("td", {}, [seg]), fileCell, obs, src]);
  }

  /* ---------- sumar, structură, export ---------- */
  function updateSum(l) {
    var s = O.stats(l), box = $("chips"); if (!box) return;
    box.textContent = "";
    [["bad", s.lipsa, "lipsesc"], ["warn", s.probleme, "cu semnături sau ștampile lipsă"], ["good", s.ok, "în regulă"], ["mut", s.neverificat, "neverificate"]]
      .forEach(function (c) { box.appendChild(h("span", { class: "chip " + c[0] }, [h("b", { text: String(c[1]) }), c[2]])); });
  }
  function updateTree(l) { var p = $("tree"); if (p) p.textContent = O.folderTree(l).join("\n"); }
  function say(t) { var m = $("msg"); if (m) { m.textContent = t || ""; m.hidden = !t; } }

  function saveFile(name, data) {
    if (dl) return dl.save({ filename: name, data: data });
    var a = document.createElement("a"), url = URL.createObjectURL(data instanceof Blob ? data : new Blob([data]));
    a.href = url; a.download = name; document.body.appendChild(a); a.click(); a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 4000);
    return Promise.resolve();
  }
  async function exportFile(l, kind, btn) {
    say("");
    btn.disabled = true;
    try {
      var base = O.fileBase(l), data, name;
      if (kind === "docx") { data = await O.docx(O.buildModel(l, { sursa: false }), window.JSZip); name = base + ".docx"; }
      else if (kind === "pdf") { data = O.pdf(O.buildModel(l, { sursa: true }), window.jspdf.jsPDF, window.OPIS_FONTS); name = base + ".pdf"; }
      else {
        var z = new window.JSZip(), tree = O.folderTree(l);
        tree.forEach(function (p) { z.folder(p); });
        z.file(tree[0] + "/" + base + ".docx", await O.docx(O.buildModel(l, { sursa: false }), window.JSZip, "uint8array"));
        z.file(tree[0] + "/" + base + ".pdf", O.pdf(O.buildModel(l, { sursa: true }), window.jspdf.jsPDF, window.OPIS_FONTS));
        data = await z.generateAsync({ type: "blob" }); name = O.folderName(l) + ".zip";
      }
      await saveFile(name, data);
    } catch (e) {
      if (!e || e.code !== "declined") say("Fișierul nu a putut fi descărcat" + (e && e.code === "rate_limited" ? ": mai e o descărcare în așteptare." : ". Încearcă din nou."));
    }
    btn.disabled = false;
  }

  function renderMain() {
    var main = $("main"), l = get(curent); main.textContent = "";
    if (msg) main.appendChild(h("div", { class: "panel msg", text: msg }));
    if (!l) {
      main.appendChild(h("div", { class: "panel empty" }, [
        h("h2", { text: "Adaugă prima lucrare" }),
        h("p", { text: "Apasă „+ PTE” sau „+ DTAC”. Primești borderoul fazei, pe volume, gata de completat: ce există, ce se află în memoriu și ce lipsește. La final descarci OPIS-ul în Word și PDF și structura de foldere." })
      ]));
      return;
    }
    var m = O.MODELE[l.faza];
    main.appendChild(h("section", { class: "panel fisa", "aria-label": "Fișa lucrării" }, [
      field(l, "scurt", "Nume scurt (pentru foldere)", "", { ph: "ex. Castelu" }),
      field(l, "faza", "Faza", "w1", { select: ["PTE", "DTAC"] }),
      field(l, "revizie", "Revizia", "w1", { ph: "Rev.0" }),
      field(l, "proiectant", "Proiectant", "", { ph: "denumirea completă a firmei" }),
      field(l, "denumire", "Lucrarea (denumirea obiectivului din lista Anghel Saligny)", "w6", { area: true }),
      field(l, "cuNr", "Certificat de urbanism nr.", "w1"), field(l, "cuData", "CU din data", "w1", { ph: "zz.ll.aaaa" }),
      field(l, "acNr", "Autorizație de construire nr.", "w1"), field(l, "acData", "AC din data", "w1", { ph: "zz.ll.aaaa" }),
      field(l, "atr", "ATR (nr. / dată / emitent)", "", {})
    ]));

    var bDocx = h("button", { class: "btn", type: "button", text: "OPIS Word" }),
      bPdf = h("button", { class: "btn", type: "button", text: "OPIS PDF" }),
      bZip = h("button", { class: "btn primary", type: "button", text: "Dosar cu foldere (.zip)" });
    bDocx.addEventListener("click", function () { exportFile(l, "docx", bDocx); });
    bPdf.addEventListener("click", function () { exportFile(l, "pdf", bPdf); });
    bZip.addEventListener("click", function () { exportFile(l, "zip", bZip); });
    var bRest = h("button", { class: "btn", type: "button", text: "Marchează neverificatele ca lipsă",
      on: { click: function () {
        m.volume.forEach(function (v) { v.rows.forEach(function (r) { var s = l.rows[r.k] || (l.rows[r.k] = {}); if (!s.stare) s.stare = "lipsa"; }); });
        queueSave(l); renderList(); renderMain();
      } } });

    var tbody = h("tbody", {});
    m.volume.forEach(function (v) {
      tbody.appendChild(h("tr", { class: "vol" }, [h("td", { colspan: "6", text: v.titlu })]));
      v.rows.forEach(function (r) { tbody.appendChild(rowEl(l, r)); });
    });
    main.appendChild(h("section", { class: "panel", "aria-label": "Borderou" }, [
      h("div", { class: "sum" }, [h("span", { id: "chips", style: "display:contents" }), h("div", { class: "sp" }, [bRest, bDocx, bPdf, bZip])]),
      h("div", { class: "msg", id: "msg", hidden: true }),
      h("p", { class: "note", text: "Faza: " + m.faza + ". PDF-ul are și coloana „Sursa”, Word-ul nu. Pozițiile neverificate apar goale în OPIS." }),
      h("div", { class: "tw" }, [h("table", {}, [
        h("thead", {}, [h("tr", {}, ["Nr. crt.", "Denumire", "Stare", "Nr. file", "Lipsuri și observații", "Sursa (de unde a fost extras)"].map(function (t) { return h("th", { scope: "col", text: t }); }))]),
        tbody])])
    ]));
    updateSum(l);

    main.appendChild(h("section", { class: "panel" }, [h("details", {}, [
      h("summary", { text: "Structura de foldere a dosarului" }), h("pre", { id: "tree" })])]));
    updateTree(l);

    var del = h("button", { class: "btn danger", type: "button", text: "Șterge lucrarea" }), armed = false;
    del.addEventListener("click", function () {
      if (!armed) { armed = true; del.textContent = "Apasă din nou ca să ștergi definitiv"; setTimeout(function () { armed = false; del.textContent = "Șterge lucrarea"; }, 4000); return; }
      var id = l.id; clearTimeout(timers[id]);
      lucrari = lucrari.filter(function (x) { return x.id !== id; });
      curent = lucrari.length ? lucrari[0].id : null;
      if (db) db.collection("lucrari").doc(id).delete().then(function () { setSave("Salvat"); }, function () { setSave("Ștergerea nu a reușit"); });
      else saveLocal();
      renderList(); renderMain();
    });
    main.appendChild(h("div", { class: "foot" }, [
      h("span", { class: "hint", text: "Întocmit: Daniel Drăghicioiu" }), del]));
  }

  /* copie de siguranță, doar când datele stau în browser */
  function backupUi() {
    var box = $("backup"); if (!box) return;
    var inp = h("input", { type: "file", id: "impFile", accept: ".json,application/json", hidden: true });
    inp.addEventListener("change", function () {
      var f = inp.files && inp.files[0]; if (!f) return;
      f.text().then(function (t) {
        var arr = JSON.parse(t); if (!Array.isArray(arr)) throw 0;
        arr.forEach(function (x) {
          if (!x || !x.id || !O.MODELE[x.faza]) return;
          x.rows = x.rows || {};
          var i = lucrari.findIndex(function (y) { return y.id === x.id; });
          if (i >= 0) lucrari[i] = x; else lucrari.push(x);
        });
        sortList(); saveLocal(); if (!curent && lucrari.length) curent = lucrari[0].id;
        renderList(); renderMain(); setSave("Copie încărcată");
      }).catch(function () { setSave("Fișierul nu este o copie validă"); });
      inp.value = "";
    });
    box.appendChild(h("p", { class: "hint", text: "Lucrările se păstrează doar în acest browser. Salvează din când în când o copie." }));
    box.appendChild(h("div", { class: "row" }, [
      h("button", { class: "btn", type: "button", text: "Salvează copie", on: { click: function () {
        saveFile("borderou-lucrari-" + new Date().toISOString().slice(0, 10) + ".json", new Blob([JSON.stringify(lucrari, null, 1)], { type: "application/json" }));
      } } }),
      h("button", { class: "btn", type: "button", text: "Încarcă copie", on: { click: function () { inp.click(); } } }), inp]));
    box.hidden = false;
  }

  $("newPte").addEventListener("click", function () { nou("PTE"); });
  $("newDtac").addEventListener("click", function () { nou("DTAC"); });

  (async function () {
    var framed = false; try { framed = window.self !== window.top; } catch (e) { framed = true; }
    for (var i = 0; framed && i < 20 && !(window.claude && window.claude.use); i++) await new Promise(function (r) { setTimeout(r, 100); });
    var c = window.claude;
    if (c && c.use) {
      try { db = await c.use("db"); } catch (e) { db = null; }
      try { dl = await c.use("downloads"); } catch (e) { dl = null; }
    }
    await load();
    if (!db) backupUi();
  })();
})();
