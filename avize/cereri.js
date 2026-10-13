/* Cereri de avize – definiții și generare PDF (rulează în browser, fără server). */
(function (root) {
  'use strict';

  // Documente care se anexează de obicei la orice cerere de aviz
  var DOCS = {
    cu: 'Certificatul de urbanism (copie)',
    incadrare: 'Plan de încadrare în zonă',
    situatie: 'Plan de situație cu amplasamentul lucrării',
    memoriu: 'Memoriu tehnic de prezentare a lucrării',
    id: 'Act de identitate (persoană fizică) / certificat de înregistrare – CUI (persoană juridică)',
    proprietate: 'Dovada dreptului asupra imobilului / extras de carte funciară',
    imputernicire: 'Împuternicire pentru persoana mandatată (dacă este cazul)',
    plata: 'Dovada plății tarifului de emitere a avizului (dacă este cazul)'
  };
  var BASE = ['cu', 'incadrare', 'situatie', 'memoriu', 'id', 'proprietate'];

  /* src: de unde vine avizatorul
       'j:<harta>'  – după județul amplasamentului
       'l:<harta>'  – listă de operatori pe județ, se alege
       'f:<cheie>'  – avizator fix (național)
       'm'          – îl completează utilizatorul
     aviz: cum apare în cerere („solicit emiterea …”) */
  var AVIZE = [
    { g: 'Utilități (CU pct. d.1)', id: 'apa', t: 'Alimentare cu apă / canalizare', src: 'm', hint: 'operatorul local de apă-canal', aviz: 'avizului privind alimentarea cu apă și canalizarea (aviz de amplasament / coexistență cu rețelele de apă-canal)' },
    { g: 'Utilități (CU pct. d.1)', id: 'energie', t: 'Alimentare cu energie electrică', src: 'j:energie', aviz: 'avizului de amplasament privind coexistența cu rețelele electrice de distribuție', extra: ['Plan de situație în format PDF și DWG, coordonate Stereo 70'] },
    { g: 'Utilități (CU pct. d.1)', id: 'gaze', t: 'Gaze naturale', src: 'l:gaze', hint: 'operatorul de distribuție gaze din localitate', aviz: 'avizului de amplasament privind coexistența cu rețelele de distribuție a gazelor naturale' },
    { g: 'Utilități (CU pct. d.1)', id: 'termica', t: 'Alimentare cu energie termică', src: 'm', hint: 'operatorul local de termoficare', aviz: 'avizului privind coexistența cu rețelele de alimentare cu energie termică' },
    { g: 'Utilități (CU pct. d.1)', id: 'orange', t: 'Telefonizare – Orange (fost Telekom)', src: 'f:orange', aviz: 'avizului de amplasament privind coexistența cu rețelele de comunicații electronice' },
    { g: 'Utilități (CU pct. d.1)', id: 'digi', t: 'Telefonizare – Digi (RCS & RDS)', src: 'f:digi', aviz: 'avizului de amplasament privind coexistența cu rețelele de comunicații electronice' },
    { g: 'Utilități (CU pct. d.1)', id: 'salubritate', t: 'Salubritate', src: 'm', hint: 'operatorul de salubrizare din localitate', aviz: 'avizului de salubrizare' },
    { g: 'Utilități (CU pct. d.1)', id: 'transport_urban', t: 'Transport urban', src: 'm', hint: 'operatorul de transport public local', aviz: 'avizului privind transportul public urban' },

    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'isu_psi', t: 'Securitate la incendiu – ISU', src: 'j:isu', aviz: 'avizului de securitate la incendiu', extra: ['Documentația tehnică (D.T.A.C./D.T.A.D.), semnată electronic calificat'] },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'isu_pc', t: 'Protecție civilă – ISU', src: 'j:isu', aviz: 'avizului de protecție civilă', extra: ['Documentația tehnică (D.T.A.C./D.T.A.D.), semnată electronic calificat'] },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'dsp', t: 'Sănătatea populației – DSP', src: 'j:dsp', aviz: 'notificării / asistenței de specialitate de sănătate publică privind conformarea cu normele de igienă și sănătate publică' },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'djc', t: 'Cultură / monumente istorice – DJC', src: 'j:djc', aviz: 'avizului privind lucrările în zona de protecție a monumentelor istorice / siturilor arheologice' },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'apele', t: 'Gospodărirea apelor – Apele Române (SGA)', src: 'j:apele', aviz: 'avizului de gospodărire a apelor', extra: ['Documentația tehnică pentru fundamentarea avizului de gospodărire a apelor'] },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'drum_judetean', t: 'Drumuri județene – Consiliul Județean', src: 'j:drumuri_judetene', aviz: 'acordului prealabil al administratorului drumului pentru lucrări în zona drumului județean' },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'drum_national', t: 'Drumuri naționale – CNAIR / DRDP', src: 'j:drdp', aviz: 'acordului prealabil al administratorului drumului pentru lucrări în zona drumului național' },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'politie', t: 'Poliția rutieră – IPJ', src: 'j:politie', aviz: 'avizului poliției rutiere privind accesul și organizarea circulației' },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'anif', t: 'Îmbunătățiri funciare – ANIF', src: 'j:anif', aviz: 'avizului privind lucrările în zona amenajărilor de îmbunătățiri funciare' },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'cfr', t: 'Căi ferate – CNCF „CFR”', src: 'f:cfr', aviz: 'avizului de amplasare în zona de protecție a infrastructurii feroviare', extra: ['CD/stick cu planurile de situație în format DWG'] },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'transgaz', t: 'Transport gaze – Transgaz', src: 'f:transgaz', aviz: 'avizului în vederea autorizării executării construcțiilor amplasate în vecinătatea obiectivelor sistemului național de transport gaze naturale', extra: ['Plan de situație în format PDF și DWG, coordonate Stereo 70, sc. 1:500'] },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'transelectrica', t: 'Transport energie – Transelectrica', src: 'f:transelectrica', aviz: 'avizului de amplasament privind coexistența cu instalațiile rețelei electrice de transport' },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'conpet', t: 'Transport țiței – CONPET', src: 'f:conpet', aviz: 'avizului de amplasament privind coexistența cu conductele sistemului național de transport țiței, gazolină, condensat și etan' },
    { g: 'Alte avize și acorduri (CU pct. d.2)', id: 'romgaz', t: 'Romgaz / Depogaz', src: 'o:romgaz_medias,romgaz_mures,depogaz', aviz: 'avizului de amplasament privind vecinătatea obiectivelor de producție și înmagazinare a gazelor naturale' },

    { g: 'Administrația centrală (CU pct. d.3)', id: 'mai', t: 'Ministerul Afacerilor Interne', src: 'f:mai', aviz: 'avizului Ministerului Afacerilor Interne', oficial: 'mai' },
    { g: 'Administrația centrală (CU pct. d.3)', id: 'mapn', t: 'Ministerul Apărării Naționale', src: 'f:mapn', aviz: 'avizului Ministerului Apărării Naționale' },
    { g: 'Administrația centrală (CU pct. d.3)', id: 'sri', t: 'Serviciul Român de Informații', src: 'f:sri', aviz: 'avizului Serviciului Român de Informații' },
    { g: 'Administrația centrală (CU pct. d.3)', id: 'sts', t: 'Serviciul de Telecomunicații Speciale', src: 'f:sts', aviz: 'avizului Serviciului de Telecomunicații Speciale' },
    { g: 'Administrația centrală (CU pct. d.3)', id: 'aacr', t: 'Aviație civilă – AACR', src: 'f:aacr', aviz: 'avizului aeronautic' },

    { g: 'Mediu (CU pct. e)', id: 'mediu', t: 'Protecția mediului – Direcția Județeană de Mediu (fosta APM)', src: 'j:apm', aviz: 'actului administrativ al autorității competente pentru protecția mediului (evaluarea inițială a proiectului)', extra: ['Notificare / memoriu de prezentare a proiectului'] },

    { g: 'Alt aviz', id: 'altul', t: 'Alt aviz cerut prin CU', src: 'm', hint: 'denumirea avizatorului', aviz: '', custom: true }
  ];

  var TIP_DC = { dtac: 'D.T.A.C.', dtad: 'D.T.A.D.', pud: 'P.U.D.', puz: 'P.U.Z.', pug: 'P.U.G.', patz: 'P.A.T.Z.', patj: 'P.A.T.J.', patn: 'P.A.T.N.' };

  /* ---------- PDF ---------- */
  var A4 = [595.28, 841.89], ML = 62, MR = 62, W = A4[0] - ML - MR;

  function words(font, text, size, width) {
    var out = [];
    String(text || '').split('\n').forEach(function (para) {
      var cur = '';
      para.split(/\s+/).filter(Boolean).forEach(function (w) {
        var t = cur ? cur + ' ' + w : w;
        if (font.widthOfTextAtSize(t, size) <= width || !cur) cur = t;
        else { out.push(cur); cur = w; }
      });
      out.push(cur);
    });
    return out;
  }

  function Writer(doc, reg, bold) {
    this.doc = doc; this.reg = reg; this.bold = bold;
    this.newPage();
  }
  Writer.prototype.newPage = function () { this.page = this.doc.addPage(A4); this.y = A4[1] - 58; };
  Writer.prototype.need = function (h) { if (this.y - h < 60) this.newPage(); };
  Writer.prototype.text = function (s, o) {
    o = o || {};
    var f = o.bold ? this.bold : this.reg, size = o.size || 11, lh = o.lh || size * 1.38;
    var x0 = ML + (o.indent || 0), width = (o.width || W) - (o.indent || 0);
    var self = this;
    words(f, s, size, width).forEach(function (line) {
      self.need(lh);
      var x = x0;
      if (o.align === 'center') x = ML + (W - f.widthOfTextAtSize(line, size)) / 2;
      if (o.align === 'right') x = ML + W - f.widthOfTextAtSize(line, size);
      self.page.drawText(line, { x: x, y: self.y - size, size: size, font: f, color: o.color });
      self.y -= lh;
    });
    if (o.after) this.y -= o.after;
  };
  // paragraf cu porțiuni îngroșate: [['text normal', false], ['text bold', true], ...]
  Writer.prototype.rich = function (parts, o) {
    o = o || {};
    var size = o.size || 11, lh = size * 1.42, self = this, x0 = ML + (o.indent || 0), maxX = ML + W;
    var x = x0 + (o.firstIndent || 0);
    var toks = [];
    parts.forEach(function (p) {
      String(p[0]).split(/(\s+)/).forEach(function (t) { if (t) toks.push([t, p[1]]); });
    });
    self.need(lh);
    var lineStart = true;
    toks.forEach(function (tk) {
      var f = tk[1] ? self.bold : self.reg;
      if (/^\s+$/.test(tk[0])) { if (!lineStart) x += f.widthOfTextAtSize(' ', size); return; }
      var w = f.widthOfTextAtSize(tk[0], size);
      if (x + w > maxX && !lineStart) { self.y -= lh; self.need(lh); x = x0; }
      self.page.drawText(tk[0], { x: x, y: self.y - size, size: size, font: f });
      x += w; lineStart = false;
    });
    self.y -= lh;
    if (o.after) self.y -= o.after;
  };
  Writer.prototype.box = function (checked, label, o) {
    o = o || {};
    var size = 11, lh = size * 1.38, s = 8.5, self = this;
    var lines = words(this.reg, label, size, W - 20 - (o.indent || 0));
    this.need(lh * lines.length);
    var bx = ML + (o.indent || 0), by = this.y - size + 0.5;
    this.page.drawRectangle({ x: bx, y: by, width: s, height: s, borderWidth: 0.8, borderColor: PDFLibRef.rgb(0, 0, 0) });
    if (checked) {
      this.page.drawLine({ start: { x: bx + 1.6, y: by + 4.4 }, end: { x: bx + 3.6, y: by + 1.8 }, thickness: 1.3 });
      this.page.drawLine({ start: { x: bx + 3.6, y: by + 1.8 }, end: { x: bx + 7.2, y: by + 7.2 }, thickness: 1.3 });
    }
    lines.forEach(function (line) {
      self.page.drawText(line, { x: bx + 16, y: self.y - size, size: size, font: self.reg });
      self.y -= lh;
    });
  };
  Writer.prototype.gap = function (h) { this.y -= h; };
  Writer.prototype.rule = function () {
    this.need(10);
    this.page.drawLine({ start: { x: ML, y: this.y }, end: { x: ML + W, y: this.y }, thickness: 0.5, color: PDFLibRef.rgb(0.6, 0.6, 0.6) });
    this.y -= 10;
  };

  var PDFLibRef = null;

  function join(arr, sep) { return arr.filter(function (x) { return x && String(x).trim(); }).join(sep || ', '); }

  function adresa(p, d) {
    var s = join([
      d[p + 'loc'],
      d[p + 'str'] && ('str. ' + d[p + 'str']),
      d[p + 'nr'] && ('nr. ' + d[p + 'nr']),
      d[p + 'bl'] && ('bl. ' + d[p + 'bl']),
      d[p + 'sc'] && ('sc. ' + d[p + 'sc']),
      d[p + 'et'] && ('et. ' + d[p + 'et']),
      d[p + 'ap'] && ('ap. ' + d[p + 'ap']),
      d[p + 'rest'],
      d[p + 'judet'] && (/^sector/i.test(d[p + 'judet']) ? d[p + 'judet'] : 'județul ' + d[p + 'judet'])
    ]);
    return s;
  }

  /* d = datele comune, item = {aviz, avizator:{nume, adresa, telefon, email}, docs:[label], titluAviz} */
  function cerereGenerica(w, d, item) {
    var pj = d.tip_entitate === 'pjur';
    w.text('Nr. înregistrare ................ / ....................', { size: 10, align: 'right', after: 18 });

    w.text('Către,', { size: 11 });
    w.text(item.avizator.nume || '.................................................................', { bold: true, size: 12 });
    if (item.avizator.adresa) w.text(item.avizator.adresa, { size: 10.5 });
    var contact = join([item.avizator.telefon && ('Tel. ' + item.avizator.telefon), item.avizator.email && ('e-mail: ' + item.avizator.email)], '   •   ');
    if (contact) w.text(contact, { size: 10.5 });
    w.gap(16);

    w.text('CERERE', { bold: true, size: 16, align: 'center', after: 2 });
    w.text('pentru emiterea ' + item.aviz, { size: 11.5, align: 'center', after: 14 });

    var parts = [];
    parts.push([(pj ? 'Subscrisa ' : 'Subsemnatul/Subsemnata '), false]);
    parts.push([d.nume, true]);
    if (d.cnp) parts.push([', ' + (pj ? 'CUI ' : 'CNP ') + d.cnp, false]);
    parts.push([', cu ' + (pj ? 'sediul' : 'domiciliul') + ' în ' + adresa('c_', d), false]);
    if (pj && d.reprezentant) parts.push([', reprezentată prin ' + d.reprezentant, false]);
    parts.push([', telefon ' + (d.tel || '—') + (d.email ? ', e-mail ' + d.email : ''), false]);
    parts.push([', solicit emiterea ' + item.aviz + ' pentru obiectivul ', false]);
    parts.push(['„' + d.continut + '”', true]);
    parts.push([', în baza Certificatului de urbanism nr. ' + d.cu_nr + ' din ' + d.cu_data + ', emis de ' + d.cu_emis + (d.cu_valab ? ', valabil până la ' + d.cu_valab : '') + '.', false]);
    w.rich(parts, { firstIndent: 28, after: 10 });

    w.text('Date despre lucrare', { bold: true, size: 11.5, after: 2 });
    var rows = [
      ['Amplasament', adresa('a_', d)],
      ['Nr. cadastral / CF', join([d.a_cad && ('nr. cad. ' + d.a_cad), d.a_cf && ('CF nr. ' + d.a_cf)], '; ') || '—'],
      ['Beneficiar(i)', d.beneficiari],
      ['Documentație', TIP_DC[d.tip_dc] || ''],
      ['Proiectant', d.proiectant]
    ];
    rows.forEach(function (r) {
      if (!r[1]) return;
      w.rich([[r[0] + ': ', true], [r[1], false]], { size: 10.5, indent: 12 });
    });
    if (item.detalii) w.rich([['Precizări: ', true], [item.detalii, false]], { size: 10.5, indent: 12 });
    w.gap(10);

    w.text('Anexez prezentei cereri:', { bold: true, size: 11.5, after: 3 });
    item.docs.forEach(function (doc) { w.box(true, doc, { indent: 12 }); });
    w.gap(10);

    w.text('Doresc ca avizul să îmi fie transmis:', { bold: true, size: 11.5, after: 3 });
    w.box(d.primire === 'email', 'prin e-mail' + (d.email ? ', la adresa ' + d.email : ''), { indent: 12 });
    w.box(d.primire === 'posta', 'prin poștă, la adresa de corespondență de mai sus', { indent: 12 });
    w.box(d.primire === 'ridicare', 'îl ridic personal de la sediul emitentului', { indent: 12 });
    w.gap(12);

    w.text('Declar pe propria răspundere că datele înscrise în prezenta cerere sunt reale și complete și îmi exprim acordul pentru prelucrarea datelor cu caracter personal în scopul soluționării cererii, conform Regulamentului (UE) 2016/679.', { size: 10, after: 16 });

    if (w.y - 62 < 40) w.newPage();
    var yy = w.y;
    var p = w.page;
    p.drawText('Data: ' + (d.data || '....................'), { x: ML, y: yy - 11, size: 11, font: w.reg });
    var semn = pj ? (d.reprezentant ? d.nume + ', prin ' + d.reprezentant : d.nume) : d.nume;
    var colX = ML + W * 0.52;
    p.drawText('Semnătura solicitantului,', { x: colX, y: yy - 11, size: 11, font: w.reg });
    var sl = words(w.reg, semn, 10.5, W * 0.48);
    sl.forEach(function (l, i) { p.drawText(l, { x: colX, y: yy - 28 - i * 14, size: 10.5, font: w.bold }); });
    p.drawText('........................................', { x: colX, y: yy - 46 - (sl.length - 1) * 14, size: 11, font: w.reg });
    w.y = yy - 70;
  }

  async function buildCerere(lib, fontkit, fonts, d, item) {
    PDFLibRef = lib;
    var doc = await lib.PDFDocument.create();
    doc.registerFontkit(fontkit);
    var reg = await doc.embedFont(fonts.reg, { subset: true });
    var bold = await doc.embedFont(fonts.bold, { subset: true });
    doc.setTitle('Cerere ' + item.titlu);
    doc.setLanguage('ro-RO');
    var w = new Writer(doc, reg, bold);
    cerereGenerica(w, d, item);
    return doc.save();
  }

  async function merge(lib, list) {
    var out = await lib.PDFDocument.create();
    for (var i = 0; i < list.length; i++) {
      var src = await lib.PDFDocument.load(list[i]);
      var pages = await out.copyPages(src, src.getPageIndices());
      pages.forEach(function (p) { out.addPage(p); });
    }
    return out.save();
  }

  var api = { AVIZE: AVIZE, DOCS: DOCS, BASE: BASE, TIP_DC: TIP_DC, buildCerere: buildCerere, merge: merge, adresa: adresa };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.Cereri = api;
})(this);
