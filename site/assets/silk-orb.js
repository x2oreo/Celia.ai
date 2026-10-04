// The agent's silk orb for the web: a direct port of app/entry/src/main/ets/components/SilkOrb.ets (DESIGN.md §6.6).
// Same palette ("Dawn"), same state looks and easing, same bands, blobs, soft edge, glow and halo, drawn with
// plain 2D canvas calls. A slow single breath, never a double beat; nothing here looks like an ECG trace.
//
// Usage: <span data-silk data-size="104" data-phase="OFF"></span>, or SilkOrb.mount(el, { size, phase, small }).
// Phases: OFF, CONNECTING, LISTENING, HEARING, THINKING, SPEAKING; plus muted. Reduced motion: one settled frame.
(function () {
  'use strict';

  var INNER = [255, 206, 176];
  var MID = [242, 116, 112];
  var EDGE = [212, 96, 156];
  var BLOB_A = [255, 220, 170];
  var BLOB_B = [196, 96, 178];
  var BLOB_C = [255, 140, 118];
  var LINE = [255, 246, 240];
  var HALO_INK = [138, 129, 123];   // ink_4: the user's (neutral) halo

  var TWO_PI = 6.2832;
  var SEGMENTS = 44;
  var GROUPS = 3;
  var CANVAS_SCALE = 1.9;

  function Look(ink, dim, swirl, out, inw, halo, lines) {
    this.ink = ink; this.dim = dim; this.swirl = swirl; this.out = out; this.inw = inw; this.halo = halo; this.lines = lines;
  }
  var LOOKS = {
    OFF: new Look(0, 1, 0, 0, 0, 0, 0.45),
    CONNECTING: new Look(0, 1, 0.5, 0, 0, 0.3, 0.8),
    LISTENING: new Look(1, 1, 0, 0, 0, 0.7, 0.55),
    HEARING: new Look(1, 1, 0, 0, 1, 1, 0.9),
    THINKING: new Look(0, 0.88, 1, 0, 0, 0.3, 0.9),
    SPEAKING: new Look(0, 1, 0, 1, 0, 1, 1),
    MUTED: new Look(0, 0.45, 0, 0, 0, 0, 0.15)
  };

  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function rgba(c, a) {
    var alpha = Math.max(0, Math.min(1, a));
    return 'rgba(' + Math.round(c[0]) + ',' + Math.round(c[1]) + ',' + Math.round(c[2]) + ',' + alpha.toFixed(3) + ')';
  }
  function mix(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }

  function Orb(host, opts) {
    var self = this;
    this.host = host;
    this.dim = opts.size || 168;
    this.phase = opts.phase || 'OFF';
    this.small = !!opts.small;
    this.muted = false;
    this.level = 0;
    this.look = new Look(0, 1, 0, 0, 0, 0, 0.45);
    this.lvl = 0; this.drift = Math.random() * 10; this.spin = 0; this.clock = 0; this.last = 0;
    this.visible = false; this.running = false;

    host.classList.add('silk');
    host.style.width = this.dim + 'px';
    host.style.height = this.dim + 'px';
    var side = this.dim * CANVAS_SCALE;
    var canvas = document.createElement('canvas');
    canvas.setAttribute('aria-hidden', 'true');
    canvas.style.width = side + 'px';
    canvas.style.height = side + 'px';
    canvas.style.margin = (-(side - this.dim) / 2) + 'px';
    host.appendChild(canvas);
    this.canvas = canvas;
    this.g = canvas.getContext('2d');
    this.resize();

    if ('IntersectionObserver' in window) {
      new IntersectionObserver(function (es) {
        es.forEach(function (e) { self.visible = e.isIntersecting; self.restart(); });
      }, { rootMargin: '80px' }).observe(host);
    } else { this.visible = true; this.restart(); }
    this.settle();
  }

  Orb.prototype.resize = function () {
    var side = this.dim * CANVAS_SCALE;
    var dpr = Math.min(2, window.devicePixelRatio || 1);
    this.canvas.width = Math.round(side * dpr);
    this.canvas.height = Math.round(side * dpr);
    this.g.setTransform(dpr, 0, 0, dpr, 0, 0);
  };
  Orb.prototype.target = function () { return this.muted ? LOOKS.MUTED : (LOOKS[this.phase] || LOOKS.OFF); };
  Orb.prototype.levelTarget = function () {
    if (this.muted) return 0;
    if (this.phase === 'HEARING' || this.phase === 'SPEAKING') return Math.max(0.25, Math.min(1, this.level));
    return this.phase === 'LISTENING' ? Math.min(1, this.level) * 0.5 : 0;
  };
  Orb.prototype.step = function (dt) {
    var t = this.target(), p = this.look, k = Math.min(1, dt * 6);
    p.ink += (t.ink - p.ink) * k; p.dim += (t.dim - p.dim) * k; p.swirl += (t.swirl - p.swirl) * k;
    p.out += (t.out - p.out) * k; p.inw += (t.inw - p.inw) * k; p.halo += (t.halo - p.halo) * k;
    p.lines += (t.lines - p.lines) * k;
    this.lvl += (this.levelTarget() - this.lvl) * Math.min(1, dt * 9);
    this.drift += dt * (0.55 + 1.5 * this.lvl + 0.5 * p.lines);
    this.spin += dt * 2.4;
    this.clock += dt;
  };
  Orb.prototype.soft = function (x, y, r, c, a) {
    if (a <= 0.002 || r <= 0) return;
    var g = this.g, grad = g.createRadialGradient(x, y, 0, x, y, r);
    grad.addColorStop(0, rgba(c, a));
    grad.addColorStop(1, rgba(c, 0));
    g.beginPath(); g.arc(x, y, r, 0, TWO_PI); g.fillStyle = grad; g.fill();
  };
  // One group of silk bands: latitude circles of a unit sphere around a slowly tumbling axis, front half only.
  Orb.prototype.bands = function (c, r, k, count) {
    var p = this.look, g = this.g;
    var yaw = this.drift * (0.35 + 0.12 * k) * (1 - p.swirl) + this.spin * p.swirl + k * 2.1 * (1 - p.swirl * 0.85);
    var pitch = Math.sin(this.drift * 0.23 + k * 1.7) * 0.9 * (1 - p.swirl) + 0.35 * p.swirl;
    var nx = Math.cos(pitch) * Math.cos(yaw), ny = Math.cos(pitch) * Math.sin(yaw), nz = Math.sin(pitch);
    var ux = -ny, uy = nx, ul = Math.sqrt(ux * ux + uy * uy) || 1;
    ux /= ul; uy /= ul;
    var vx = -nz * uy, vy = nz * ux, vz = nx * uy - ny * ux;
    var amp = 0.012 + 0.05 * this.lvl;
    for (var i = 0; i < count; i++) {
      var phi = 0.5 + 0.78 * (i / (count - 1)) + 0.06 * Math.sin(this.drift * 0.6 + k);
      var cp = Math.cos(phi), sp = Math.sin(phi), open = false;
      g.beginPath();
      for (var s = 0; s <= SEGMENTS; s++) {
        var th = s / SEGMENTS * TWO_PI;
        var rr = 1 + amp * Math.sin(th * 3 + this.drift * 2.2 + i * 0.7 + k);
        var ct = Math.cos(th), st = Math.sin(th);
        var x = rr * (cp * (ux * ct + vx * st) + sp * nx);
        var y = rr * (cp * (uy * ct + vy * st) + sp * ny);
        var z = cp * (vz * st) + sp * nz;
        if (z > -0.02) {
          if (open) g.lineTo(c + x * r, c + y * r); else { g.moveTo(c + x * r, c + y * r); open = true; }
        } else open = false;
      }
      g.strokeStyle = rgba(LINE, (0.16 + 0.5 * (i / count)) * p.lines * (0.55 + 0.6 * this.lvl + 0.2 * p.swirl));
      g.lineWidth = 0.8 + 1.1 * (i / count);
      g.stroke();
    }
  };
  Orb.prototype.paint = function () {
    var p = this.look, g = this.g, side = this.dim * CANVAS_SCALE, c = side / 2;
    var breath = reduced ? 1 : 1 + 0.025 * Math.sin(this.clock * 1.57);
    var r = this.dim / 2 * breath * (1 + 0.08 * this.lvl * p.out - 0.03 * p.inw);
    var d = this.drift;
    g.globalCompositeOperation = 'source-over';
    g.clearRect(0, 0, side, side);
    var base = g.createRadialGradient(c - r * 0.2, c - r * 0.25, 0, c, c, r * 1.1);
    base.addColorStop(0, rgba(INNER, 1));
    base.addColorStop(0.6, rgba(MID, 1));
    base.addColorStop(1, rgba(EDGE, 1));
    g.fillStyle = base;
    g.fillRect(c - r * 1.12, c - r * 1.12, r * 2.24, r * 2.24);
    this.soft(c + Math.cos(d * 0.9) * r * 0.42, c + Math.sin(d * 0.7) * r * 0.42, r * 0.9, BLOB_A, 0.8);
    this.soft(c + Math.cos(d * 0.6 + 2.1) * r * 0.5, c + Math.sin(d * 0.4 + 2.1) * r * 0.5, r * 0.85, BLOB_B, 0.5);
    this.soft(c + Math.cos(d * 1.1 + 4.2) * r * 0.4, c + Math.sin(d * 1.0 + 4.2) * r * 0.4, r * 0.75, BLOB_C, 0.7);
    g.lineCap = 'round';
    var count = this.small ? 4 : 8;
    for (var k = 0; k < GROUPS; k++) this.bands(c, r, k, count);
    g.globalCompositeOperation = 'destination-in';
    var mask = g.createRadialGradient(c, c, r * 0.74, c, c, r * 1.06);
    mask.addColorStop(0, 'rgba(0,0,0,' + p.dim.toFixed(3) + ')');
    mask.addColorStop(1, 'rgba(0,0,0,0)');
    g.fillStyle = mask;
    g.fillRect(0, 0, side, side);
    g.globalCompositeOperation = 'destination-over';
    this.soft(c, c + r * 0.14, Math.min(c, r * 1.4), MID, 0.16 * p.dim);
    this.soft(c, c, Math.min(c, r * (1.45 + 0.45 * this.lvl)), mix(MID, HALO_INK, p.ink), 0.26 * p.halo * (0.5 + this.lvl));
    g.globalCompositeOperation = 'source-over';
  };
  Orb.prototype.frame = function (now) {
    if (!this.running) return;
    var self = this;
    var dt = Math.min(0.05, this.last > 0 ? (now - this.last) / 1000 : 0.016);
    this.last = now;
    this.step(dt);
    this.paint();
    requestAnimationFrame(function (t) { self.frame(t); });
  };
  // One settled frame: where the state ends up, without the motion in between.
  Orb.prototype.settle = function () { for (var i = 0; i < 60; i++) this.step(0.05); this.paint(); };
  Orb.prototype.restart = function () {
    var self = this;
    if (reduced) { this.settle(); return; }
    var want = this.visible && !document.hidden;
    if (want && !this.running) { this.running = true; this.last = 0; requestAnimationFrame(function (t) { self.frame(t); }); }
    else if (!want) this.running = false;
  };
  Orb.prototype.setPhase = function (ph) { this.phase = ph; if (reduced || !this.running) this.settle(); };
  Orb.prototype.setLevel = function (l) { this.level = l; };
  Orb.prototype.setMuted = function (m) { this.muted = !!m; if (reduced || !this.running) this.settle(); };

  var all = [];
  document.addEventListener('visibilitychange', function () { all.forEach(function (o) { o.restart(); }); });

  window.SilkOrb = {
    mount: function (el, opts) { var o = new Orb(el, opts || {}); all.push(o); el._orb = o; return o; },
    mountAll: function (root) {
      (root || document).querySelectorAll('[data-silk]').forEach(function (el) {
        if (el._orb) return;
        window.SilkOrb.mount(el, {
          size: parseFloat(el.getAttribute('data-size')) || 168,
          phase: el.getAttribute('data-phase') || 'OFF',
          small: el.hasAttribute('data-small')
        });
      });
    }
  };
})();
