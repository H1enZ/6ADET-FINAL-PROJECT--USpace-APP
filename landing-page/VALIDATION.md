# USpace landing page validation

Verified locally on 9 October 2026, Windows, Node 22.17.1, Chromium 156 through Playwright. Nothing was deployed, committed, or pushed. No production database operations were performed.

## Final results

### Remove extra intro and reading controls ? 9 October 2026

Removed the visible Skip intro button and the extra Tap the letter to read it action. Ready previews now appear automatically after opening; locked previews still show only the locked message/countdown. Lint and production build pass. All four focused intro/capsule browser cases passed, including automatic reveal, repeated closing/resealing, locked content protection, refresh, and first paint. The existing Windows cleanup stall required interrupting the runner after the passing results. Escape remains as an unobtrusive intro fallback.

### Flutter-reference correction and first-paint intro — 9 October 2026

The active Flutter ceremony was inspected before changing the website; see `ANIMATION_REFERENCE.md` for file paths, exact phase mapping, and visual limitations. The former generic envelope has been replaced by a Canvas port of the 6400 ms opening and separate 7000 ms candle/stamp sealing. Close reverses opening as a website-only extension; Flutter has no reverse-close ceremony.

Validation: lint and build pass; all **18 Chromium browser test cases** reported passing. The expanded ceremony regression completed in 48.4 seconds and checks repeated opening/reading/closing, interruption, candle resealing, locked data remaining absent, and reduced motion. New intro tests verify hidden landing content before module execution, blocked module loading with a working inline Skip control, natural four-second completion, refresh, Escape, and no replay on in-page tabs. A standalone Dart harness executes the original frame functions: **202 frames × 19 fields, maximum difference 0** against the JS port. Mobile open-capsule axe scan has no violations; 320px with 200% text has no horizontal overflow. Desktop and mobile website screenshots were visually reviewed.

The Flutter visual-reference harness could not build because the SDK cache lockfile is outside this session's writable directories. No side-by-side Flutter render or pixel-identical claim is made. Canvas texture/antialiasing, folding projection, small wax details, and the unavailable handwriting font remain disclosed differences. The Windows Playwright runner still stalls during cleanup and was interrupted after all test cases passed. No commit, push, authentication change, security-rule change, or real capsule-data access occurred.

### Capsule envelope and storytelling motion — 9 October 2026

Lint and production build pass. All 16 Chromium browser test cases reported passing, including repeated opening/resealing, reversal mid-animation, locked countdown without a protected body, unchanged demo release time after resealing, keyboard activation, card/icon entry points, reduced motion, desktop hero fold placement, and reveals when scrolling down and up. WCAG scans pass at 320, 390, 768, and 1440 pixels; the locked interface is also scanned. Existing mood and Timeline demos, no-JavaScript fallback, mobile navigation, and enlarged text regressions pass. Fixed an existing responsive layer rule that hid the mobile preview tabs, and prevented intro dismissal from moving a button between pointerdown and click.

Visually reviewed desktop hero and sealed/opening/open capsule states, plus sealed/open/locked states on mobile. CSS/JS bundles are 52.12 kB / 24.82 kB (12.44 kB / 8.47 kB gzip). No new runtime library, screenshot replacement, backend connection, commit, or push. The existing Windows Playwright cleanup stall remains; the runner requires interruption after its cases finish. No physical-device or Safari/Firefox verification and no measured 60 FPS claim.

### Entrance and editable Timeline — 9 October 2026

Lint and production build pass. All 14 browser test cases reported passing; the existing Windows cleanup stall still required interrupting the runner after the cases finished.

Added a dismissible, session-once 1.7-second entrance and an editable Timeline scrapbook. Verified desktop board and mobile dialog screenshots. Tests cover add/edit/save/cancel/Escape, focus restoration, literal rendering of visitor text, remove/empty/reset states, mobile dialog accessibility, first-visit dismissal, session repeat suppression, and reduced-motion skipping. A hidden lazy screenshot is now excluded from the initial visible-image loading assertion; visible gallery images are still checked individually. Memory data is temporary; only the entrance-played flag uses session storage. No backend writes or deployment occurred.

### Interactive mood demo — 9 October 2026

Replaced the hero Home screenshot and Moods gallery screenshot with a labeled native HTML demo without test-account names. Added synchronized Loved / Calm / Need a hug controls to the hero, feature card, and gallery, with artwork transitions, spark animations, keyboard support, and live reduced-motion cancellation. No storage or backend calls are made. Desktop and mobile screenshots were reviewed; the decorative floating label was then hidden on small screens to avoid overlapping the controls, and mobile phone parallax disabled to keep the controls steady. Lint/build pass and all 12 browser test cases reported passing before that final mobile CSS adjustment. The test runner still requires interruption during Windows cleanup. The original size and timing table below remains historical.

### Design and motion polish — 9 October 2026

