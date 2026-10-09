// Scroll follows the reader; it never takes over native scrolling.
const motionPreference = window.matchMedia('(prefers-reduced-motion: reduce)');
const finePointer = window.matchMedia('(hover: hover) and (pointer: fine)');
const root = document.documentElement;
const header = document.querySelector('.site-header');
const hero = document.querySelector('.hero');
const story = document.querySelector('.story-section');
const stages = [...document.querySelectorAll('.feature-card, .preview-stage, .story-section, .final-cta')];
const links = [...document.querySelectorAll('#main-nav a[href^="#"]')];
const sections = links.map((link) => document.querySelector(link.hash));
const clamp = (value) => Math.max(0, Math.min(1, value));
let scheduled = false;

function paint() {
  scheduled = false;
  const height = window.innerHeight;
  const range = root.scrollHeight - height;
  root.style.setProperty('--reading-progress', range > 0 ? clamp(window.scrollY / range) : 0);
  header.classList.toggle('has-scrolled', window.scrollY > 24);
  let active = 0;
  sections.forEach((section, index) => {
    if (section && section.getBoundingClientRect().top <= height * .4) active = index;
  });
  links.forEach((link, index) => {
    if (index === active) link.setAttribute('aria-current', 'location');
    else link.removeAttribute('aria-current');
  });
  if (motionPreference.matches) return;
  const heroProgress = clamp(-hero.getBoundingClientRect().top / hero.offsetHeight);
  hero.style.setProperty('--hero-drift', `${heroProgress * 100}px`);
  hero.style.setProperty('--hero-turn', `${heroProgress * -8}deg`);
  stages.forEach((stage) => {
    const rect = stage.getBoundingClientRect();
    if (rect.bottom < 0 || rect.top > height) return;
    const progress = clamp((height - rect.top) / (height + rect.height));
    stage.style.setProperty('--art-drift', `${(progress - .5) * -50}px`);
    if (stage === story) {
      stage.style.setProperty('--ring-shift', `${progress * 42}px`);
      stage.style.setProperty('--story-turn', `${(progress - .5) * 16}deg`);
    }
  });
}

function schedule() {
  if (!scheduled) { scheduled = true; requestAnimationFrame(paint); }
}
window.addEventListener('scroll', schedule, { passive: true });
window.addEventListener('resize', schedule);
motionPreference.addEventListener('change', schedule);
window.addEventListener('load', schedule);
paint();

document.querySelectorAll('.feature-card, .preview-stage').forEach((card) => {
  card.addEventListener('pointermove', (event) => {
    if (motionPreference.matches || !finePointer.matches) return;
    const rect = card.getBoundingClientRect();
    card.style.setProperty('--glow-x', `${event.clientX - rect.left}px`);
    card.style.setProperty('--glow-y', `${event.clientY - rect.top}px`);
  });
});
