// Opens an end-to-end encrypted Celia share in the browser.
//   link:  https://<viewer>/<kind>/#<id>.<key>
//   fetch: GET <CELIA_SHARE_API>?id=<id>  →  { kind, ciphertext, expiresAt }
//   open:  AES-256-GCM with the key from the #fragment (never sent anywhere), layout iv(12) | ciphertext | tag(16)
(function () {
  'use strict';

  function fromB64url(text) {
    var b64 = text.replace(/-/g, '+').replace(/_/g, '/');
    while (b64.length % 4) { b64 += '='; }
    var bin = atob(b64);
    var bytes = new Uint8Array(bin.length);
    for (var i = 0; i < bin.length; i++) { bytes[i] = bin.charCodeAt(i); }
    return bytes;
  }

  // '#<16 base62>.<43 base64url>' → { id, key } or null (anything else, e.g. the legacy in-link card payload)
  function parseHash(hash) {
    var m = String(hash || '').replace(/^#/, '').match(/^([A-Za-z0-9]{16})\.([A-Za-z0-9_-]{43})$/);
    return m ? { id: m[1], key: m[2] } : null;
  }

  async function decrypt(ciphertext, key) {
    var all = fromB64url(ciphertext);
    var raw = fromB64url(key);
    var k = await crypto.subtle.importKey('raw', raw, { name: 'AES-GCM' }, false, ['decrypt']);
    var plain = await crypto.subtle.decrypt({ name: 'AES-GCM', iv: all.slice(0, 12) }, k, all.slice(12));
    return new TextDecoder('utf-8').decode(plain);
  }

  // Resolves to { status: 'ok', data, expiresAt } | { status: 'gone' } | { status: 'expired' } | { status: 'error' }
  async function open(kind) {
    var ref = parseHash(location.hash);
    if (!ref) { return { status: 'invalid' }; }
    var res;
    try {
      res = await fetch(window.CELIA_SHARE_API + '?id=' + ref.id, { cache: 'no-store', referrerPolicy: 'no-referrer' });
    } catch (e) {
      return { status: 'offline' };
    }
    if (res.status === 404) { return { status: 'gone' }; }
    if (res.status === 410) { return { status: 'expired' }; }
    if (!res.ok) { return { status: 'error' }; }
    try {
      var body = await res.json();
      if (body.kind !== kind) { return { status: 'invalid' }; }
      var json = await decrypt(body.ciphertext, ref.key);
      return { status: 'ok', data: JSON.parse(json), expiresAt: body.expiresAt };
    } catch (e) {
      return { status: 'invalid' };
    }
  }

  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) { e.className = cls; }
    if (text !== undefined && text !== null) { e.textContent = String(text); }
    return e;
  }

  // Reveal content groups once, staggered (CSS does the motion; reduced motion = opacity only).
  function reveal(root) {
    var groups = root.querySelectorAll('[data-reveal]');
    for (var i = 0; i < groups.length; i++) {
      groups[i].style.setProperty('--d', Math.min(i, 4) * 40 + 'ms');
    }
    requestAnimationFrame(function () { root.classList.add('is-ready'); });
  }

  window.CeliaShare = { open: open, parseHash: parseHash, el: el, reveal: reveal, fromB64url: fromB64url };
})();
