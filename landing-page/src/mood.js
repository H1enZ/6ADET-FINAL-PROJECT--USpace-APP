const moods = {
  loved: { title: 'Feeling loved.', message: 'A little closer, just by being you.', label: 'Loved' },
  calm: { title: 'A softer kind of day.', message: 'Take a breath. There’s no rush here.', label: 'Calm' },
  need_a_hug: { title: 'A hug would be nice.', message: 'You don’t need all the words to be understood.', label: 'Need a hug' },
};
const source = document.querySelector('.mood-demo');
document.querySelectorAll('[data-mood-mount]').forEach((mount) => {
  mount.append(source.cloneNode(true));
});
const gallery = source.cloneNode(true);
gallery.classList.add('gallery-mood-demo');
gallery.hidden = true;
document.querySelector('.preview-phone').append(gallery);

const widgets = [...document.querySelectorAll('[data-mood-demo]')];
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
let animations = [];
let current = 'loved';

function stopAnimations() {
  animations.forEach((animation) => animation.cancel());
  animations = [];
}

widgets.forEach((widget) => {
  widget.addEventListener('click', (event) => {
    const button = event.target.closest('[data-mood]');
    if (!button || button.dataset.mood === current) return;
    current = button.dataset.mood;
    const mood = moods[current];
    stopAnimations();
    widgets.forEach((demo) => {
      demo.dataset.feeling = current;
      demo.querySelector('.demo-mood-title').textContent = mood.title;
      demo.querySelector('.demo-mood-message').textContent = mood.message;
      const artwork = demo.querySelector('.demo-mood-image');
      artwork.src = `${import.meta.env.BASE_URL}assets/moods/${current}.webp`;
      demo.querySelectorAll('[data-mood]').forEach((choice) => {
        choice.setAttribute('aria-pressed', String(choice.dataset.mood === current));
      });
      if (!reducedMotion.matches && demo.getBoundingClientRect().height > 0) {
        animations.push(artwork.animate([
          { transform: 'scale(.65) rotate(-12deg)', opacity: .3 },
          { transform: 'scale(1.1) rotate(5deg)', opacity: 1, offset: .65 },
          { transform: 'scale(1) rotate(0deg)', opacity: 1 },
        ], { duration: 620, easing: 'cubic-bezier(.2,.8,.2,1)' }));
        demo.querySelectorAll('.mood-spark').forEach((spark, index) => {
          animations.push(spark.animate([
            { transform: 'translateY(8px) scale(.5)', opacity: 0 },
            { transform: `translateY(-${18 + index * 9}px) scale(1.4)`, opacity: 1, offset: .5 },
            { transform: 'translateY(0) scale(1)', opacity: .7 },
          ], { duration: 800, easing: 'ease-out' }));
        });
      }
    });
    document.querySelector('#mood-announcement').textContent = `Demo mood set to ${mood.label}. ${mood.message} Nothing is saved or sent.`;
  });
});
reducedMotion.addEventListener('change', () => { if (reducedMotion.matches) stopAnimations(); });

export function showMoodPreview(visible) {
  gallery.hidden = !visible;
  document.querySelector('#preview-image').hidden = visible;
  document.querySelector('.preview-phone').classList.toggle('shows-mood-demo', visible);
  document.querySelector('.preview-device figcaption').textContent = visible
    ? 'Interactive mood demo · Nothing is saved or sent'
    : 'Actual app screenshot · Fictional sample data';
}
