# USpace landing page

A separate, responsive marketing website for the existing USpace Flutter web app. All website source, assets, dependencies, tests, and generated output stay in this directory. It neither imports Flutter code nor connects to Supabase.

## Run locally

Use Node.js 22.12+ (tested with 22.17.1) and npm:

```powershell
cd 'C:\USPACE APP\6ADET-FINAL-PROJECT--USpace-APP\landing-page'
npm ci
npm run dev
```

Open http://127.0.0.1:5173/. The port is strict: if occupied, stop the other process or explicitly choose another with `npm run dev -- --port 5174`.

```powershell
npm run lint
npm run build
npx playwright install chromium
npm test
```

Tests start and stop a production preview on port 4173. Keep that port free when running them. To explore the production build manually, run `npm run preview` and open http://127.0.0.1:4173/.

No environment variables, credentials, API keys, or Flutter installation are needed. Do not copy the app's `.env` into this directory.

## Implementation

The current capsule source mapping, timing verification, renderer limitations, and intro behavior are documented in [ANIMATION_REFERENCE.md](ANIMATION_REFERENCE.md). The active implementation is `capsule-frames.js` + `capsule-painter.js` + `capsule.js`, replacing the earlier generic envelope. The intro now lasts four seconds, is present before the first page paint, and replays on refresh; in-page navigation never restarts it. Earlier continuation descriptions below are historical.

- `src/capsule.js` / `src/capsule.css` wrap the Time Capsule preview in a reversible 2.4-second wax-seal, flap, and letter animation using native Web Animations. The tab, card, and accessible envelope-icon link lead to the same experience. The toggle reverses from the current animation position; switching features resets the envelope. Reduced motion settles immediately. The original app screenshot is preserved in the ready demo. The separate locked example contains only public demo release metadata and a countdown; no protected letter is loaded. This presentation never reads or changes Supabase data, release dates, authentication, or policies.
- `src/reveals.js` and `src/story-motion.css` provide viewport-aware hero sizing, staged hero entrances after the welcome animation, alternating card entrances, and repeatable section reveals. Elements reset only fully outside the viewport; focused content stays visible. Mobile content may naturally exceed one viewport to retain readable text and usable controls. Native scrolling and hash navigation remain unchanged.

- `src/entrance.js` animates the HTML-mounted branding intro for four seconds (configurable with `window.USPACE_INTRO_MS`). It completes automatically, respects reduced motion, and does not replay when switching page sections. There is no visible Skip intro button; Escape remains available, including if modules fail to load.
- `src/timeline.js` and `src/timeline.css` add an editable scrapbook in the Timeline preview. Click the hero Timeline phone or choose Timeline in the gallery. Add up to eight memories, edit a title/date/note/illustrated cover, remove memories, or reset the demo. Native dialog controls support Escape and return focus to the trigger or saved card. Memory edits remain in memory only and reset on refresh; no account or backend is connected.

- `src/mood.js` and `src/mood.css` provide a native HTML mood demo in the hero, feature card, and Moods gallery. Loved, Calm, and Need a hug update the artwork, message, pressed button, and polite announcement together. Selections are held only in memory; nothing is saved or sent. The hero and Moods preview replace the original test-account Home screenshot, and are explicitly labeled as demos. Keyboard controls and live reduced-motion changes are supported.

- Scroll polish lives in `src/motion.js` and `src/polish.css`: phone parallax, staggered entrances, inward-moving story rings and keepsake cards, pointer-following card highlights, active navigation, and a reading-progress line. Native scrolling remains intact; decorative movement is disabled for reduced motion, including preference changes while the page is open.

