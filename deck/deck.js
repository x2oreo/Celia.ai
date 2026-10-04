/* Celia.ai deck: scaling, navigation and the generated visuals. No dependencies. */
(function () {
  'use strict';

  var NS = 'http://www.w3.org/2000/svg';
  var slides = Array.prototype.slice.call(document.querySelectorAll('.slide'));
  var current = -1;

  function $(id) { return document.getElementById(id); }
  function svgEl(tag, attrs) {
    var el = document.createElementNS(NS, tag);
    for (var k in attrs) { if (Object.prototype.hasOwnProperty.call(attrs, k)) el.setAttribute(k, attrs[k]); }
    return el;
  }

  /* ---------------- Scale 1920 × 1080 to the window ---------------- */
  function fit() {
    var k = Math.min(window.innerWidth / 1920, window.innerHeight / 1080);
    document.documentElement.style.setProperty('--k', k.toFixed(4));
  }
  window.addEventListener('resize', fit);
  fit();

  var total = slides.length;

  /* ---------------- Navigation ---------------- */
  function go(i) {
    i = Math.max(0, Math.min(total - 1, i));
    if (i === current) return;
    if (current >= 0) slides[current].classList.remove('is-active');
    current = i;
    var s = slides[i];
    s.classList.add('is-active');
    if (history.replaceState) history.replaceState(null, '', '#' + (i + 1));
    $('bar').style.width = ((i + 1) / total * 100) + '%';
    document.title = 'Celia.ai · ' + (s.getAttribute('data-title') || '');
    var v = $('demo');
    if (v && !s.contains(v) && !v.paused) v.pause();
  }
  function next() { go(current + 1); }
  function prev() { go(current - 1); }

  document.addEventListener('keydown', function (e) {
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    var k = e.key;
    if (k === 'ArrowRight' || k === 'ArrowDown' || k === 'PageDown' || k === ' ' || k === 'Enter') { e.preventDefault(); next(); }
    else if (k === 'ArrowLeft' || k === 'ArrowUp' || k === 'PageUp' || k === 'Backspace') { e.preventDefault(); prev(); }
    else if (k === 'Home') go(0);
    else if (k === 'End') go(total - 1);
    else if (k === 'f' || k === 'F') {
      if (!document.fullscreenElement) document.documentElement.requestFullscreen && document.documentElement.requestFullscreen();
      else document.exitFullscreen && document.exitFullscreen();
    } else if (k === 'p' || k === 'P') window.print();
    hideHint();
  });
  document.addEventListener('click', function (e) {
    if (e.target.closest('video, a, button')) return;
    if (e.clientX > window.innerWidth * 0.35) next(); else prev();
    hideHint();
  });
  var tx = null;
  document.addEventListener('touchstart', function (e) { tx = e.touches[0].clientX; }, { passive: true });
  document.addEventListener('touchend', function (e) {
    if (tx === null) return;
    var dx = e.changedTouches[0].clientX - tx;
    if (Math.abs(dx) > 40) { if (dx < 0) next(); else prev(); }
    tx = null;
  });
  function hideHint() { var h = $('hint'); if (h) h.classList.add('gone'); }
  setTimeout(hideHint, 5000);

  /* ---------------- Slide 2: 2,000 people ---------------- */
  (function () {
    var svg = $('dots');
    if (!svg) return;
    var cols = 50, rows = 40, step = 16.4, r = 4.6;
    var pick = { c: 37, r: 13 };
    var frag = document.createDocumentFragment();
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (x === pick.c && y === pick.r) continue;
        var c = svgEl('circle', { cx: (8 + x * step).toFixed(1), cy: (8 + y * step).toFixed(1), r: r });
        c.style.setProperty('--r', String(y));
        frag.appendChild(c);
      }
    }
    var px = 8 + pick.c * step, py = 8 + pick.r * step;
    frag.appendChild(svgEl('circle', { cx: px, cy: py, r: 14, class: 'one-ring' }));
    frag.appendChild(svgEl('circle', { cx: px, cy: py, r: 7.5, class: 'one' }));
    svg.appendChild(frag);
  })();

  /* ---------------- Slide 2: real entries from the dataset ---------------- */
  (function () {
    var A = [['clarithromycin', 'known'], ['ofloxacin', 'possible'], ['ondansetron', 'known'], ['tramadol', 'possible'],
      ['azithromycin', 'known'], ['venlafaxine', 'possible'], ['domperidone', 'known'], ['mirtazapine', 'possible'],
      ['citalopram', 'known'], ['tamoxifen', 'possible'], ['levofloxacin', 'known'], ['granisetron', 'possible'],
      ['haloperidol', 'known'], ['aripiprazole', 'possible'], ['methadone', 'known'], ['lithium', 'possible']];
    var B = [['metronidazole', 'conditional'], ['hydroxychloroquine', 'known'], ['omeprazole', 'conditional'], ['fluconazole', 'known'],
      ['furosemide', 'conditional'], ['promethazine', 'possible'], ['loperamide', 'conditional'], ['escitalopram', 'known'],
      ['salbutamol', 'conditional'], ['moxifloxacin', 'known'], ['pseudoephedrine', 'conditional'], ['erythromycin', 'known'],
      ['quetiapine', 'conditional'], ['ciprofloxacin', 'known'], ['sertraline', 'conditional'], ['donepezil', 'known']];
    var WORD = { known: 'Known risk', possible: 'Possible risk', conditional: 'Conditional', listed: 'Not listed' };
    function build(el, list) {
      if (!el) return;
      var html = list.map(function (m) {
        return '<span class="pill-med ' + m[1] + '"><svg aria-hidden="true"><use href="#r-' + m[1] + '"/></svg><b>' +
          m[0] + '</b><span>' + WORD[m[1]] + '</span></span>';
      }).join('');
      el.innerHTML = html;
    }
    var mixed = [];
    for (var i = 0; i < A.length; i++) { mixed.push(A[i]); mixed.push(B[i]); }
    build($('mqA'), mixed);
  })();

  /* ---------------- Team photo slot ---------------- */
  (function () {
    var img = $('team-photo'), tslot = $('team-slot');
    function noPhoto() { if (img) img.style.visibility = 'hidden'; if (tslot) tslot.hidden = false; }
    if (img) {
      img.addEventListener('error', noPhoto);
      if (img.complete && img.naturalWidth === 0) noPhoto();
    }
  })();

  /* ---------------- Start ---------------- */
  var start = parseInt((location.hash || '').replace('#', ''), 10);
  go(isNaN(start) ? 0 : start - 1);
})();
