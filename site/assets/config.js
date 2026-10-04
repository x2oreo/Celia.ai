// Where the viewer pages fetch encrypted shares from (Supabase Edge Function `share`). Public URL - no secrets.
// On localhost the pages talk to the local dev backend (backend/eval/dev-backend.ts) instead.
window.CELIA_SHARE_API = (location.hostname === 'localhost' || location.hostname === '127.0.0.1')
  ? 'http://127.0.0.1:8000/functions/v1/share'
  : 'https://jxiggumhircfuhianmel.supabase.co/functions/v1/share';
