const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
const elements = [...document.querySelectorAll('.reveal, .more-features article, .privacy-points article, .faq-list details, .final-cta > :not(.cta-orbit), .preview-device')];
let observer;
function configure() {
  observer?.disconnect();
  if (reduced.matches || !('IntersectionObserver' in window)) {
    elements.forEach((element) => element.classList.add('is-visible'));
    return;
  }
  observer = new IntersectionObserver((entries) => {
    entries.forEach(({ target, isIntersecting, boundingClientRect }) => {
      if (isIntersecting || target.contains(document.activeElement)) target.classList.add('is-visible');
      // Reset only after leaving the viewport completely, avoiding threshold flicker.
      else if (boundingClientRect.bottom < -40 || boundingClientRect.top > window.innerHeight + 40) target.classList.remove('is-visible');
    });
  }, { rootMargin: '40px 0px', threshold: 0 });
  elements.forEach((element, index) => {
    element.style.setProperty('--reveal-delay', `${index % 3 * 75}ms`);
    element.dataset.revealDirection = element.classList.contains('feature-card') ? (index % 2 ? 'right' : 'left') : 'up';
    element.classList.add('reveal-ready');
    observer.observe(element);
  });
}
document.addEventListener('focusin', (event) => {
  elements.filter((element) => element.contains(event.target)).forEach((element) => element.classList.add('is-visible'));
});
reduced.addEventListener('change', configure);
configure();
