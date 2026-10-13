/* Completează PDF-ul oficial „Cerere pentru eliberarea avizului MAI” (Anexa 2).
   Rulează integral în browser: datele nu pleacă nicăieri. */
(function (root) {
  'use strict';

  // câmpurile cu o singură linie: cheie internă -> nume câmp în PDF
  var SINGLE = {
    nume: 'DENUMIRENUME PRENUME',
    reprezentant: 'NUME PRENUME REPREZENTNT',
    c_loc: 'LO LITTE', c_str: 'str', c_nr: 'nr',
    c_bl: 'bl', c_sc: 'sc', c_et: 'et', c_ap: 'ap',
    c_rest: 'fill_10', c_judet: 'fill_11',
    destinatar: 'DESTINTR', tel: 'Nr Telefon', email: 'Email',
    cu_nr: 'Nr', cu_data: 'din data', cu_emis: 'emis de',
    cu_valab: 'Valabilitate', cu_prel: 'prelungire  ertificat de Urbanism',
    a_loc: 'LO LITTE_2', a_str: 'str_2', a_nr: 'nr_2',
    a_rest: 'fill_26', a_judet: 'fill_27',
    a_cad: 'nr cad', a_cf: 'F nr'
  };
  // câmpurile pe mai multe rânduri din formular
  var MULTI = {
    continut: ['fill_20', 'conform Certificatului de Urbanism', 'Text3'],
    beneficiari: ['ENEFI IRi', 'Text4']
  };
  var MAX = 10, MIN = 6, PAD = 4;

  function fieldWidth(f) {
    var w = f.acroField.getWidgets()[0];
    return w.getRectangle().width - PAD;
  }

  function fitSize(font, text, width) {
    var w = font.widthOfTextAtSize(text, MAX);
    if (w <= width) return MAX;
    return Math.max(MIN, Math.floor((MAX * width / w) * 10) / 10);
  }

  // împarte textul pe rândurile disponibile; micșorează fontul dacă nu încape
  function wrap(font, text, widths) {
    for (var size = MAX; size >= MIN; size -= 0.5) {
      var lines = layout(font, text, widths, size);
      if (lines) return { lines: lines, size: size };
    }
    // nu încape nici la MIN: ultimul rând primește restul, micșorat
    var l = layout(font, text, widths, MIN, true);
    return { lines: l, size: MIN };
  }

  function layout(font, text, widths, size, force) {
    var words = String(text).replace(/\s+/g, ' ').trim().split(' ');
    var lines = [], cur = '', i = 0;
    for (var k = 0; k < words.length; k++) {
      var test = cur ? cur + ' ' + words[k] : words[k];
      if (font.widthOfTextAtSize(test, size) <= widths[i] || !cur) {
        cur = test;
      } else if (i < widths.length - 1) {
        lines.push(cur); cur = words[k]; i++;
      } else if (force) {
        cur = test;
      } else {
        return null;
      }
    }
    lines.push(cur);
    if (!force && font.widthOfTextAtSize(lines[lines.length - 1], size) > widths[lines.length - 1]) return null;
    while (lines.length < widths.length) lines.push('');
    return lines;
  }

  async function buildPdf(PDFLib, fontkit, pdfBytes, fontBytes, data, opts) {
    opts = opts || {};
    var doc = await PDFLib.PDFDocument.load(pdfBytes);
    doc.registerFontkit(fontkit);
    var font = await doc.embedFont(fontBytes, { subset: true });
    var form = doc.getForm();

    // listele au valoare internă (ex. „puz”) și text afișat („P.U.Z.”);
    // desenăm textul afișat, apoi punem la loc valoarea internă
    var dropdowns = [];
    function setDropdown(name, value) {
      var dd = form.getDropdown(name);
      var hit = dd.acroField.getOptions().find(function (o) {
        return o.value && o.value.decodeText() === value;
      });
      if (!hit) return;
      dropdowns.push({ dd: dd, value: hit.value, display: hit.display || hit.value });
    }
    setDropdown('tip_dc', data.tip_dc || 'dtac');
    setDropdown('tip_entitate', data.tip_entitate || 'pfiz');

    Object.keys(SINGLE).forEach(function (k) {
      var v = (data[k] || '').toString().trim();
      var f = form.getTextField(SINGLE[k]);
      f.setText(v);
      f.setFontSize(v ? fitSize(font, v, fieldWidth(f)) : MAX);
    });

    Object.keys(MULTI).forEach(function (k) {
      var names = MULTI[k];
      var fields = names.map(function (n) { return form.getTextField(n); });
      var v = (data[k] || '').toString().trim();
      var res = v ? wrap(font, v, fields.map(fieldWidth)) : { lines: names.map(function () { return ''; }), size: MAX };
      fields.forEach(function (f, i) { f.setText(res.lines[i] || ''); f.setFontSize(res.size); });
    });

    form.updateFieldAppearances(font);
    dropdowns.forEach(function (x) {
      var V = PDFLib.PDFName.of('V');
      x.dd.acroField.dict.set(V, x.display);
      x.dd.updateAppearances(font);
      x.dd.acroField.dict.set(V, x.value);
    });
    if (opts.flatten) form.flatten();
    return doc.save();
  }

  var api = { buildPdf: buildPdf, SINGLE: SINGLE, MULTI: MULTI };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.AvizMAI = api;
})(this);
