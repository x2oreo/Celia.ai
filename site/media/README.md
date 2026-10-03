# Landing page media

Drop files here with these exact names and the landing page (`site/index.html`) picks them up. A missing file keeps
its designed placeholder, so the page never shows a broken image.

| File | Where it shows | Shape |
|---|---|---|
| `demo.mp4` | "See it working" main video | 16:9, H.264, keep under ~30 MB |
| `demo-poster.jpg` | Still frame before the video plays | 16:9 |
| `hero-phone.png` | Replaces the drawn phone screen in the hero | 360 × 780 (or any 9:19.5 screenshot) |
| `screen-1.png` … `screen-4.png` | Gallery: Home, Scan a box, My medicines, Emergency card | 9:19.5 portrait |
| `watch.jpg` | Gallery: the watch on a wrist | any, cropped to fill |
| `team-kaloyan.jpg`, `team-georgi.jpg`, `team-mark.jpg` | Team portraits | square |

Captions and alt text live next to each slot in `index.html`; change them there if a screenshot shows something else.
Videos and images must be served from this site: the Content-Security-Policy in `vercel.json` allows `'self'` only.
