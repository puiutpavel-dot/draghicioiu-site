/* Borderou DTAC / PTE rețea gaze: modele, reguli OPIS, export Word și PDF.
   Funcții pure, folosite de pagină și testate separat. */
(function (g) {
  "use strict";

  // Tipuri de lipsuri care se pot bifa pe o poziție
  var FLAGS = {
    nesemnat: "nesemnat",
    nestampilat: "neștampilat",
    stSoc: "fără ștampila societății",
    stPro: "fără ștampila proiectantului",
    stVer: "fără ștampila verificatorului",
    viza: "fără viza „vizat spre neschimbare”",
    expirat: "expirat"
  };

  // kind: act | scris | plan | eco
  function flagsFor(faza, kind) {
    if (kind === "act") return ["expirat"];
    if (kind === "eco") return ["nesemnat", "nestampilat"]; // fără verificator / viză la Vol. III
    var f = kind === "plan"
      ? ["nesemnat", "stSoc", "stPro", "stVer"]
      : ["nesemnat", "nestampilat", "stVer"];
    if (faza === "DTAC") f.push("viza");
    return f;
  }

  var MODELE = {
    PTE: {
      titlu: "PROIECT TEHNIC DE EXECUȚIE",
      faza: "Proiect Tehnic de Execuție (P.T.E.)",
      volume: [
        { titlu: "Volumul I – Piese scrise", dir: "I. Volum I - Piese scrise", extraDirs: ["00. Referate de verificare"], rows: [
          { k: "v1_referat", nr: "1", den: "Referat Verificator", kind: "scris", dir: "01. Referat verificator" },
          { k: "v1_anre", nr: "2", den: "Autorizație de proiectare ANRE firma proiectare", kind: "act", dir: "02. Autorizatiile ANRE ale societatii" },
          { k: "v1_legit", nr: "3", den: "Legitimație instalator autorizat ANRE pentru proiectare", kind: "act", dir: "03. Legitimatia ANRE de instalator autorizat" },
          { k: "v1_control", nr: "4", den: "Programul de control în faze determinante", kind: "scris", dir: "04. Program de control" },
          { k: "v1_central", nr: "5", den: "Centralizatorul avizelor obținute conform CU", kind: "scris", dir: "05. Centralizator avize" },
          { k: "v1_cu", nr: "6", den: "Certificatul de urbanism cu avizele și acordurile obținute", kind: "act", dir: "06. CU cu avize si acorduri" },
          { k: "v1_ac", nr: "7", den: "Autorizația de Construire", kind: "act", dir: "07. Autorizatia de construire" },
          { k: "v1_mprez", nr: "", den: "I. Memoriu tehnic de prezentare", kind: "scris", dir: "07.1 Memoriu tehnic de prezentare" },
          { k: "v1_mspec", nr: "", den: "II. Memoriu tehnic de specialitate", kind: "scris", dir: "07.2 Memoriu tehnic de specialitate", inMem: true },
          { k: "v1_brev", nr: "", den: "III. Breviar de calcul", kind: "scris", dir: "07.3 Breviar de calcul", inMem: true },
          { k: "v1_caiet", nr: "8", den: "IV. Caiet de sarcini", kind: "scris", dir: "08. Caiet de sarcini", inMem: true },
          { k: "v1_smart", nr: "9", den: "V. Contorizare inteligentă", kind: "scris", dir: "09. Contorizare inteligenta", inMem: true },
          { k: "v1_grafic", nr: "10", den: "VI. Grafic execuție", kind: "scris", dir: "10. Grafic executie", inMem: true }
        ] },
        { titlu: "Volumul II – Piese desenate", dir: "II. Volum II - Piese desenate", rows: [
          { k: "v2_incadr", nr: "1", den: "Plan de încadrare în zonă", kind: "plan", dir: "01. Plan de incadrare in zona" },
          { k: "v2_situatie", nr: "2", den: "Planul situație", kind: "plan", dir: "02. Planul situatie" },
          { k: "v2_schema", nr: "3", den: "Schema tehnologică", kind: "plan", dir: "03. Schema tehnologica" },
          { k: "v2_detalii", nr: "4", den: "Detalii de execuție", kind: "plan", dir: "04. Detalii de executie" },
          { k: "v2_teu", nr: "5", den: "Detalii teu", kind: "plan", dir: "05. Detalii teu" },
          { k: "v2_sectiuni", nr: "6", den: "Secțiuni", kind: "plan", dir: "06. Sectiuni" },
          { k: "v2_smart", nr: "7", den: "Contorizare inteligentă", kind: "plan", dir: "07. Contorizare inteligenta" }
        ] },
        { titlu: "Volumul III – Documentație economică", dir: "III. Volum III - Documentatie economica", rows: [
          { k: "v3_deviz", nr: "1", den: "Deviz general", kind: "eco", dir: "01. Deviz general" },
          { k: "v3_a5", nr: "2", den: "Anexa 5 – Tabel centralizator conducte", kind: "eco", dir: "02. Anexa 5 - Tabel centralizator conducte" },
          { k: "v3_a6", nr: "3", den: "Anexa 6 – Tabel centralizator racorduri", kind: "eco", dir: "03. Anexa 6 - Tabel centralizator racorduri" },
          { k: "v3_f1", nr: "4", den: "Formular F1", kind: "eco", dir: "04. Formular F1" },
          { k: "v3_f2", nr: "5", den: "Formular F2", kind: "eco", dir: "05. Formular F2" },
          { k: "v3_f3", nr: "6", den: "Formular F3", kind: "eco", dir: "06. Formular F3" },
          { k: "v3_f4", nr: "7", den: "Formular F4", kind: "eco", dir: "07. Formular F4" },
          { k: "v3_f5", nr: "8", den: "Formular F5", kind: "eco", dir: "08. Formular F5" },
          { k: "v3_f6", nr: "9", den: "Formular F6", kind: "eco", dir: "09. Formular F6" }
        ] }
      ]
    },
    DTAC: {
      titlu: "DOCUMENTAȚIE TEHNICĂ PENTRU AUTORIZAREA EXECUTĂRII LUCRĂRILOR DE CONSTRUIRE",
      faza: "Documentație Tehnică pentru Autorizația de Construire (D.T.A.C.)",
      volume: [
        { titlu: "Volumul I – Piese scrise", dir: "I. Volum I - Piese scrise",
          extraDirs: ["00. Referate de verificare", "04. Aviz tehnic racordare"], rows: [
          { k: "v1_anre", nr: "1", den: "Autorizație de proiectare ANRE și legitimație instalator autorizat pentru proiectare", kind: "act",
            dirs: ["01. Autorizatiile ANRE societate", "02. Legitimatia ANRE de instalator autorizat"] },
          { k: "v1_cu", nr: "2", den: "Certificatul de urbanism", kind: "act", dir: "03. Certificatul de urbanism" },
          { k: "v1_mprez", nr: "", den: "I. Memoriu tehnic de prezentare", kind: "scris", dir: "05. Memoriu tehnic de prezentare" },
          { k: "v1_mspec", nr: "", den: "II. Memoriu tehnic de specialitate", kind: "scris", dir: "06. Memoriu tehnic de specialitate", inMem: true },
          { k: "v1_brev", nr: "", den: "III. Breviar de calcul", kind: "scris", dir: "07. Breviar de calcul", inMem: true }
        ] },
        { titlu: "Volumul II – Piese desenate", dir: "II. Volum II - Piese desenate", rows: [
          { k: "v2_incadr", nr: "1", den: "Plan de încadrare în zonă", kind: "plan", dir: "01. Plan de incadrare in zona" },
          { k: "v2_situatie", nr: "2", den: "Planul situație", kind: "plan", dir: "02. Planul situatie" },
          { k: "v2_schema", nr: "3", den: "Schema tehnologică", kind: "plan", dir: "03. Schema tehnologica" }
        ] },
        { titlu: "Volumul III – Documentație economică", dir: "III. Volum III - Documentatie economica", rows: [
          { k: "v3_deviz", nr: "1", den: "Deviz general", kind: "eco", dir: "01. Deviz general" },
          { k: "v3_a5", nr: "2", den: "Anexa 5 – Tabel centralizator conducte", kind: "eco", dir: "02. Anexa 5 - Tabel centralizator conducte" },
          { k: "v3_a6", nr: "3", den: "Anexa 6 – Tabel centralizator racorduri", kind: "eco", dir: "03. Anexa 6 - Tabel centralizator racorduri" }
        ] }
      ]
    }
  };

  /* Starea unei poziții -> ce scrie în „Nr. file” și „Observații”.
     st: { stare: ""|"ok"|"mem"|"lipsa", file, pag, flags:{}, nota, sursa } */
  function cellsFor(faza, row, st) {
    st = st || {};
    var out = { file: { text: "", red: false }, obs: [], sursa: st.sursa || "" };
    if (st.stare === "lipsa") {
      out.file = { text: "–", red: true };
      if (st.nota) out.obs.push({ text: st.nota, red: false });
      out.obs.push({ text: "LIPSEȘTE", red: true });
      out.sursa = "";
    } else if (st.stare === "mem") {
      out.file.text = "în memoriu";
      out.obs.push({ text: "se află în memoriul tehnic" + (st.pag ? " (pag. " + st.pag + ")" : ""), red: false });
      if (st.nota) out.obs.push({ text: st.nota, red: false });
    } else if (st.stare === "ok") {
      out.file.text = st.file ? String(st.file) : "";
      if (st.nota) out.obs.push({ text: st.nota, red: false });
      var fl = flagsFor(faza, row.kind).filter(function (f) { return st.flags && st.flags[f]; })
        .map(function (f) { return FLAGS[f]; });
      if (fl.length) out.obs.push({ text: fl.join(", "), red: true });
    }
    return out;
  }

  function stats(l) {
    var m = MODELE[l.faza], s = { total: 0, ok: 0, lipsa: 0, probleme: 0, neverificat: 0 };
    m.volume.forEach(function (v) {
      v.rows.forEach(function (r) {
        var st = (l.rows || {})[r.k] || {};
        s.total++;
        if (st.stare === "lipsa") s.lipsa++;
        else if (!st.stare) s.neverificat++;
        else {
          var bad = st.stare === "ok" && flagsFor(l.faza, r.kind).some(function (f) { return st.flags && st.flags[f]; });
          if (bad) s.probleme++; else s.ok++;
        }
      });
    });
    return s;
  }

  function buildModel(l, opts) {
    var m = MODELE[l.faza], withSursa = !!(opts && opts.sursa);
    var cols = ["Nr. crt.", "Denumire", "Nr. file", "Observații"];
    if (withSursa) cols.push("Sursa (de unde a fost extras)");
    var rows = [];
    m.volume.forEach(function (v) {
      rows.push({ type: "vol", text: v.titlu });
      v.rows.forEach(function (r) {
        var c = cellsFor(l.faza, r, (l.rows || {})[r.k]);
        rows.push({ type: "row", nr: r.nr, den: r.den, file: c.file, obs: c.obs, sursa: c.sursa });
      });
    });
    var meta = [
      ["Lucrarea: ", l.denumire || ""],
      ["Proiectant: ", l.proiectant || ""],
      ["Faza: ", m.faza + (l.revizie ? ", " + l.revizie : "")]
    ];
    return { titlu: m.titlu, subtitlu: "BORDEROU", meta: meta, cols: cols, rows: rows,
      withSursa: withSursa, intocmit: "Întocmit: " + (l.intocmit || "Daniel Drăghicioiu") };
  }

  function safeName(s) {
    return String(s || "").normalize("NFD").replace(/[̀-ͯ]/g, "")
      .replace(/[^A-Za-z0-9]+/g, "_").replace(/^_+|_+$/g, "");
  }
  function folderName(l) {
    var n = safeName(l.scurt || l.denumire).toUpperCase() || "LUCRARE";
    if (l.faza === "PTE") return "PTE_" + n;
    var s = "DTAC_" + n;
    if (l.acNr) s += "_AC" + safeName(l.acNr) + (l.acData ? "_" + String(l.acData).replace(/[^0-9.]/g, "") : "");
    return s;
  }
  function folderTree(l) {
    var m = MODELE[l.faza], root = folderName(l), out = [root + "/00. Coperta si borderou"];
    m.volume.forEach(function (v) {
      var dirs = (v.extraDirs || []).slice();
      v.rows.forEach(function (r) { (r.dirs || [r.dir]).forEach(function (d) { dirs.push(d); }); });
      dirs.sort(function (a, b) { return a.localeCompare(b, "en", { numeric: true }); });
      dirs.forEach(function (d) { out.push(root + "/" + v.dir + "/" + d); });
    });
    return out;
  }
  function fileBase(l) { return "00. OPIS - Borderou " + l.faza + " " + (safeName(l.scurt || l.denumire).slice(0, 60) || "lucrare"); }

  /* ---------- Word (.docx) ---------- */
  function esc(s) { return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }
  function run(t, o) {
    o = o || {};
    return "<w:r><w:rPr>" + (o.b ? "<w:b/>" : "") + (o.red ? '<w:color w:val="FF0000"/>' : "") +
      (o.sz ? '<w:sz w:val="' + o.sz + '"/>' : "") + '</w:rPr><w:t xml:space="preserve">' + esc(t) + "</w:t></w:r>";
  }
  function par(inner, o) {
    o = o || {};
    return "<w:p><w:pPr>" + (o.jc ? '<w:jc w:val="' + o.jc + '"/>' : "") +
      '<w:spacing w:before="' + (o.before || 0) + '" w:after="' + (o.after == null ? 60 : o.after) + '"/></w:pPr>' + inner + "</w:p>";
  }
  function tc(w, inner, o) {
    o = o || {};
    return "<w:tc><w:tcPr><w:tcW w:w=\"" + w + '" w:type="dxa"/>' + (o.span ? '<w:gridSpan w:val="' + o.span + '"/>' : "") +
      (o.fill ? '<w:shd w:val="clear" w:color="auto" w:fill="' + o.fill + '"/>' : "") + '<w:vAlign w:val="center"/></w:tcPr>' + inner + "</w:tc>";
  }
  function docxXml(model) {
    var W = model.withSursa ? [600, 3300, 900, 2400, 2438] : [800, 4200, 1300, 3338];
    var total = W.reduce(function (a, b) { return a + b; }, 0);
    var b = "";
    b += par(run(model.titlu, { b: true, sz: 28 }), { jc: "center", after: 60 });
    b += par(run(model.subtitlu, { b: true, sz: 26 }), { jc: "center", after: 200 });
    model.meta.forEach(function (m) { b += par(run(m[0], { b: true }) + run(m[1]), { after: 40 }); });
    b += par("", { after: 120 });
    var t = '<w:tbl><w:tblPr><w:tblW w:w="' + total + '" w:type="dxa"/><w:tblBorders>';
    ["top", "left", "bottom", "right", "insideH", "insideV"].forEach(function (s) {
      t += "<w:" + s + ' w:val="single" w:sz="4" w:space="0" w:color="000000"/>';
    });
    t += '</w:tblBorders><w:tblLayout w:type="fixed"/><w:tblCellMar><w:left w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/></w:tblCellMar></w:tblPr><w:tblGrid>';
    W.forEach(function (w) { t += '<w:gridCol w:w="' + w + '"/>'; });
    t += "</w:tblGrid><w:tr><w:trPr><w:tblHeader/></w:trPr>";
    model.cols.forEach(function (c, i) { t += tc(W[i], par(run(c, { b: true }), { jc: "center", before: 40, after: 40 }), { fill: "D9D9D9" }); });
    t += "</w:tr>";
    model.rows.forEach(function (r) {
      t += "<w:tr><w:trPr><w:cantSplit/></w:trPr>";
      if (r.type === "vol") {
        t += tc(total, par(run(r.text, { b: true }), { before: 40, after: 40 }), { span: W.length, fill: "DDEBF7" });
      } else {
        t += tc(W[0], par(run(r.nr), { jc: "center", before: 30, after: 30 }));
        t += tc(W[1], par(run(r.den), { before: 30, after: 30 }));
        t += tc(W[2], par(run(r.file.text, { red: r.file.red }), { jc: "center", before: 30, after: 30 }));
        var obs = r.obs.length ? r.obs.map(function (o) { return par(run(o.text, { red: o.red, b: o.red && o.text === "LIPSEȘTE" }), { before: 30, after: 30 }); }).join("") : par("", { before: 30, after: 30 });
        t += tc(W[3], obs);
        if (model.withSursa) t += tc(W[4], par(run(r.sursa || ""), { before: 30, after: 30 }));
      }
      t += "</w:tr>";
    });
    t += "</w:tbl>";
    b += t + par("", { after: 200 }) + par(run(model.intocmit), { jc: "right" });
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>' +
      b + '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1134" w:right="1134" w:bottom="1134" w:left="1134" w:header="708" w:footer="708" w:gutter="0"/></w:sectPr></w:body></w:document>';
  }
  function docx(model, JSZip, outType) {
    var z = new JSZip();
    z.file("[Content_Types].xml", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>');
    z.file("_rels/.rels", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>');
    z.file("word/_rels/document.xml.rels", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>');
    z.file("word/styles.xml", '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial"/><w:sz w:val="20"/><w:szCs w:val="20"/><w:lang w:val="ro-RO"/></w:rPr></w:rPrDefault></w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style></w:styles>');
    z.file("word/document.xml", docxXml(model));
    return z.generateAsync({ type: outType || "blob" });
  }

  /* ---------- PDF ---------- */
  function pdf(model, jsPDF, fonts) {
    var land = model.withSursa;
    var doc = new jsPDF({ orientation: land ? "landscape" : "portrait", unit: "mm", format: "a4" });
    doc.addFileToVFS("LS-R.ttf", fonts.normal); doc.addFont("LS-R.ttf", "LS", "normal");
    doc.addFileToVFS("LS-B.ttf", fonts.bold); doc.addFont("LS-B.ttf", "LS", "bold");
    var PW = doc.internal.pageSize.getWidth(), PH = doc.internal.pageSize.getHeight(), M = 15, y = M + 4;
    var FS = 9, LH = 4.1, PAD = 1.6;
    function font(b, sz) { doc.setFont("LS", b ? "bold" : "normal"); doc.setFontSize(sz || FS); }
    font(true, 13); doc.setTextColor(0);
    doc.splitTextToSize(model.titlu, PW - 2 * M).forEach(function (ln) { doc.text(ln, PW / 2, y, { align: "center" }); y += 6; });
    font(true, 12); doc.text(model.subtitlu, PW / 2, y, { align: "center" }); y += 9;
    model.meta.forEach(function (m) {
      font(true, 10); doc.text(m[0], M, y); var w = doc.getTextWidth(m[0]);
      font(false, 10);
      var lines = doc.splitTextToSize(m[1] || "", PW - 2 * M - w);
      lines.forEach(function (ln, i) { doc.text(ln, M + w, y); if (i < lines.length - 1) y += 4.6; });
      y += 5.4;
    });
    y += 2;
    var avail = PW - 2 * M;
    var frac = land ? [0.06, 0.32, 0.08, 0.24, 0.30] : [0.08, 0.47, 0.11, 0.34];
    var W = frac.map(function (f) { return f * avail; });
    var X = []; W.reduce(function (a, w, i) { X[i] = a; return a + w; }, M);
    doc.setLineWidth(0.2); doc.setDrawColor(0);

    function header() {
      font(true);
      var lines = model.cols.map(function (c, i) { return doc.splitTextToSize(c, W[i] - 2 * PAD); });
      var h = Math.max.apply(null, lines.map(function (l) { return l.length; })) * LH + 2 * PAD;
      lines.forEach(function (ls, i) {
        doc.setFillColor(217, 217, 217); doc.rect(X[i], y, W[i], h, "FD");
        doc.setTextColor(0);
        ls.forEach(function (ln, k) { doc.text(ln, X[i] + W[i] / 2, y + PAD + 3 + k * LH, { align: "center" }); });
      });
      y += h;
    }
    function need(h) { if (y + h > PH - M) { doc.addPage(); y = M; header(); } }
    header();
    model.rows.forEach(function (r) {
      if (r.type === "vol") {
        var h0 = LH + 2 * PAD; need(h0);
        doc.setFillColor(221, 235, 247); doc.rect(M, y, avail, h0, "FD");
        font(true); doc.setTextColor(0); doc.text(r.text, M + PAD, y + PAD + 3); y += h0; return;
      }
      font(false);
      var cells = [
        [{ text: r.nr, red: false }], [{ text: r.den, red: false }], [r.file], r.obs
      ];
      if (land) cells.push([{ text: r.sursa || "", red: false }]);
      var laid = cells.map(function (parts, i) {
        var out = [];
        parts.forEach(function (p) {
          font(p.red && p.text === "LIPSEȘTE");
          doc.splitTextToSize(p.text || "", W[i] - 2 * PAD).forEach(function (ln) { out.push({ t: ln, red: p.red, b: p.red && p.text === "LIPSEȘTE" }); });
        });
        return out;
      });
      var h = Math.max(1, Math.max.apply(null, laid.map(function (l) { return l.length; }))) * LH + 2 * PAD;
      need(h);
      laid.forEach(function (ls, i) {
        doc.rect(X[i], y, W[i], h, "S");
        var center = i === 0 || i === 2;
        ls.forEach(function (ln, k) {
          font(ln.b); doc.setTextColor(ln.red ? 255 : 0, 0, 0);
          doc.text(ln.t, center ? X[i] + W[i] / 2 : X[i] + PAD, y + PAD + 3 + k * LH, center ? { align: "center" } : undefined);
        });
      });
      y += h;
    });
    doc.setTextColor(0); font(false, 10);
    if (y + 14 > PH - M) { doc.addPage(); y = M; }
    doc.text(model.intocmit, PW - M, y + 10, { align: "right" });
    return doc.output("arraybuffer");
  }

  var api = { FLAGS: FLAGS, MODELE: MODELE, flagsFor: flagsFor, cellsFor: cellsFor, stats: stats, buildModel: buildModel,
    folderName: folderName, folderTree: folderTree, fileBase: fileBase, docx: docx, pdf: pdf };
  g.OPIS = api;
  if (typeof module !== "undefined" && module.exports) module.exports = api;
})(typeof globalThis !== "undefined" ? globalThis : this);
