import './motion.js';
import { showMoodPreview } from './mood.js';
import { showTimelinePreview } from './timeline.js';
import { showCapsulePreview } from './capsule.js';
import './reveals.js';
import './entrance.js';

const root = document.documentElement;
root.classList.add('js');
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
const menu = document.querySelector('#main-nav');
const toggle = document.querySelector('.menu-toggle');

function closeMenu({ restoreFocus = false } = {}) {
  toggle.setAttribute('aria-expanded', 'false');
  toggle.setAttribute('aria-label', 'Open navigation');
  menu.classList.remove('is-open');
  if (restoreFocus) toggle.focus();
}

toggle.addEventListener('click', () => {
  const open = toggle.getAttribute('aria-expanded') !== 'true';
  toggle.setAttribute('aria-expanded', String(open));
  toggle.setAttribute('aria-label', open ? 'Close navigation' : 'Open navigation');
  menu.classList.toggle('is-open', open);
});
menu.addEventListener('click', (event) => {
  if (event.target.closest('a')) closeMenu();
});
document.addEventListener('keydown', (event) => {
  if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
    closeMenu({ restoreFocus: true });
  }
});
document.addEventListener('click', (event) => {
  if (!event.target.closest('.nav-wrap')) closeMenu();
});
document.addEventListener('focusin', (event) => {
  if (!event.target.closest('.nav-wrap')) closeMenu();
});
window.matchMedia('(min-width: 801px)').addEventListener('change', () => closeMenu());

const screens = {
  timeline: {
    image: 'timeline', kicker: 'Your shared scrapbook', title: 'Because “remember when” deserves a home.',
    description: 'The first coffee. The spontaneous trip. An ordinary Tuesday that felt like everything. Keep the photos and the story, together.',
    points: ['Save photos, stories, locations, and tags', 'Arrange a corkboard that feels like yours', 'Revisit your favourite moments together'],
    alt: 'USpace Timeline showing illustrated sample memories on a corkboard',
  },
  home: {
    image: 'home', kicker: 'A little closer, every day', title: 'Let them in on how you’re feeling.',
    description: 'Some days you’re on top of the world. Some days you need a hug. A little check-in helps your partner meet you where you are.',
    points: ['Share your mood with your partner', 'See a shared state when your moods match', 'Keep special-day countdowns close'],
    alt: 'USpace Home with a special-day countdown and matching Loved together moods',
  },
  chat: {
    image: 'chat', kicker: 'Your everyday connection', title: 'From “good morning” to “still awake?”',
    description: 'A conversation that’s just between you and your partner. Share the updates, photos, and tiny thoughts that make up your day.',
    points: ['Message your partner in real time', 'Share photos and react to messages', 'Keep your conversation in your couple’s space'],
    alt: 'USpace Chat showing fictional messages between two paired tester accounts',
  },
  bucket: {
    image: 'bucket-list', kicker: 'For all your somedays', title: 'Make plans for your kind of adventure.',
    description: 'A weekend away. A new café. Something you’ve always wanted to try. Collect your ideas and take little steps toward them.',
    points: ['Create a shared list of things to do', 'Add a place, budget, and savings contributions', 'Mark the moments you’ve made happen'],
    alt: 'USpace Bucket List with a sample weekend getaway goal',
  },
  notes: {
    image: 'love-notes', kicker: 'Something worth rereading', title: 'A small note. A lasting feeling.',
    description: 'For the words that deserve more than a passing message. Write a letter, tuck in a photo, and leave your partner something to keep.',
    points: ['Write Love Notes for your partner', 'Include a photo with your letter', 'Favourite the notes you want to return to'],
    alt: 'A sample Love Note with a photo in the real USpace interface',
  },
  capsules: {
    image: 'time-capsules', kicker: 'A little love, saved for later', title: 'Today’s words. Tomorrow’s butterflies.',
    description: 'Write to a future version of you two. Seal a memory, a wish, or a little promise until the date you choose.',
    points: ['Seal notes and photos for a chosen date', 'Content stays hidden until its unlock time', 'Open your capsule with a wax-seal ceremony'],
    alt: 'USpace Time Capsules screen with a sealed sample capsule and its countdown',
  },
};

