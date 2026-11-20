/* Citește un Certificat de Urbanism (PDF cu text, PDF scanat sau poză) și scoate din el
   datele pentru formular și avizele cerute. Totul rulează în browser.
   CU.read(files, onProgress) -> Promise<{text, ocr}>;  CU.parse(text) -> rezultat. */
(function (root) {
  'use strict';

  /* ---------- pliere 1:1 (aceeași lungime), ca indexurile să rămână valabile pe textul original ---------- */
  var MAP = { 'ă': 'a', 'â': 'a', 'î': 'i', 'ș': 's', 'ş': 's', 'ț': 't', 'ţ': 't', 'Ă': 'a', 'Â': 'a', 'Î': 'i', 'Ș': 's', 'Ş': 's', 'Ț': 't', 'Ţ': 't' };
  function fold(s) {
    var o = '';
    for (var i = 0; i < s.length; i++) { var c = s[i]; o += MAP[c] || c.toLowerCase().charAt(0) || c; }
    return o;
  }
  function clean(s) {
    return String(s || '').replace(/\s+/g, ' ').replace(/[._…]{3,}/g, ' ').replace(/\s+([,;.])/g, '$1').replace(/^[\s,;:.\-–*]+/, '').replace(/^[\dlI]\)\s*/, '').replace(/[\s,;:\-–]+$/, '').trim();
  }
  function title(s) {
    if (s !== s.toUpperCase()) return s;
    return s.toLowerCase().replace(/(^|[\s\-„"(])([a-zăâîșț])/g, function (m, a, b) { return a + b.toUpperCase(); })
      .replace(/\b(De|Al|A|Din|Cu|Si|Și|Pentru|La|In|În)\b/g, function (w, _, i) { return i ? w.toLowerCase() : w; });
  }

  /* ---------- avizele: cuvinte-cheie pe textul pliat; `up` = sigle căutate pe textul original, cu majuscule ---------- */
  var RULES = [
    { id: 'apa', re: /alimentar[ea] cu apa|apa\s*[-–\/]\s*canal|canalizare/, box: 1 },
    { id: 'energie', re: /(?:alimentar[ea] cu )?energie electrica/, box: 1 },
    { id: 'gaze', re: /(?:^|[^a-z])gaze naturale/, not: /transport(?:ul)? (?:de |al )?gaze|productie|inmagazinare/, box: 1 },
    { id: 'termica', re: /(?:alimentar[ea] cu )?energie termica|termoficare/, box: 1 },
    { id: 'orange', re: /telefonizare|orange|telekom|comunicatii electronice/, box: 1 },
    { id: 'digi', re: /telefonizare|\bdigi\b|rcs\s*&?\s*rds/, box: 1 },
    { id: 'salubritate', re: /salubritate|salubrizare/, box: 1 },
    { id: 'transport_urban', re: /transport(?:ul)? urban/, box: 1 },
    { id: 'isu_psi', re: /securitate[a]? la incendiu/, box: 1 },
    { id: 'isu_pc', re: /protecti[ea] civila/, box: 1 },
    { id: 'dsp', re: /sanatatea populatiei|sanatate publica/, up: /\bD\.?\s?S\.?\s?P\b/, box: 1 },
    { id: 'djc', re: /directi[ae] judetean[ae] (?:de|pentru) cultura|ministerul culturii|monument(?:e|elor) istorice|sit(?:ului|urilor)? arheologic/ },
    { id: 'apele', re: /gospodarire[a]? (?:a )?apelor|apele romane|sistemul de gospodarire/, up: /\bS\.?G\.?A\b|\bA\.?N\.?A\.?R\b/ },
    { id: 'drum_judetean', re: /drum(?:ului|uri|urilor)? judete(?:an|ne)|administratorul(?:ui)? drumului judetean/, up: /\bDJ\s?\d/ },
    { id: 'drum_national', re: /drum(?:ului|uri|urilor)? national|drumuri si poduri/, up: /\bC\.?N\.?A\.?I\.?R\b|\bD\.?R\.?D\.?P\b|\bDN\s?\d/ },
    { id: 'politie', re: /politi(?:a|ei) rutier|serviciul(?:ui)? rutier|inspectoratul(?:ui)? de politie/, up: /\bI\.?P\.?J\b/ },
    { id: 'anif', re: /imbunatatiri(?:lor)? funciare/, up: /\bA\.?\s?N\.?\s?[I1l]\.?\s?F\b/ },
    { id: 'cfr', re: /cai(?:i|le|lor)? ferate|infrastructur(?:a|ii) feroviar/, up: /\bC\.?F\.?R\b/ },
    { id: 'transgaz', re: /transgaz/ },
    { id: 'transelectrica', re: /transelectrica/ },
    { id: 'conpet', re: /conpet/ },
    { id: 'romgaz', re: /romgaz|depogaz/ },
    { id: 'mai', re: /ministerul(?:ui)? afacerilor interne/, up: /\bM\.A\.I\b|\bMAI\b/ },
    { id: 'mapn', re: /ministerul(?:ui)? apararii/, up: /\bM\.?Ap\.?N\b/ },
    { id: 'sri', re: /serviciul(?:ui)? roman de informatii/, up: /\bS\.R\.I\b|\bSRI\b/ },
    { id: 'sts', re: /telecomunicatii speciale/, up: /\bS\.T\.S\b|\bSTS\b/ },
    { id: 'aacr', re: /aeronautic|aviati(?:e|a|ei) civil/, up: /\bA\.?A\.?C\.?R\b/ },
    { id: 'mediu', re: /protectia mediului|agenti[ae] (?:judeteana )?(?:pentru|de) protectia|directia judeteana de mediu/, up: /\bA\.?P\.?M\b/ }
  ];
  var MARK = /(?:^|[\s\[(|])[xX×✓✔☒☑■▣⊠✗✘](?:$|[\s\])|])/;

  function first(re, s) { var m = re.exec(s); return m ? { i: m.index, len: m[0].length } : null; }

  function findAvize(text, low) {
    // secțiunea „avizele și acordurile stabilite prin certificatul de urbanism” … până la taxe / valabilitate
    var a = low.search(/avizele si acordurile|d\.?\s?1\s*[).]\s*avize/), scoped = a >= 0;
    var rest = scoped ? low.slice(a) : low;
    var end = rest.search(/documentel[ea] de plata|dovada (?:privind )?achitar|are valabilitate|valabilitatea de/);
    var from = scoped ? a : 0, to = end > 0 ? from + end : low.length;
    var sec = low.slice(from, to), orig = text.slice(from, to);

    var hits = [];
    RULES.forEach(function (r) {
      // toate aparițiile: o rubrică e marcată dacă măcar una dintre ele are X în față
      var re = new RegExp(r.re.source, 'g'), m, hit = null, marked = false;
      while ((m = re.exec(sec))) {
        if (r.not && r.not.test(sec.slice(Math.max(0, m.index - 40), m.index + m[0].length + 40))) continue; // ex. „transport gaze naturale”
        if (!hit) hit = { i: m.index };
        if (MARK.test(orig.slice(Math.max(0, m.index - 5), m.index))) marked = true;
      }
      if (!hit && r.up) { var u = first(r.up, orig); if (u) hit = { i: u.i }; }
      if (hit) hits.push({ id: r.id, i: hit.i, box: !!r.box, marked: marked });
    });

    // căsuțele: dacă unele rubrici tip (utilități, ISU, DSP) sunt marcate și altele nu, păstrăm doar marcajele
    var boxed = hits.filter(function (h) { return h.box; });
    var nMark = boxed.filter(function (h) { return h.marked; }).length;
    var marks = nMark > 0 && nMark < boxed.length;
    var ids = hits.filter(function (h) { return !h.box || !marks || h.marked; }).map(function (h) { return h.id; });
    return { ids: ids, marks: marks, scoped: scoped, unsure: !marks && boxed.length >= 6 };
  }

  function adresa(seg) { // „județul X, comuna Y, satul Z, str. S nr. N” -> părți
    var low = fold(seg), o = {};
    function grab(re) { var m = re.exec(low); return m ? clean(seg.substr(m.index + m[0].length - m[1].length, m[1].length)) : ''; }
    var stop = '(?=\\s*(?:[,;\\n]|\\bmunicipiul|\\borasul|\\bcomuna|\\bsatul|\\bsat\\b|\\bsector|\\bcod postal|\\bstr\\b|\\bstrada|\\bnr\\b|\\bbl\\b|\\btelefon|\\be-?mail|\\binregistrat|\\bsau identificat|\\bin temeiul|$))';
    o.judet = grab(new RegExp('jude[tț]ul\\s*:?\\s*([a-z\\- ]{3,30}?)' + stop));
    var loc = grab(new RegExp('(?:municipiul|orasul|comuna)\\s*(?:\\/\\s*(?:orasul|comuna)\\s*){0,2}:?\\s*([a-z0-9\\-. ]{2,40}?)' + stop));
    var sat = grab(new RegExp('\\bsat(?:ul)?\\s*:?\\s*([a-z0-9\\-. ]{2,40}?)' + stop));
    var kind = /municipiul\s*:?\s*[a-z]/.test(low) ? 'municipiul ' : /orasul\s*:?\s*[a-z]/.test(low) ? 'orașul ' : /comuna\s*:?\s*[a-z]/.test(low) ? 'comuna ' : '';
    o.loc = loc ? kind + loc + (sat ? ', satul ' + sat : '') : (sat ? 'satul ' + sat : '');
    o.str = grab(/\b(?:str\.?|strada)\s*:?\s*([^,;\n]{2,50}?)(?=\s*(?:,|;|\n|\bnr\b|$))/);
    o.nr = grab(/\bnr\.?\s*:?\s*([0-9]+[a-z]?(?:\s?[-\/]\s?[0-9a-z]+)?)/);
    if (/bucuresti/.test(low) && !o.judet) o.judet = 'București';
    return o;
  }

  function parse(text) {
    text = String(text || '').replace(/\r/g, '').replace(/[ \t ]+/g, ' ');
    var low = fold(text), R = { f: {}, sol: {}, avize: [], warn: [] }, m;

    // număr și dată
    m = /certificat\s+de\s+urbanism\s*(?:nr\.?|numarul)?\s*:?\s*([0-9][\w\/.\-]*)\s*(?:din(?: data(?: de)?)?|\/)\s*:?\s*(\d{1,2})\s*[.\/\-]\s*(\d{1,2})\s*[.\/\-]\s*(\d{4})/.exec(low);
    if (m) {
      R.f.cu_nr = m[1].replace(/[.\/\-]+$/, '');
      R.f.cu_data = m[4] + '-' + ('0' + m[3]).slice(-2) + '-' + ('0' + m[2]).slice(-2);
    }
    // valabilitate
    var v = /valabilitate[a]?\s*(?:de)?\s*:?\s*(\d{1,2})\s*(?:\([a-z ]+\)\s*)?luni/.exec(low);
    if (v && R.f.cu_data) {
      var d = new Date(R.f.cu_data + 'T12:00:00'); d.setMonth(d.getMonth() + (+v[1]));
      R.f.cu_valab = d.toISOString().slice(0, 10);
    }
    // emitent: prima linie din antet care numește primăria / consiliul județean
    var head = text.slice(0, Math.max(0, low.indexOf('certificat de urbanism')) || 600).split('\n');
    for (var i = 0; i < head.length; i++) {
      var hl = fold(head[i]).trim();
      if (/^(primaria|consiliul judetean|primarul|presedintele consiliului)/.test(hl) && hl.length > 12) { R.f.cu_emis = title(clean(head[i])); break; }
    }
    if (!R.f.cu_emis) for (i = 0; i < head.length; i++) {
      hl = fold(head[i]).trim();
      if (/^(municipiul|orasul|comuna|sectorul)\s+[a-z0-9]/.test(hl)) { R.f.cu_emis = 'Primăria ' + title(clean(head[i])).replace(/^(Municipiul|Orașul|Orasul|Comuna|Sectorul)/, function (w) { return ({ Municipiul: 'Municipiului', 'Orașul': 'Orașului', Orasul: 'Orașului', Comuna: 'Comunei', Sectorul: 'Sectorului' })[w]; }); break; }
    }

    // solicitant
    var s0 = low.search(/ca urmare a cererii adresate de/), s1 = low.search(/pentru imobilul/), s2 = low.search(/se certifica/);
    if (s0 >= 0) {
      var segEnd = s1 > s0 ? s1 : (s2 > s0 ? s2 : s0 + 900);
      var seg = text.slice(s0, segEnd), segLow = low.slice(s0, segEnd);
      var n = /adresate de\s*\d?\)?\s*:?\s*([\s\S]+?)\s*,?\s*(?:\d\)\s*)?cu (?:domiciliul|sediul)/.exec(segLow);
      if (n) {
        var st = segLow.indexOf(n[1]);
        R.sol.nume = clean(seg.substr(st, n[1].length));
        R.sol.pjur = /s\.?\s?r\.?\s?l|s\.?\s?a\.?\b|s\.?c\.?\s|primaria|comuna|orasul|municipiul|consiliul|asociatia|parohia|societatea|\bii\b|p\.?f\.?a/.test(fold(R.sol.nume));
      }
      var dm = segLow.search(/cu (?:domiciliul|sediul)/);
      if (dm >= 0) R.sol.adr = adresa(seg.slice(dm, segLow.search(/inregistrata? la/) > dm ? segLow.search(/inregistrata? la/) : undefined));
      var tel = /telefon[^0-9+]{0,20}(\+?[0-9][0-9 .\-]{8,14}[0-9])/.exec(segLow); if (tel) R.sol.tel = tel[1].trim();
      var em = /[\w.+\-]+@[\w\-]+\.[\w.\-]+/.exec(seg); if (em) R.sol.email = em[0];
    }
    // amplasament
    if (s1 >= 0) {
      var aEnd = low.slice(s1).search(/in temeiul|se certifica|1\.\s*regimul juridic/);
      var amp = text.slice(s1, aEnd > 0 ? s1 + aEnd : s1 + 700);
      var idp = fold(amp).search(/sau identificat/);
      R.amp = adresa(idp > 0 ? amp.slice(0, idp) : amp);
      var c = /(?:nr\.?|numar(?:ul)?)\s*cad(?:astral)?\.?\s*:?\s*([0-9]{3,7})/.exec(fold(amp)) || /cad(?:astral)?\.?\s*(?:nr\.?)?\s*:?\s*([0-9]{3,7})/.exec(fold(amp));
      if (c) R.amp.cad = c[1];
      var cf = /(?:c\.?\s?f\.?|cart(?:e|ea) funciara)\s*(?:nr\.?)?\s*:?\s*([0-9]{3,7})/.exec(fold(amp)); if (cf) R.amp.cf = cf[1];
    }
    // scopul / denumirea lucrării
    var sc = /scopul declarat[^a-z:]{0,6}(?:pentru\s*\/?\s*(?:intrucat)?)?\s*:?\s*([\s\S]{8,600}?)\s*(?:certificatul de urbanism nu tine loc|4\.\s*obligatii|\n\s*\n)/.exec(low);
    if (sc) { var si = low.indexOf(sc[1], sc.index); R.f.continut = clean(text.substr(si, sc[1].length)); }
    var fs = fold(R.f.continut || '');
    R.f.tip_dc = /p\.?\s?u\.?\s?z/.test(fs) ? 'puz' : /p\.?\s?u\.?\s?d/.test(fs) ? 'pud' : /desfiint|demolar/.test(fs) && !/constru[ic]/.test(fs) ? 'dtad' : 'dtac';

    // avize
    var av = findAvize(text, low);
    R.avize = av.ids; R.marks = av.marks;
    if (!av.scoped) R.warn.push('Nu am găsit rubrica „avizele și acordurile” din certificat, așa că am căutat în tot textul. Verifică fiecare bifă.');
    else if (av.unsure) R.warn.push('Nu am putut citi căsuțele bifate de la utilități, ISU și DSP, așa că le-am bifat pe toate cele tipărite. Debifează ce nu este marcat pe certificat.');
    else if (av.marks) R.warn.push('La utilități, ISU și DSP am păstrat doar rubricile marcate cu X. Compară cu certificatul.');
    R.found = !!(R.f.cu_nr || R.avize.length);
    return R;
  }

  /* ---------- citirea fișierelor (doar în browser) ---------- */
  var base = (typeof document !== 'undefined' && document.currentScript ? document.currentScript.src : '').replace(/[^\/]*$/, '') + 'ocr/';
  var loaded = {};
  function script(name) {
    if (!loaded[name]) loaded[name] = new Promise(function (ok, bad) {
      var s = document.createElement('script'); s.src = base + name;
      s.onload = ok; s.onerror = function () { delete loaded[name]; bad(new Error('Nu am putut încărca ' + name)); };
      document.head.appendChild(s);
    });
    return loaded[name];
  }

  function pageText(tc) { // grupează fragmentele pe rânduri, după poziția verticală
    var rows = [];
    tc.items.forEach(function (it) {
      if (!it.str) return;
      var y = it.transform[5], x = it.transform[4], h = it.height || 10, r = null;
      for (var i = rows.length - 1; i >= 0 && i >= rows.length - 4; i--) if (Math.abs(rows[i].y - y) < h * 0.5) { r = rows[i]; break; }
      if (!r) { r = { y: y, it: [] }; rows.push(r); }
      r.it.push({ x: x, s: it.str, w: it.width || 0 });
    });
    rows.sort(function (a, b) { return b.y - a.y; });
    return rows.map(function (r) {
      r.it.sort(function (a, b) { return a.x - b.x; });
      var out = '', end = null;
      r.it.forEach(function (t) { out += (end !== null && t.x - end > 1.5 && !/\s$/.test(out) && !/^\s/.test(t.s) ? ' ' : '') + t.s; end = t.x + t.w; });
      return out;
    }).join('\n');
  }

  var worker = null;
  function ocr(images, onP) {
    return script('tesseract.min.js').then(function () {
      if (!worker) worker = root.Tesseract.createWorker('ron', 1, {
        workerPath: base + 'worker.min.js', corePath: base, langPath: base, gzip: true,
        logger: function (m) { if (m.status === 'recognizing text' && ocr.cb) ocr.cb(m.progress); }
      });
      return worker;
    }).then(function (w) {
      var out = [], i = 0;
      function next() {
        if (i >= images.length) return out.join('\n\n');
        var k = i++;
        ocr.cb = function (p) { onP('Citesc pagina ' + (k + 1) + ' din ' + images.length + ' (' + Math.round(p * 100) + '%)…'); };
        return w.recognize(images[k]).then(function (r) { out.push(r.data.text); return next(); });
      }
      return next();
    });
  }

  function readPdf(buf, onP) {
    return script('pdf.min.js').then(function () {
      var lib = root.pdfjsLib; lib.GlobalWorkerOptions.workerSrc = base + 'pdf.worker.min.js';
      return lib.getDocument({ data: buf }).promise;
    }).then(function (pdf) {
      var n = Math.min(pdf.numPages, 8), texts = [], p = Promise.resolve();
      for (var i = 1; i <= n; i++) (function (i) {
        p = p.then(function () { return pdf.getPage(i); }).then(function (pg) { return pg.getTextContent(); }).then(function (tc) { texts.push(pageText(tc)); });
      })(i);
      return p.then(function () {
        var text = texts.join('\n\n');
        if (text.replace(/\s/g, '').length > 250) return { text: text, ocr: false };
        // PDF scanat: desenăm paginile și le trecem prin OCR
        onP('Certificatul este scanat. Pregătesc recunoașterea textului…');
        var imgs = [], q = Promise.resolve();
        for (var j = 1; j <= n; j++) (function (j) {
          q = q.then(function () { return pdf.getPage(j); }).then(function (pg) {
            var vp = pg.getViewport({ scale: 2.2 }), cv = document.createElement('canvas');
            cv.width = vp.width; cv.height = vp.height;
            return pg.render({ canvasContext: cv.getContext('2d'), viewport: vp }).promise.then(function () { imgs.push(cv); });
          });
        })(j);
        return q.then(function () { return ocr(imgs, onP); }).then(function (t) { return { text: t, ocr: true }; });
      });
    });
  }

  function read(files, onP) {
    files = Array.prototype.slice.call(files); onP = onP || function () {};
    var pdf = files.filter(function (f) { return /pdf$/i.test(f.type) || /\.pdf$/i.test(f.name); })[0];
    if (pdf) { onP('Deschid PDF-ul…'); return pdf.arrayBuffer().then(function (b) { return readPdf(b, onP); }); }
    var imgs = files.filter(function (f) { return /^image\//.test(f.type); });
    if (!imgs.length) return Promise.reject(new Error('Alege un PDF sau poze (JPG, PNG) ale certificatului.'));
    imgs.sort(function (a, b) { return a.name.localeCompare(b.name, 'ro', { numeric: true }); });
    onP('Pregătesc recunoașterea textului…');
    return ocr(imgs, onP).then(function (t) { return { text: t, ocr: true }; });
  }

  var api = { parse: parse, read: read };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.CU = api;
})(typeof self !== 'undefined' ? self : this);
