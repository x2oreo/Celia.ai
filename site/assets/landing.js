// Celia.ai landing page (DESIGN.md §10.2b): smooth scroll, scroll-linked reveals, the heartbeat field, the pinned
// medicine-check story, the agent conversation player, the multilingual emergency card and the media slots.
// Libraries (self-hosted): GSAP + ScrollTrigger, Lenis. Everything degrades to a static, readable page.
(function () {
  'use strict';

  var doc = document.documentElement;
  var $ = function (id) { return document.getElementById(id); };
  var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var fine = window.matchMedia('(hover: hover) and (pointer: fine)').matches;
  var gsap = window.gsap;
  var ST = window.ScrollTrigger;
  var motion = !!(gsap && ST) && !reduce;

  if (!motion) {
    doc.classList.add('no-motion');
    document.body.classList.add('is-ready');
  }
  if (gsap && ST) gsap.registerPlugin(ST);
  if (window.SilkOrb) window.SilkOrb.mountAll();

  function wait(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }
  function onVisible(el, cb, threshold) {
    if (!el || !('IntersectionObserver' in window)) { cb(true); return; }
    new IntersectionObserver(function (entries) {
      entries.forEach(function (e) { cb(e.isIntersecting); });
    }, { threshold: threshold || 0 }).observe(el);
  }

  /* ---------------- Media slots ---------------- */
  // A slot keeps its placeholder until the file really loads, so a missing file never shows as broken.
  function fill(el) {
    var slot = el.closest('[data-slot]');
    if (slot) slot.classList.add('is-filled');
    if (ST) ST.refresh();
  }
  document.querySelectorAll('img[data-src]').forEach(function (img) {
    var probe = new Image();
    probe.onload = function () { img.src = img.getAttribute('data-src'); fill(img); };
    probe.src = img.getAttribute('data-src');
  });

  /* ---------------- Smooth scroll ---------------- */
  var lenis = null;
  if (motion && window.Lenis) {
    lenis = new window.Lenis({ lerp: 0.085, smoothWheel: true, wheelMultiplier: 0.95 });
    lenis.on('scroll', ST.update);
    gsap.ticker.add(function (t) { lenis.raf(t * 1000); });
    gsap.ticker.lagSmoothing(0);
  }
  document.querySelectorAll('a[href^="#"]').forEach(function (a) {
    a.addEventListener('click', function (e) {
      var id = a.getAttribute('href');
      if (id.length < 2) return;
      var target = document.querySelector(id);
      if (!target) return;
      e.preventDefault();
      if (lenis) lenis.scrollTo(target, { offset: id === '#top' ? 0 : -16, duration: 1.5 });
      else target.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth' });
      if (history.replaceState) history.replaceState(null, '', id);
    });
  });

  /* ---------------- Word splitting ---------------- */
  function split(el) {
    var text = el.textContent.replace(/\s+/g, ' ').trim();
    el.setAttribute('aria-label', text);
    el.textContent = '';
    text.split(' ').forEach(function (word, i, all) {
      var w = document.createElement('span');
      w.className = 'w';
      w.setAttribute('aria-hidden', 'true');
      var wi = document.createElement('span');
      wi.className = 'wi';
      wi.textContent = word;
      w.appendChild(wi);
      el.appendChild(w);
      if (i < all.length - 1) el.appendChild(document.createTextNode(' '));
    });
  }
  document.querySelectorAll('[data-split], [data-scrub]').forEach(split);

  /* ---------------- Entrances ---------------- */
  if (motion) {
    var intro = gsap.timeline({ defaults: { ease: 'expo.out' } });
    intro
      .fromTo('#heroOrb', { scale: 0.55, opacity: 0 }, { scale: 1, opacity: 1, duration: 2.2 }, 0)
      .fromTo('[data-split="hero"] .wi', { yPercent: 60, opacity: 0, filter: 'blur(14px)' },
        { yPercent: 0, opacity: 1, filter: 'blur(0px)', duration: 1.3, stagger: 0.08 }, 0.15)
      .fromTo('[data-hero]', { y: 26, opacity: 0, filter: 'blur(8px)' },
        { y: 0, opacity: 1, filter: 'blur(0px)', duration: 1.1, stagger: 0.09, clearProps: 'filter' }, 0.3)
      .fromTo('#heroTilt .hero-phone', { y: 140, opacity: 0, rotateX: 26 },
        { y: 0, opacity: 1, rotateX: 0, duration: 1.8 }, 0.2)
      .fromTo('#heroTilt .float-in > *', { opacity: 0, scale: 0.82, filter: 'blur(8px)' },
        { opacity: 1, scale: 1, filter: 'blur(0px)', duration: 1.2, stagger: 0.12, clearProps: 'filter' }, 0.8);

    // Hero recedes as you scroll away.
    gsap.to('#heroStage', { yPercent: -10, scale: 0.92, opacity: 0.35, ease: 'none',
      scrollTrigger: { trigger: '.hero', start: 'top top', end: 'bottom top', scrub: true } });
    gsap.to('#heroCopy', { y: -90, opacity: 0, ease: 'none',
      scrollTrigger: { trigger: '.hero', start: 'top top', end: 'bottom 25%', scrub: true } });

    gsap.utils.toArray('[data-split]:not([data-split="hero"])').forEach(function (h) {
      gsap.fromTo(h.querySelectorAll('.wi'), { yPercent: 55, opacity: 0, filter: 'blur(10px)' }, {
        yPercent: 0, opacity: 1, filter: 'blur(0px)', duration: 1.15, ease: 'expo.out', stagger: 0.055,
        scrollTrigger: { trigger: h, start: 'top 86%', once: true }
      });
    });

    ST.batch('[data-reveal]', {
      start: 'top 90%', once: true,
      onEnter: function (batch) {
        gsap.fromTo(batch, { opacity: 0, y: 40, filter: 'blur(8px)' }, {
          opacity: 1, y: 0, filter: 'blur(0px)', duration: 1.1, ease: 'expo.out', stagger: 0.09, clearProps: 'filter,transform'
        });
      }
    });

    // The context statement fills in word by word with the scroll.
    document.querySelectorAll('[data-scrub]').forEach(function (s) {
      gsap.fromTo(s.querySelectorAll('.wi'), { opacity: 0.13 }, {
        opacity: 1, stagger: 0.1, ease: 'none',
        scrollTrigger: { trigger: s, start: 'top 82%', end: 'bottom 42%', scrub: 0.6 }
      });
    });

    if (document.fonts && document.fonts.ready) document.fonts.ready.then(function () { ST.refresh(); });
  }

  /* ---------------- Nav: tone over dark sections, active link, hide on scroll down, progress ---------------- */
  var nav = $('nav');
  var navInd = $('navInd');
  var navLinks = Array.prototype.slice.call(document.querySelectorAll('[data-nav]'));
  var darkSecs = Array.prototype.slice.call(document.querySelectorAll('[data-theme="dark"]'));
  var navTargets = navLinks.map(function (a) { return $(a.getAttribute('data-nav')); });
  var bar = $('progressBar');
  var lastY = window.scrollY;
  var ticking = false;

  function moveInd(a) {
    if (!a) { navInd.style.opacity = '0'; return; }
    navInd.style.opacity = '1';
    navInd.style.width = a.offsetWidth + 'px';
    navInd.style.transform = 'translateX(' + a.offsetLeft + 'px)';
  }
  function onScroll() {
    ticking = false;
    var y = window.scrollY;
    var probe = 40;
    var dark = darkSecs.some(function (s) { var r = s.getBoundingClientRect(); return r.top <= probe && r.bottom > probe; });
    nav.setAttribute('data-tone', dark ? 'dark' : 'light');

    var mid = window.innerHeight * 0.42;
    var active = null;
    navTargets.forEach(function (t, i) {
      if (!t) return;
      var r = t.getBoundingClientRect();
      if (r.top <= mid && r.bottom > mid) active = navLinks[i];
    });
    navLinks.forEach(function (a) { a.classList.toggle('is-active', a === active); });
    moveInd(active);

    if (y > 640 && y > lastY + 4) nav.classList.add('is-hidden');
    else if (y < lastY - 4 || y < 640) nav.classList.remove('is-hidden');
    lastY = y;

    var max = document.documentElement.scrollHeight - window.innerHeight;
    bar.style.transform = 'scaleX(' + (max > 0 ? y / max : 0) + ')';
  }
  window.addEventListener('scroll', function () {
    if (!ticking) { ticking = true; requestAnimationFrame(onScroll); }
  }, { passive: true });
  window.addEventListener('resize', onScroll);
  onScroll();

  /* ---------------- Heartbeat field (canvas) ---------------- */
  // A dot grid that one soft wave sweeps through with each breath of the orb (4 s) and that bends away from the
  // cursor. A single slow wave, never a double beat, never a trace of a heart signal (DESIGN §6.6).
  function Field(canvas, center, host) {
    var ctx = canvas.getContext('2d');
    var dots = [];
    var waves = [];
    var W = 0, H = 0, dpr = 1;
    var mouse = { x: -9999, y: -9999 };
    var running = false;
    var lastBeat = 0;
    var GAP = 30, PERIOD = 4000, SPEED = 0.2, WIDTH = 46;

    function resize() {
      W = canvas.clientWidth; H = canvas.clientHeight;
      dpr = Math.min(2, window.devicePixelRatio || 1);
      canvas.width = Math.round(W * dpr); canvas.height = Math.round(H * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      dots = [];
      var ox = (W % GAP) / 2, oy = (H % GAP) / 2;
      for (var y = oy; y <= H; y += GAP) for (var x = ox; x <= W; x += GAP) dots.push(x, y);
    }
    function origin() {
      var cr = canvas.getBoundingClientRect();
      var r = center.getBoundingClientRect();
      return { x: r.left + r.width / 2 - cr.left, y: r.top + r.height / 2 - cr.top, rad: r.width / 2 };
    }
    function frame(now) {
      if (!running) return;
      if (now - lastBeat > PERIOD) {
        lastBeat = now;
        waves.push({ t: now, s: 1 });
      }
      draw(now);
      requestAnimationFrame(frame);
    }
    function draw(now) {
      var o = origin();
      var maxR = Math.hypot(Math.max(o.x, W - o.x), Math.max(o.y, H - o.y));
      ctx.clearRect(0, 0, W, H);
      waves = waves.filter(function (w) { return (now - w.t) * SPEED < maxR; });
      for (var k = 0; k < waves.length; k++) {
        var wr = (now - waves[k].t) * SPEED;
        if (wr < o.rad) continue;
        ctx.beginPath();
        ctx.arc(o.x, o.y, wr, 0, Math.PI * 2);
        ctx.strokeStyle = 'rgba(229,72,77,' + (0.16 * waves[k].s * (1 - wr / maxR)).toFixed(3) + ')';
        ctx.lineWidth = 1.5;
        ctx.stroke();
      }
      for (var i = 0; i < dots.length; i += 2) {
        var x = dots[i], y = dots[i + 1];
        var dx = x - o.x, dy = y - o.y;
        var d = Math.sqrt(dx * dx + dy * dy) || 1;
        if (d < o.rad * 0.92) continue;
        var infl = 0;
        for (var j = 0; j < waves.length; j++) {
          var r = (now - waves[j].t) * SPEED;
          var del = d - r;
          if (del > -90 && del < 90) infl += Math.exp(-(del * del) / (2 * WIDTH * WIDTH)) * waves[j].s * (1 - r / maxR);
        }
        var mx = x - mouse.x, my = y - mouse.y;
        var dm = Math.sqrt(mx * mx + my * my);
        var push = dm < 150 ? Math.pow(1 - dm / 150, 2) : 0;
        var px = x + (dx / d) * infl * 10 + (dm ? (mx / dm) * push * 16 : 0);
        var py = y + (dy / d) * infl * 10 + (dm ? (my / dm) * push * 16 : 0);
        var fade = Math.min(1, d / (o.rad * 3));
        var a = (0.13 + infl * 0.7 + push * 0.35) * fade;
        var g = Math.round(235 - infl * 150);
        ctx.fillStyle = 'rgba(255,' + g + ',' + Math.round(g * 0.95) + ',' + a.toFixed(3) + ')';
        var s = 1.1 + infl * 1.5 + push;
        ctx.fillRect(px - s / 2, py - s / 2, s, s);
      }
    }
    host.addEventListener('pointermove', function (e) {
      var cr = canvas.getBoundingClientRect();
      mouse.x = e.clientX - cr.left; mouse.y = e.clientY - cr.top;
    });
    host.addEventListener('pointerleave', function () { mouse.x = mouse.y = -9999; });
    window.addEventListener('resize', resize);
    resize();
    if (reduce) { draw(performance.now()); return; }
    onVisible(host, function (vis) {
      if (vis && !running) { running = true; requestAnimationFrame(frame); }
      else if (!vis) running = false;
    });
  }
  var heroSec = document.querySelector('.hero');
  var closeSec = document.querySelector('.closing');
  if ($('heroField')) Field($('heroField'), $('heroSilk'), heroSec);
  if ($('closeField')) Field($('closeField'), $('closeOrb'), closeSec);

  /* ---------------- Hero: 3D tilt + depth parallax ---------------- */
  (function () {
    var tilt = $('heroTilt');
    if (!tilt || reduce) return;
    var floats = Array.prototype.slice.call(tilt.querySelectorAll('.float'));
    var tx = 0, ty = 0, cx = 0, cy = 0, live = false;
    heroSec.addEventListener('pointermove', function (e) {
      var r = heroSec.getBoundingClientRect();
      tx = (e.clientX - r.left) / r.width * 2 - 1;
      ty = (e.clientY - r.top) / r.height * 2 - 1;
    });
    heroSec.addEventListener('pointerleave', function () { tx = 0; ty = 0; });
    function loop(t) {
      if (!live) return;
      var ix = tx, iy = ty;
      if (!fine) { ix = Math.sin(t / 2400) * 0.5; iy = Math.cos(t / 3100) * 0.35; }
      cx += (ix - cx) * 0.06; cy += (iy - cy) * 0.06;
      tilt.style.transform = 'rotateY(' + (-12 + cx * 12).toFixed(2) + 'deg) rotateX(' + (5 - cy * 9).toFixed(2) + 'deg)';
      floats.forEach(function (f) {
        var d = parseFloat(f.getAttribute('data-depth')) || 1;
        f.style.transform = 'translate3d(' + (cx * d * 24).toFixed(1) + 'px,' + (cy * d * 18).toFixed(1) + 'px,' + (d * 80) + 'px)';
      });
      requestAnimationFrame(loop);
    }
    onVisible(heroSec, function (vis) {
      if (vis && !live) { live = true; requestAnimationFrame(loop); } else if (!vis) live = false;
    });
  })();

  // Illustrative heart rate on the drawn screens.
  (function () {
    var els = [$('heroBpm')].filter(Boolean);
    if (reduce || !els.length) return;
    setInterval(function () {
      if (document.hidden) return;
      var v = String(70 + Math.round(Math.random() * 5));
      els.forEach(function (e) { e.textContent = v; });
    }, 2600);
  })();

  /* ---------------- Medicine marquee (real entries from the dataset) ---------------- */
  (function () {
    var A = [['clarithromycin', 'known'], ['ofloxacin', 'possible'], ['ondansetron', 'known'], ['tramadol', 'possible'],
      ['azithromycin', 'known'], ['venlafaxine', 'possible'], ['domperidone', 'known'], ['mirtazapine', 'possible'],
      ['citalopram', 'known'], ['tamoxifen', 'possible'], ['levofloxacin', 'known'], ['granisetron', 'possible'],
      ['haloperidol', 'known'], ['aripiprazole', 'possible'], ['methadone', 'known'], ['lithium', 'possible'],
      ['hydroxychloroquine', 'known'], ['promethazine', 'possible']];
    var B = [['metronidazole', 'conditional'], ['ibuprofen', 'listed'], ['omeprazole', 'conditional'], ['amoxicillin', 'listed'],
      ['furosemide', 'conditional'], ['paracetamol', 'listed'], ['loperamide', 'conditional'], ['cetirizine', 'listed'],
      ['salbutamol', 'conditional'], ['nadolol', 'listed'], ['pseudoephedrine', 'conditional'], ['propranolol', 'listed'],
      ['quetiapine', 'conditional'], ['doxycycline', 'listed'], ['fluconazole', 'known'], ['metformin', 'listed'],
      ['sertraline', 'conditional'], ['loratadine', 'listed']];
    var WORD = { known: 'Known risk', possible: 'Possible risk', conditional: 'Conditional', listed: 'Not listed' };
    function build(track, list) {
      var html = list.map(function (m) {
        return '<span class="pill-med ' + m[1] + '"><svg aria-hidden="true"><use href="#r-' + m[1] + '"/></svg><b>' +
          m[0] + '</b><span>' + WORD[m[1]] + '</span></span>';
      }).join('');
      track.innerHTML = html + html.replace(/<span class="pill-med/g, '<span aria-hidden="true" class="pill-med');
    }
    var ta = $('mqA'), tb = $('mqB');
    if (!ta || !tb) return;
    build(ta, A); build(tb, B);
    if (reduce) return;
    var rows = [{ el: ta, dir: -1, x: 0 }, { el: tb, dir: 1, x: 0 }];
    var live = false, prev = 0, lastScroll = window.scrollY, boost = 0;
    function loop(t) {
      if (!live) return;
      var dt = prev ? Math.min(64, t - prev) : 16;
      prev = t;
      var sy = window.scrollY;
      boost += (Math.min(40, Math.abs(sy - lastScroll)) - boost) * 0.08;
      lastScroll = sy;
      rows.forEach(function (r) {
        var half = r.el.scrollWidth / 2;
        r.x += r.dir * (0.04 + boost * 0.012) * dt;
        if (r.x <= -half) r.x += half;
        if (r.x > 0) r.x -= half;
        r.el.style.transform = 'translate3d(' + r.x.toFixed(1) + 'px,0,0)';
      });
      requestAnimationFrame(loop);
    }
    rows[1].x = -tb.scrollWidth / 4;
    onVisible($('marquee'), function (vis) {
      if (vis && !live) { live = true; prev = 0; requestAnimationFrame(loop); } else if (!vis) live = false;
    });
  })();

  /* ---------------- Medicine check story ---------------- */
  (function () {
    var story = $('story'), phone = $('storyPhone');
    if (!story || !phone) return;
    var steps = Array.prototype.slice.call(story.querySelectorAll('.step'));
    var typeEl = $('typeText'), suggest = $('suggest');
    var cur = -1, typer = 0;

    // Barcode bars, drawn once.
    var bars = $('bars');
    if (bars) {
      var x = 8, seed = 7, out = '';
      while (x < 150) {
        seed = (seed * 9301 + 49297) % 233280;
        var w = 1 + Math.floor((seed / 233280) * 3);
        out += '<rect x="' + x + '" y="2" width="' + w + '" height="54"/>';
        x += w + 1 + Math.floor(((seed * 7) % 100) / 50);
      }
      bars.innerHTML = out;
    }

    function typeName() {
      clearInterval(typer);
      typeEl.textContent = '';
      suggest.classList.remove('show');
      var word = 'Klacid', i = 0;
      if (reduce) { typeEl.textContent = word; suggest.classList.add('show'); return; }
      typer = setInterval(function () {
        i += 1;
        typeEl.textContent = word.slice(0, i);
        if (i >= word.length) { clearInterval(typer); setTimeout(function () { suggest.classList.add('show'); }, 250); }
      }, 140);
    }
    function setStep(i) {
      if (cur === i) return;
      cur = i;
      phone.setAttribute('data-step', String(i));
      story.setAttribute('data-step', String(i));
      steps.forEach(function (s, j) { s.classList.toggle('is-active', j === i); });
      if (i === 0) typeName();
    }

    if (reduce) {
      setStep(3);
      steps.forEach(function (s) { s.classList.add('is-active'); });
      typeEl.textContent = 'Klacid';
      return;
    }

    var timer = 0, visible = false;
    function autoplay(on) {
      clearInterval(timer);
      if (on) timer = setInterval(function () { if (visible) setStep((cur + 1) % 4); }, 3200);
    }
    steps.forEach(function (s, j) {
      s.addEventListener('click', function () { setStep(j); autoplay(!desktopNow()); });
    });
    function desktopNow() { return window.matchMedia('(min-width: 961px)').matches; }
    onVisible(story, function (v) { visible = v; if (v && cur < 0) setStep(0); }, 0.2);

    if (motion) {
      var mm = gsap.matchMedia();
      mm.add('(min-width: 961px)', function () {
        steps.forEach(function (s, j) {
          ST.create({ trigger: s, start: 'top 55%', end: 'bottom 55%', onEnter: function () { setStep(j); }, onEnterBack: function () { setStep(j); } });
        });
        gsap.fromTo('#storyFill', { scaleY: 0 }, { scaleY: 1, ease: 'none',
          scrollTrigger: { trigger: '.story-steps', start: 'top 50%', end: 'bottom 50%', scrub: true } });
        gsap.fromTo('.story-phone', { rotateY: -14, rotateX: 6 }, { rotateY: 10, rotateX: -4, ease: 'none',
          scrollTrigger: { trigger: story, start: 'top bottom', end: 'bottom top', scrub: true } });
      });
      mm.add('(max-width: 960px)', function () {
        autoplay(true);
        return function () { autoplay(false); };
      });
    } else {
      autoplay(true);
    }
  })();

  /* ---------------- Spotlight cards ---------------- */
  if (fine) {
    document.querySelectorAll('.spot').forEach(function (el) {
      el.addEventListener('pointermove', function (e) {
        var r = el.getBoundingClientRect();
        el.style.setProperty('--mx', (e.clientX - r.left) + 'px');
        el.style.setProperty('--my', (e.clientY - r.top) + 'px');
      });
    });
  }

  /* ---------------- Watch v2 faces (DESIGN §7, v2-watches) ---------------- */
  // One renderer for every watch on the page, so the hero, and the sequence draw the same face.
  var ZONE = { calm: '#12B76A', elev: '#FDB022', alert: '#F04438', brand: '#F26B6F' };
  var GAUGE = 80.56;   // 290° of the circle, open at the bottom
  function bezel(mode, zone, frac) {
    var c = ZONE[zone] || ZONE.calm;
    var o = '<svg class="bezel" viewBox="0 0 466 466" aria-hidden="true">';
    if (mode === 'gauge') {
      o += '<circle class="trk" cx="233" cy="233" r="213" pathLength="100" stroke-dasharray="' + GAUGE + ' 100" transform="rotate(125 233 233)"/>';
      o += '<circle cx="233" cy="233" r="213" pathLength="100" stroke="' + c + '" stroke-dasharray="' + (GAUGE * frac).toFixed(2) + ' 100" transform="rotate(125 233 233)"/>';
    } else if (mode === 'ring' || mode === 'count') {
      o += '<circle class="trk" cx="233" cy="233" r="213"/>';
      o += '<circle class="arc" cx="233" cy="233" r="213" pathLength="100" stroke="' + c + '" stroke-dasharray="100 100" stroke-dashoffset="0" transform="rotate(-90 233 233)"/>';
    } else {
      o += '<circle class="trk" cx="233" cy="233" r="213"/>';
    }
    return o + '</svg>';
  }
  function gaugeFrac(bpm) { return Math.max(0.02, Math.min(1, (bpm - 45) / (110 - 45))); }
  var FACES = {
    home: { label: 'Watch home: 72 beats per minute, all good, at rest, max 110.', zone: 'calm',
      html: function () { return bezel('gauge', 'calm', gaugeFrac(72)) + '<div class="wf-in"><span class="w-badge">DEMO DATA</span><span class="w-status" style="color:#12B76A;margin-top:10px"><i class="w-dot"></i>All good</span><span class="w-hero">72</span><span class="w-unit">bpm</span><span class="w-line">At rest · max 110</span><div class="w-chips"><span class="w-chip">LQT2</span><span class="w-chip">Phone ✓</span></div></div><div class="w-dots"><i class="on"></i><i></i><i></i><i></i><i></i></div>'; } },
    near: { label: 'Near your max: 104 beats per minute at rest, max 110.', zone: 'elev',
      html: function () { return bezel('gauge', 'elev', gaugeFrac(104)) + '<div class="wf-in"><span class="w-badge">DEMO DATA</span><span class="w-status" style="color:#FDB022;margin-top:10px">▲ Near your max</span><span class="w-hero">104</span><span class="w-unit">bpm</span><span class="w-line">At rest · max 110</span><div class="w-chips"><span class="w-chip">LQT2</span><span class="w-chip">Syncing…</span></div></div><div class="w-dots"><i class="on"></i><i></i><i></i><i></i><i></i></div>'; } },
    high: { label: 'Heart rate high: 165 beats per minute at rest. Limit 110, LQT2 at rest. I\'m OK or Need help.', zone: 'alert',
      html: function () { return bezel('ring', 'alert') + '<div class="wf-in"><span class="w-cap" style="color:#F97066">▲ HEART RATE HIGH</span><span class="w-hero" style="color:#F04438">165</span><span class="w-unit">bpm · at rest</span><span class="w-line sm">Limit 110 · LQT2 at rest</span><div class="w-btns"><span class="w-btn">I\'m OK</span><span class="w-btn red">Need help</span></div></div>'; } },
    checkin: { label: 'Check-in: How do you feel? Fine, Dizzy or Racing.', zone: 'brand',
      html: function () { return bezel('ring', 'brand') + '<div class="wf-in"><span class="w-title">How do you feel?</span><div class="w-feel"><span class="fine"><b>✓</b>Fine</span><span class="dizzy"><b>≈</b>Dizzy</span><span class="racing"><b>♥</b>Racing</span></div><span class="w-line sm" style="margin-top:14px">Racing = palpitations</span></div>'; } },
    sos: { label: 'Sending SOS to your phone and contacts. Cancel.', zone: 'alert',
      html: function () { return bezel('count', 'alert') + '<div class="wf-in"><span class="w-cap" style="color:#F97066">SOS</span><span class="w-title">Sending SOS</span><span class="w-hero" data-count-sos>10</span><span class="w-line sm">to your phone and contacts</span><div class="w-btns"><span class="w-btn white">Cancel</span></div></div>'; } },
    sent: { label: 'SOS sent. Your phone is alerting your contacts. I have Long QT syndrome. Call 112.', zone: 'calm',
      html: function () { return bezel('ring', 'calm') + '<div class="wf-in"><span class="w-check"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg></span><span class="w-title">SOS sent</span><span class="w-line sm">Your phone is alerting your contacts.</span><span class="w-bystander">I have Long QT syndrome. Call 112.</span><div class="w-btns" style="margin-top:14px"><span class="w-btn">Done</span></div></div>'; } },
    verdict: { zone: 'alert',
      html: function () { return bezel('none') + '<div class="wf-in"><svg class="w-shape" aria-hidden="true"><use href="#r-known"/></svg><span class="w-title" style="font-size:36px">Clarithromycin</span><span class="w-status" style="color:#F97066;font-size:26px;margin-top:4px">Known risk</span><span class="w-line sm">Ask your doctor before you take it.</span><span class="w-line sm" style="color:#8A817B">Your watch now watches more closely.</span><div class="w-btns" style="margin-top:14px"><span class="w-btn">Got it</span></div></div>'; } },
    dose: { zone: 'brand',
      html: function () { return bezel('ring', 'brand') + '<div class="wf-in"><span class="w-cap" style="color:#F26B6F">DAILY DOSE</span><span class="w-title" style="margin-top:6px">Did you take Nadolol?</span><span class="w-line sm">Skipped beta-blocker doses raise the risk.</span><div class="w-btns"><span class="w-btn coral">Took it</span><span class="w-btn">Not yet</span></div></div>'; } },
    low: { zone: 'elev',
      html: function () { return bezel('ring', 'elev') + '<div class="wf-in"><span class="w-cap" style="color:#FDB022">▼ HEART RATE LOW</span><span class="w-hero" style="color:#FDB022">38</span><span class="w-unit">bpm · asleep</span><span class="w-line sm">Limit 45 · LQT3 asleep</span><span class="w-line sm" style="color:#FDB022">Gentle wake-up tone</span><div class="w-btns"><span class="w-btn">I\'m OK</span><span class="w-btn red">Need help</span></div></div>'; } },
    irregular: { zone: 'elev',
      html: function () { return bezel('ring', 'elev') + '<div class="wf-in"><span class="w-cap" style="color:#FDB022">▲ IRREGULAR RHYTHM</span><span class="w-title" style="color:#FDB022;font-size:64px;margin-top:6px">Irregular</span><span class="w-unit"><span class="w-sim">SIM</span>· at rest</span><span class="w-line sm">Sit down and breathe slowly.</span><div class="w-btns"><span class="w-btn">I\'m OK</span><span class="w-btn red">Need help</span></div></div>'; } },
    trend: { zone: 'calm',
      html: function () {
        // 20 slots × 30 s: grey range capsule with a white average tick; slots over the max turn red.
        var lo = [62, 64, 63, 66, 65, 68, 70, 74, 80, 86, 92, 100, 104, 108, 98, 90, 84, 78, 74, 70];
        var hi = [70, 72, 71, 74, 76, 78, 82, 86, 94, 100, 108, 114, 118, 116, 108, 98, 92, 86, 80, 76];
        var y = function (v) { return 100 - (v - 45) * 1.2; };
        var s = '<svg class="w-trend" viewBox="0 0 300 120" aria-hidden="true"><line class="lim" x1="0" x2="300" y1="' + y(110) + '" y2="' + y(110) + '"/><line class="lim" x1="0" x2="300" y1="' + y(45) + '" y2="' + y(45) + '"/>';
        for (var i = 0; i < 20; i++) {
          var x = 8 + i * 14.5, a = (lo[i] + hi[i]) / 2;
          s += '<line class="cap' + (hi[i] > 110 ? ' over' : '') + '" x1="' + x + '" x2="' + x + '" y1="' + y(hi[i]) + '" y2="' + y(lo[i]) + '"/><line class="tick" x1="' + (x - 4) + '" x2="' + (x + 4) + '" y1="' + y(a) + '" y2="' + y(a) + '"/>';
        }
        s += '</svg>';
        return bezel('none') + '<div class="wf-in"><span class="w-cap" style="color:#B8AEA8">LAST 10 MIN</span><span style="font-size:68px;font-weight:800;line-height:1;margin-top:6px">88 <small style="font-size:24px;color:#B8AEA8;font-weight:500">avg bpm</small></span><span class="w-line sm">Range 62–118 · <span style="color:#F97066">▲ 3 over max</span></span>' + s + '<span class="w-line sm" style="margin-top:0">Resting 62 bpm</span></div>';
      } }
  };
  function renderFace(el, name) {
    var f = FACES[name];
    if (!f) return;
    el.innerHTML = '<div class="wf">' + f.html() + '</div>';
    el.setAttribute('data-face', name);
    if (f.label && el.getAttribute('role') === 'img') el.setAttribute('aria-label', f.label);
  }
  document.querySelectorAll('.watch[data-face]').forEach(function (w) {
    if (w.id !== 'wseqFace') renderFace(w, w.getAttribute('data-face'));
  });

  (function () {
    var face = $('wseqFace'), list = $('wseqSteps'), glow = $('wseqGlow'), host = $('wseq');
    if (!face || !list) return;
    var items = Array.prototype.slice.call(list.querySelectorAll('li'));
    var order = items.map(function (li) { return li.getAttribute('data-face'); });
    var HOLD = { home: 2800, near: 2600, high: 3400, checkin: 3200, sent: 3600 };
    var cur = -1, timer = 0, visible = false;

    function show(i, auto) {
      clearTimeout(timer); clearInterval(timer);
      cur = i;
      var name = order[i];
      renderFace(face, name);
      var col = ZONE[FACES[name].zone];
      glow.style.background = col;
      items.forEach(function (li, j) { li.classList.toggle('is-on', j === i); li.style.setProperty('--dotc', col); });
      if (reduce) return;
      if (name === 'sos') {
        var arc = face.querySelector('.arc'), num = face.querySelector('[data-count-sos]'), n = 10;
        requestAnimationFrame(function () { requestAnimationFrame(function () {
          if (!arc) return;
          arc.style.transition = 'stroke-dasharray 10s linear, stroke-dashoffset 10s linear';
          arc.setAttribute('stroke-dasharray', '0 100');
          arc.setAttribute('stroke-dashoffset', '-100');
        }); });
        timer = setInterval(function () {
          n -= 1;
          if (num) num.textContent = String(Math.max(n, 0));
          if (n <= 0) { clearInterval(timer); if (visible) show(i + 1, true); }
        }, 1000);
        return;
      }
      if (auto !== false && visible) timer = setTimeout(function () { show((i + 1) % order.length, true); }, HOLD[name] || 3000);
    }
    items.forEach(function (li, j) {
      li.setAttribute('tabindex', '0');
      li.addEventListener('click', function () { show(j, true); });
      li.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); show(j, true); } });
    });
    show(0, false);
    if (reduce) return;
    onVisible(host, function (vis) {
      visible = vis;
      if (vis) show(cur < 0 ? 0 : cur, true); else { clearTimeout(timer); clearInterval(timer); }
    }, 0.35);
  })();

  /* ---------------- Agent stage (v2 02 → 03): what the user actually sees ---------------- */
  (function () {
    var phone = $('agentPhone'), host = $('agentSilk');
    if (!phone || !host || !host._orb) return;
    var orb = host._orb;
    var labelWrap = $('dockLabel'), label = $('dockLabelT'), glow = $('dockGlow');
    var liveState = $('liveState'), you = $('capYou'), ag = $('capAgent'), step = $('capStep'), stepL = $('capStepL');
    var card = $('capCard'), more = $('capShow'), starter = $('starterKlacid'), timeEl = $('voiceTime');
    var replay = $('cReplay');
    var stepsLi = Array.prototype.slice.call(document.querySelectorAll('#stageSteps li'));
    var token = 0, clock = 0, phase = 'OFF', amp = 0;
    var YOU = 'Can I take Klacid for my sinus infection?';

    function hl(st) { stepsLi.forEach(function (li) { li.classList.toggle('is-on', li.getAttribute('data-st') === st); }); }
    function setState(ph, text, who) {
      phase = ph;
      orb.setPhase(ph);
      label.textContent = text;
      labelWrap.setAttribute('data-who', who || 'agent');
      glow.classList.toggle('user', who === 'user');
    }
    // Synthetic voice level: the orb and its glow respond as they do to real audio (DESIGN 10.1a 03).
    function levelLoop(t) {
      var s = t / 1000, target = 0;
      if (phase === 'SPEAKING') target = 0.35 + 0.45 * Math.abs(Math.sin(s * 8.3) * Math.sin(s * 2.9));
      else if (phase === 'HEARING') target = 0.25 + 0.4 * Math.abs(Math.sin(s * 6.1) * Math.cos(s * 1.7));
      amp += (target - amp) * 0.2;
      orb.setLevel(amp);
      var liveMode = phone.getAttribute('data-mode') === 'live';
      glow.style.opacity = liveMode ? (0.6 + 0.4 * amp).toFixed(3) : '0.3';
      glow.style.transform = 'scale(' + (liveMode ? 1.1 + 0.2 * amp : 1).toFixed(3) + ')';
      requestAnimationFrame(levelLoop);
    }
    function prepAgent() {
      ag.textContent = '';
      ag.getAttribute('data-text').split(' ').forEach(function (w, i, all) {
        var sp = document.createElement('span');
        sp.className = 'tw';
        sp.textContent = w + (i < all.length - 1 ? ' ' : '');
        ag.appendChild(sp);
      });
    }
    function tick() {
      clock += 1;
      timeEl.textContent = Math.floor(clock / 60) + ':' + ('0' + (clock % 60)).slice(-2);
    }
    function reset() {
      phone.setAttribute('data-mode', 'empty');
      [you, ag, step, card, more].forEach(function (el) { el.classList.remove('on', 'done', 'interim'); });
      liveState.classList.remove('gone');
      liveState.textContent = "I'm listening";
      you.textContent = '';
      stepL.textContent = 'Checking the QT list';
      starter.classList.remove('pressed');
      prepAgent();
      clock = 0; timeEl.textContent = '0:00';
      replay.hidden = true;
      setState('OFF', 'Tap to talk');
      hl('off');
    }
    function finalState() {
      phone.setAttribute('data-mode', 'live');
      liveState.classList.add('gone');
      you.textContent = 'You: ' + YOU;
      stepL.textContent = 'Checked the QT list';
      step.classList.add('done');
      [you, ag, step, card, more].forEach(function (el) { el.classList.add('on'); });
      ag.querySelectorAll('.tw').forEach(function (w) { w.classList.add('said'); });
      timeEl.textContent = '0:42';
      setState('LISTENING', "I'm listening", 'user');
    }
    async function play() {
      var my = ++token;
      var alive = function () { return my === token; };
      var timer = 0;
      reset();
      await wait(1400); if (!alive()) return;
      starter.classList.add('pressed');
      await wait(450); if (!alive()) return;
      phone.setAttribute('data-mode', 'live');
      timer = setInterval(function () { if (alive()) tick(); else clearInterval(timer); }, 1000);
      setState('CONNECTING', 'Connecting…');
      await wait(800); if (!alive()) return;
      setState('LISTENING', "I'm listening", 'user');
      await wait(900); if (!alive()) return;
      setState('HEARING', 'Listening…', 'user'); hl('hearing');
      liveState.classList.add('gone');
      you.classList.add('on', 'interim');
      var words = YOU.split(' ');
      for (var i = 0; i < words.length; i++) {
        you.textContent = 'You: ' + words.slice(0, i + 1).join(' ');
        await wait(190); if (!alive()) return;
      }
      you.classList.remove('interim');
      await wait(300); if (!alive()) return;
      setState('THINKING', 'Checking the QT list…'); hl('thinking');
      step.classList.add('on');
      await wait(1600); if (!alive()) return;
      step.classList.add('done'); stepL.textContent = 'Checked the QT list';
      setState('SPEAKING', 'Speaking'); hl('speaking');
      ag.classList.add('on');
      var tws = ag.querySelectorAll('.tw');
      for (var k = 0; k < tws.length; k++) {
        tws[k].classList.add('said');
        await wait(150); if (!alive()) return;
      }
      await wait(250); if (!alive()) return;
      card.classList.add('on');
      await wait(700); if (!alive()) return;
      more.classList.add('on');
      setState('LISTENING', "I'm listening", 'user'); hl('');
      clearInterval(timer);
      await wait(400); if (!alive()) return;
      replay.hidden = false;   // only once the whole exchange has played out
    }

    if (reduce) { prepAgent(); finalState(); return; }
    reset();
    requestAnimationFrame(levelLoop);
    var started = false;
    onVisible(phone, function (vis) { if (vis && !started) { started = true; play(); } }, 0.45);
    replay.addEventListener('click', function () { play(); });
  })();

  /* ---------------- Emergency card: 13 languages + tilt ---------------- */
  (function () {
    var texts = window.CARD_TEXTS;
    var wrap = $('langs');
    var card = document.querySelector('.alert-card');
    if (!wrap || !card) return;
    var fields = [['cardTitle', 'title'], ['cardCond', 'condition'], ['cardAvoid', 'avoid'], ['cardMedsL', 'meds']];
    var els = fields.map(function (f) { var e = $(f[0]); e.classList.add('fade-swap'); return e; });
    var cur = 0, userPicked = false, timer = 0, visible = false;

    if (!texts || !texts.length) { wrap.style.display = 'none'; return; }
    var buttons = texts.map(function (t, i) {
      var b = document.createElement('button');
      b.type = 'button';
      b.textContent = t.language;
      b.lang = t.code;
      b.setAttribute('aria-pressed', i === 0 ? 'true' : 'false');
      b.addEventListener('click', function () { userPicked = true; clearInterval(timer); setLang(i); });
      wrap.appendChild(b);
      return b;
    });
    function setLang(i) {
      if (i === cur && card.getAttribute('lang')) return;
      cur = i;
      buttons.forEach(function (b, j) { b.setAttribute('aria-pressed', j === i ? 'true' : 'false'); });
      var t = texts[i];
      els.forEach(function (e) { e.classList.add('out'); });
      setTimeout(function () {
        els.forEach(function (e, k) { e.textContent = t[fields[k][1]]; e.classList.remove('out'); });
        card.setAttribute('lang', t.code);
      }, reduce ? 0 : 220);
    }
    card.setAttribute('lang', 'en');
    if (!reduce) {
      onVisible(card, function (vis) {
        visible = vis;
        clearInterval(timer);
        if (vis && !userPicked) timer = setInterval(function () { if (visible) setLang((cur + 1) % texts.length); }, 2600);
      }, 0.5);
    }

    if (!fine || reduce) return;
    var tiltEl = $('cardTilt');
    var tx = 0, ty = 0, cx = 0, cy = 0, live = false;
    tiltEl.addEventListener('pointermove', function (e) {
      var r = tiltEl.getBoundingClientRect();
      tx = (e.clientX - r.left) / r.width * 2 - 1;
      ty = (e.clientY - r.top) / r.height * 2 - 1;
      card.style.setProperty('--sx', ((tx + 1) * 50) + '%');
      card.style.setProperty('--sy', ((ty + 1) * 50) + '%');
      if (!live) { live = true; requestAnimationFrame(loop); }
    });
    tiltEl.addEventListener('pointerleave', function () { tx = 0; ty = 0; });
    function loop() {
      cx += (tx - cx) * 0.1; cy += (ty - cy) * 0.1;
      card.style.transform = 'rotateY(' + (cx * 9).toFixed(2) + 'deg) rotateX(' + (-cy * 7).toFixed(2) + 'deg)';
      if (Math.abs(tx - cx) > 0.001 || Math.abs(ty - cy) > 0.001 || tx !== 0 || ty !== 0) requestAnimationFrame(loop);
      else live = false;
    }
  })();

  /* ---------------- Report: count up and draw the trend ---------------- */
  if (motion) {
    var report = $('report');
    gsap.set('#chartLine', { strokeDashoffset: 1 });
    gsap.set('#chartArea', { opacity: 0 });
    gsap.set('#chartDot', { scale: 0, transformOrigin: '50% 50%' });
    gsap.fromTo(report, { y: 60, rotateX: 8, opacity: 0 }, { y: 0, rotateX: 0, opacity: 1, duration: 1.4, ease: 'expo.out',
      scrollTrigger: { trigger: report, start: 'top 85%', once: true } });
    ST.create({
      trigger: report, start: 'top 70%', once: true,
      onEnter: function () {
        var tl = gsap.timeline();
        tl.to('#chartLine', { strokeDashoffset: 0, duration: 1.8, ease: 'power2.inOut' }, 0.2)
          .to('#chartArea', { opacity: 0.08, duration: 1 }, 1)
          .to('#chartDot', { scale: 1, duration: 0.6, ease: 'back.out(3)' }, 1.8);
        report.querySelectorAll('[data-count]').forEach(function (b) {
          var n = { v: 0 }, end = parseFloat(b.getAttribute('data-count'));
          b.textContent = '0';
          tl.to(n, { v: end, duration: 1.2, ease: 'power2.out', onUpdate: function () { b.textContent = String(Math.round(n.v)); } }, 0.3);
        });
      }
    });
  }
})();