Added scroll-driven phone and illustration movement, staggered entrances, pointer highlights, active-section navigation, a reading-progress line, and decorative story keepsakes. Reviewed desktop hero/story and mobile story screenshots. `npm.cmd run lint` and `npm.cmd run build` pass. All 11 test cases reported passing, including four responsive WCAG scans, menu controls, no-JavaScript rendering, enlarged text, and a new scroll/reduced-motion regression check. The mobile-menu accessibility scan now disables motion before measuring final contrast instead of sampling a fade-in. A final inward ring-position adjustment was built and visually checked afterward. The Windows test runner still stalls during cleanup; no clean process exit is claimed. Existing size and timing figures below describe the original implementation, not this polish pass. The new bundles are 34.78 kB CSS (8.65 kB gzip) and 8.55 kB JS (3.44 kB gzip).

### Continuation check — 9 October 2026

Configured Node globals for `scripts/**/*.mjs` in ESLint, resolving eight undefined-global errors in the local capture tools. `npm.cmd run lint` and `npm.cmd run build` pass. All 10 browser test cases reported passing; the test runner remained in cleanup afterward, so this continuation does not claim a clean test-process exit. On this Windows machine, use `npm.cmd` because PowerShell blocks the `npm.ps1` wrapper.

| Check | Result |
| --- | --- |
| `npm run lint` | Pass, no ESLint errors |
| `npm run build` | Pass; standalone static output in `dist/` |
| `npm test` | All 10 tests passed; final run 13.4 seconds |
| axe WCAG 2 A/AA + 2.1 AA scans | No automated violations at 320, 390, 768, and 1440 px; mobile menu open also checked |
| Browser errors and missing assets | None in the production-page test |
| Landing-page network requests | Only local assets; no Supabase, analytics, or external font requests |
| Horizontal overflow | None at the four tested widths or 390 px with 200% text |
| Enlarged text | Feature-card text stays within its card; Love Notes changes to a stacked layout |
| Reduced motion | No phone animation; smooth scrolling disabled; content stays visible |
| Keyboard interaction | Preview arrows/Home/End, menu Tab/Escape/focus return, all FAQ Enter/Space toggles pass |
| No JavaScript | Content, mobile navigation, real CTAs, and native FAQs remain usable |
| Internal links | All fragment destinations exist |
| External destinations | HTTP 200 for the app, GitHub project, and linked security/privacy notes |
| Exposed credential-pattern scan | No Supabase key or JWT-shaped matches in HTML, source, or public assets |
| Visual review | Desktop hero, feature cards, gallery, story, privacy, closing CTA; phone hero, cards, gallery, story; enlarged-text cards reviewed from actual browser screenshots |

Initial build checks caught incorrect font-package CSS entry points; local font-file references fixed them. Initial layout tests caught decorative-ring overflow and enlarged-text sizing; those were corrected before the final passing run. No unresolved failing tests remain.

## Size and assets

- Entire static build: **499,018 bytes across 32 files**, including all seven screenshots, three mood illustrations, icons, three variable fonts, font licenses, HTML, CSS, and JS.
- Screenshot copies: **238,924 bytes**, down from **2,241,434 bytes** (89% smaller).
- Main JavaScript: 6.61 kB / 2.72 kB gzip.
- Main CSS: 29.52 kB / 7.39 kB gzip.
- HTML: 20.64 kB / 5.74 kB gzip.
- Below-the-fold images lazy-load; image dimensions are reserved; initial hero screenshots receive high fetch priority.

## Created files

Everything created for this task is inside `landing-page/`:

- `index.html` — all sections, semantic structure, metadata, and fallback preview content.
- `src/style.css` — brand tokens, responsive layouts, motion, accessible focus styles, and self-hosted fonts.
- `src/main.js` — mobile navigation, six-screen gallery, keyboard controls, reveal effects, accordion enhancement, and year.
- `public/favicon.svg` — branded favicon.
- `public/assets/screens/` — seven optimized copies of real screenshots.
- `public/assets/moods/` — three optimized copies of existing mood illustrations.
- `public/assets/icons/` — thirteen original USpace line icons.
- `public/licenses/` — Inter and Playfair Display font licenses.
- `scripts/prepare-assets.py` — optional, reproducible image optimization and asset copy script.
- `package.json`, `package-lock.json`, `vite.config.js`, `eslint.config.js`, `playwright.config.js`, `.gitignore` — isolated toolchain configuration.
- `tests/landing.spec.js` — ten production-build browser tests.
- `README.md`, `VALIDATION.md` — local operation, provenance, implementation, and checks.

Ignored local outputs are `node_modules/`, `dist/`, `qa/`, and `test-results/`. Browser review screenshots are retained in `qa/`.

The original Flutter files, existing uncommitted changes, backend code, migrations, and root documentation were left intact.

## Verification limits

- Browser automation used Chromium only. Safari, Firefox, physical devices, and human screen-reader testing were not performed.
- No Lighthouse score is claimed; the size figures above are measured build output, not field performance.
- Flutter tests were not rerun because the isolated landing page does not change or import Flutter source.
- No live sign-up, pairing, messaging, or production database security tests were performed. The existing app's URL and Flutter bootstrap were reachable; app-account functionality remains owned by the existing Flutter deployment.
- This site is not publicly hosted yet. The final canonical URL remains to be set after a hosting destination is approved. No new assets or backend integrations are required to run the landing page.
