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
  document.querySelectorAll('video[data-src]').forEach(function (video) {
    var poster = video.getAttribute('data-poster');
    if (poster) {
      var p = new Image();
      p.onload = function () { video.poster = poster; };
      p.src = poster;
    }
    video.addEventListener('loadedmetadata', function () { fill(video); }, { once: true });
    video.preload = 'metadata';
    video.src = video.getAttribute('data-src');
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
  // A dot grid that a coral pulse sweeps through on a lub-dub rhythm and that bends away from the cursor.
  // It is a ripple from the orb, never a trace of a heart signal.
  function Field(canvas, center, host) {
    var ctx = canvas.getContext('2d');
    var dots = [];
    var waves = [];
    var W = 0, H = 0, dpr = 1;
    var mouse = { x: -9999, y: -9999 };
    var running = false;
    var lastBeat = 0;
    var GAP = 30, PERIOD = 1100, SPEED = 0.42, WIDTH = 30;

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
        setTimeout(function () { waves.push({ t: performance.now(), s: 0.55 }); }, 190);
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
  if ($('heroField')) Field($('heroField'), document.querySelector('.orb-hero'), heroSec);
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
    var els = [$('heroBpm'), $('heroWatchBpm'), $('watchBpm')].filter(Boolean);
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

  /* ---------------- Agent conversation ---------------- */
  (function () {
    var convo = $('convo'), orb = $('voiceOrb'), label = $('voiceLabel');
    if (!convo || !orb) return;
    var user = $('cUser'), s1 = $('cStep1'), s2 = $('cStep2'), agent = $('cAgent'), card = $('cCard'), replay = $('cReplay');
    var mode = 'off', amp = 0, token = 0, looping = false;

    function setState(state, text) {
      mode = state;
      orb.setAttribute('data-state', state === 'hearing' ? 'listening' : state);
      label.textContent = text;
    }
    function ampLoop(t) {
      var target = 0;
      var s = t / 1000;
      if (mode === 'speaking') target = 0.35 + 0.4 * Math.abs(Math.sin(s * 9.1) * Math.sin(s * 3.3)) + Math.random() * 0.15;
      else if (mode === 'hearing') target = 0.2 + 0.35 * Math.abs(Math.sin(s * 7.3) * Math.cos(s * 2.1));
      else if (mode === 'listening') target = 0.08 * Math.abs(Math.sin(s * 2));
      amp += (target - amp) * 0.18;
      orb.style.setProperty('--amp', amp.toFixed(3));
      if (looping) requestAnimationFrame(ampLoop);
    }
    function show(el) { el.classList.add('on'); }
    function stepRun(el) {
      var l = el.querySelector('.ts-l');
      l.textContent = l.getAttribute('data-run');
      el.classList.remove('done'); el.classList.add('run'); show(el);
      return l.textContent;
    }
    function stepDone(el) {
      var l = el.querySelector('.ts-l');
      l.textContent = l.getAttribute('data-done');
      el.classList.remove('run'); el.classList.add('done');
    }
    function prepAgent() {
      agent.textContent = '';
      agent.getAttribute('data-text').split(' ').forEach(function (w, i, all) {
        var sp = document.createElement('span');
        sp.className = 'tw';
        sp.textContent = w + (i < all.length - 1 ? ' ' : '');
        agent.appendChild(sp);
      });
      agent.setAttribute('aria-label', agent.getAttribute('data-text'));
    }
    function reset() {
      [user, s1, s2, agent, card, replay].forEach(function (el) { el.classList.remove('on', 'run', 'done', 'interim'); });
      user.textContent = '';
      prepAgent();
    }
    function finalState() {
      reset();
      user.textContent = user.getAttribute('data-text');
      stepDone(s1); stepDone(s2);
      agent.querySelectorAll('.tw').forEach(function (w) { w.classList.add('v'); });
      [user, s1, s2, agent, card].forEach(show);
      setState('off', 'Tap to talk');
    }
    async function play() {
      var my = ++token;
      var alive = function () { return my === token; };
      reset();
      setState('listening', "I'm listening");
      await wait(900); if (!alive()) return;
      setState('hearing', 'Listening…');
      show(user); user.classList.add('interim');
      var words = user.getAttribute('data-text').split(' ');
      for (var i = 0; i < words.length; i++) {
        user.textContent = words.slice(0, i + 1).join(' ');
        await wait(170); if (!alive()) return;
      }
      user.classList.remove('interim');
      await wait(350); if (!alive()) return;
      setState('thinking', stepRun(s1) + '…');
      await wait(1300); if (!alive()) return;
      stepDone(s1);
      setState('thinking', stepRun(s2) + '…');
      await wait(1200); if (!alive()) return;
      stepDone(s2);
      setState('speaking', 'Speaking');
      show(agent);
      var tws = agent.querySelectorAll('.tw');
      for (var k = 0; k < tws.length; k++) {
        tws[k].classList.add('v');
        await wait(105); if (!alive()) return;
      }
      show(card);
      await wait(500); if (!alive()) return;
      setState('off', 'Tap to talk');
      show(replay);
    }

    if (reduce) { finalState(); show(replay); replay.style.display = 'none'; return; }
    looping = true; requestAnimationFrame(ampLoop);
    var started = false;
    onVisible(convo, function (vis) {
      if (vis && !started) { started = true; play(); }
    }, 0.35);
    replay.addEventListener('click', function () { play(); });
    orb.parentElement.addEventListener('click', function () { play(); });
  })();

  /* ---------------- Watch row: rings draw, SOS ring drains over 10 s ---------------- */
  (function () {
    var row = $('watchRow'), count = $('sosCount');
    if (!row) return;
    if (reduce || !('IntersectionObserver' in window)) { row.classList.add('is-in'); return; }
    var timer = 0, visible = false;
    function cycle() {
      clearTimeout(timer);
      row.classList.remove('is-draining');
      count.textContent = '10';
      timer = setTimeout(function () {
        if (!visible) return;
        row.classList.add('is-draining');
        var n = 10;
        var tick = function () {
          n -= 1;
          count.textContent = String(Math.max(n, 0));
          if (n > 0 && visible) timer = setTimeout(tick, 1000);
          else if (visible) timer = setTimeout(cycle, 1800);
        };
        timer = setTimeout(tick, 1000);
      }, 1600);
    }
    onVisible(row, function (vis) {
      visible = vis;
      if (vis) { row.classList.add('is-in'); cycle(); } else clearTimeout(timer);
    }, 0.3);
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