- Semantic HTML, custom CSS, and small vanilla JavaScript modules; Vite handles local development, hashed bundles, and relative deployment paths. A client framework would add unnecessary runtime work for a presentation page.
- Locally bundled Inter and Playfair Display variable fonts reproduce the existing brand. Their OFL licenses are included in `public/licenses/` and copied to the build.
- The existing plum (`#140C14`), rose (`#E39AAE`), and cream (`#FFF3EC`) tokens come from `../lib/theme/us_palette.dart`. The wordmark follows `uspace_wordmark.dart`.
- Sticky navigation, mobile menu with Escape dismissal, anchor navigation, six keyboard-operable preview tabs, native FAQ accordions, scroll reveals, subtle phone motion, reduced-motion support, a skip link, focus indicators, and no-JavaScript fallbacks.
- All page copy is in `index.html`; screen-switcher copy is in `src/main.js`. Layout, type, tokens, and motion are in `src/style.css`.
- Build output is `dist/`. The `base: './'` setting permits a standalone origin or subdirectory. No deployment configuration, hosting registration, git commit, or push is performed.

## Assets and product accuracy

Seven real screenshots from `../docs/screenshots/` are resized and compressed to WebP; six remain displayed, while `home.webp` is retained as an unused source asset. The app's README documents their fictional sample data. Screenshot pixels are unchanged. The hero's foreground phone and Moods gallery now use a labeled, interactive HTML demo instead of the Home screenshot. Other screenshot captions disclose their source and sample data. Three mood illustrations and thirteen original SVG icons are also reused.

`scripts/prepare-assets.py` can regenerate all copied/optimized assets from the parent repository. It optionally needs Python with Pillow; it is **not** needed to build or run the website. Original app assets remain untouched.

| Website asset | Source in the Flutter repository |
| --- | --- |
| `home.webp` | `docs/screenshots/12-home.png` |
| `timeline.webp` | `docs/screenshots/15-timeline.png` |
| `chat.webp` | `docs/screenshots/14-chat.png` |
| `bucket-list.webp` | `docs/screenshots/19-bucket-list.png` |
| `love-notes.webp` | `docs/screenshots/16-love-notes.png` |
| `time-capsules.webp` | `docs/screenshots/17-time-capsules.png` |
| `capsule-sealed.webp` | `docs/screenshots/25-capsule-sealed.png` |
| Mood illustrations | `assets/moods/{loved,calm,need_a_hug}.png` |
| Line icons | `assets/icons/` (same names) |

Supported features and pairing instructions were checked against `README.md`, `PRODUCT.md`, screens, and service code. Privacy text describes account/couple access, database row-level security, private photo storage, and time-based capsule access. It does not claim end-to-end encryption, certified security, or guaranteed confidentiality. Therabot is described as AI-guided reflection, with the AI processing and professional-counselling limitation stated.

Some source documentation disagrees about whether the private realtime-channel migration has reached production. The page deliberately makes no claim that all live realtime channels are private. The linked security notes document current limitations. No database security checks were rerun and no backend configuration was changed for this task.

## Working destinations

- Explore USpace: the interactive gallery on this page.
- Get Started: the closing section, then **Open USpace**.
- Open USpace / Try the web app: the existing `https://h1enz.github.io/USpace/` demo, opened in a new tab.
- Privacy: the page's privacy section; detailed security notes link to the real repository document.
- View project: `https://github.com/H1enZ/USpace`.

There is no fake download, waitlist, contact form, testimonial, or usage count. App access still depends on the existing deployment and Supabase service. Screenshot previews are illustrative rather than clickable app sessions. The page has no analytics, cookies, signup processing, or persistent user data.

## Tests and presentation review

`tests/landing.spec.js` tests the **production build**, including assets, errors, internal destinations, six preview states, keyboard tab switching, feature-to-preview links, all FAQ accordions, mobile navigation, reduced motion, 200% text, no-JavaScript behavior, and axe WCAG A/AA scans at 320, 390, 768, and 1440 pixels. Automated accessibility checks are not a substitute for a human assistive-technology review.

Tests save local full-page screenshots under ignored `qa/`. Tests and build results are summarized in `VALIDATION.md` after verification.

Before eventual publishing, decide the website's public URL and add an absolute canonical URL if appropriate. A social-sharing image can be added separately. No replacement assets or backend integration are required to run this completed landing page.
