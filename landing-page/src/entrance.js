const root = document.documentElement;
const intro = document.querySelector('#welcome-intro');
const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
const duration = Math.max(0, window.USPACE_INTRO_MS ?? 4000);
let animations = [];
let finished = false;
function finish(skipped = false) {
  if (finished) return;
  finished = true;
  animations.forEach((animation) => animation.cancel());
  root.dataset.intro = 'done';
  intro.hidden = true;
  if (intro.contains(document.activeElement)) document.querySelector('.skip-link').focus({ preventScroll: true });
  if (!skipped && !reduced.matches && window.scrollY < 100 && !window.location.hash) {
    animations = [...document.querySelectorAll('.hero-copy > *, .hero-visual')].map((element, index) => element.animate([
      { opacity: 0, transform: 'translateY(20px)' }, { opacity: 1, transform: 'translateY(0)' },
    ], { duration: 1100, delay: index * 130, easing: 'cubic-bezier(.16,1,.3,1)', fill: 'backwards' }));
  }
}
document.addEventListener('uspace:intro-complete', () => finish(true));
reduced.addEventListener('change', () => { if (reduced.matches) { finish(true); animations.forEach((animation) => animation.cancel()); } });
if (root.dataset.intro !== 'active' || reduced.matches) finish(true);
else {
  const animate = (element, frames) => {
    const animation = element.animate(frames, { duration, fill: 'both', easing: 'linear' });
    animations.push(animation);
    return animation;
  };
  intro.querySelectorAll('.welcome-orbits i').forEach((ring, index) => animate(ring, [
    { opacity: 0, transform: `translateX(${index ? 65 : -65}px)` },
    { opacity: 1, transform: `translateX(${index ? -12 : 12}px)`, offset: .45 },
    { opacity: 1, transform: `translateX(${index ? -12 : 12}px)` },
  ]));
  for (const [selector, start, end] of [['.welcome-orbits span', .12, .42], ['.welcome-wordmark', .175, .5], ['.welcome-line', .38, .6]]) {
    animate(intro.querySelector(selector), [
      { opacity: 0, transform: 'translateY(14px)' }, { opacity: 0, transform: 'translateY(14px)', offset: start },
      { opacity: 1, transform: 'translateY(0)', offset: end }, { opacity: 1, transform: 'translateY(0)' },
    ]);
  }
  const exit = animate(intro, [{ opacity: 1 }, { opacity: 1, offset: .8 }, { opacity: 0 }]);
  exit.onfinish = () => finish();
}