const tabs = [...document.querySelectorAll('[role="tab"]')];
const panel = document.querySelector('#preview-panel');
const previewImage = document.querySelector('#preview-image');
let activeScreen = 'timeline';
let previewAnimation;

function selectScreen(key, focus = false) {
  const screen = screens[key];
  if (!screen) return;
  tabs.forEach((tab) => {
    const selected = tab.dataset.screen === key;
    tab.setAttribute('aria-selected', String(selected));
    tab.tabIndex = selected ? 0 : -1;
    if (selected && focus) tab.focus();
  });
  panel.setAttribute('aria-labelledby', `tab-${key}`);
  if (activeScreen === key) return;
  activeScreen = key;
  showMoodPreview(key === 'home');
  showTimelinePreview(key === 'timeline');
  showCapsulePreview(key === 'capsules');
  document.querySelector('#preview-kicker').textContent = screen.kicker;
  document.querySelector('#preview-title').textContent = screen.title;
  document.querySelector('#preview-description').textContent = screen.description;
  document.querySelector('#preview-points').replaceChildren(...screen.points.map((point) => {
    const li = document.createElement('li');
    li.textContent = point;
    return li;
  }));
  if (!['home', 'timeline', 'capsules'].includes(key)) previewImage.src = `${import.meta.env.BASE_URL}assets/screens/${screen.image}.webp`;
  previewImage.alt = screen.alt;
  document.querySelector('#preview-number').textContent = String(Object.keys(screens).indexOf(key) + 1).padStart(2, '0');
  previewAnimation?.cancel();
  if (!reducedMotion.matches) {
    previewAnimation = document.querySelector('.preview-phone').animate([
      { opacity: 0.3, transform: 'translateY(8px)' },
      { opacity: 1, transform: 'translateY(0)' },
    ], { duration: 320, easing: 'ease-out' });
  }
}

tabs.forEach((tab, index) => {
  tab.addEventListener('click', () => selectScreen(tab.dataset.screen));
  tab.addEventListener('keydown', (event) => {
    const next = { ArrowRight: (index + 1) % tabs.length, ArrowLeft: (index - 1 + tabs.length) % tabs.length, Home: 0, End: tabs.length - 1 }[event.key];
    if (next !== undefined) {
      event.preventDefault();
      selectScreen(tabs[next].dataset.screen, true);
    }
  });
});

document.querySelectorAll('[data-preview-link]').forEach((link) => {
  link.addEventListener('click', () => selectScreen(link.dataset.previewLink));
});

reducedMotion.addEventListener('change', () => { if (reducedMotion.matches) previewAnimation?.cancel(); });

const capsuleCard = document.querySelector('.capsule-card');
const capsuleIcon = capsuleCard.querySelector('.card-copy > .icon');
const capsuleIconLink = document.createElement('a');
capsuleIconLink.className = 'capsule-icon-link';
capsuleIconLink.href = '#preview';
capsuleIconLink.setAttribute('aria-label', 'Explore the Time Capsule envelope');
capsuleIcon.replaceWith(capsuleIconLink);
capsuleIconLink.append(capsuleIcon);
capsuleIconLink.addEventListener('click', () => selectScreen('capsules'));
capsuleCard.addEventListener('click', (event) => {
  if (!event.target.closest('a, button')) capsuleCard.querySelector('[data-preview-link]').click();
});

// Native details retain keyboard support and work with JavaScript disabled.
document.querySelectorAll('.faq-list details').forEach((details) => {
  details.addEventListener('toggle', () => {
    if (details.open && !reducedMotion.matches) {
      details.querySelector('.faq-answer').animate([
        { opacity: 0, transform: 'translateY(-4px)' },
        { opacity: 1, transform: 'translateY(0)' },
      ], { duration: 220, easing: 'ease-out' });
    }
  });
});
document.querySelector('#year').textContent = String(new Date().getFullYear());
