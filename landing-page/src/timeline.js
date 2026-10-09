const board = document.createElement('section');
board.className = 'timeline-demo';
board.setAttribute('aria-label', 'Editable Timeline demo');
board.innerHTML = `
  <div class="timeline-toolbar"><div><p class="eyebrow">Your shared scrapbook</p><h3>Our little moments.</h3></div><button class="button timeline-add" type="button">+ Add memory</button></div>
  <p class="timeline-hint">A coffee date. A new adventure. Start with a moment worth keeping.</p>
  <div class="memory-board"></div>
  <div class="timeline-demo-footer"><p>Demo edits last until you refresh. Nothing is sent to an account.</p><button class="timeline-reset" type="button">Reset demo</button></div>
  <p class="sr-only timeline-status" role="status"></p>`;
document.querySelector('#preview-panel').append(board);
const dialog = document.createElement('dialog');
dialog.className = 'memory-dialog';
dialog.setAttribute('aria-labelledby', 'memory-dialog-title');
dialog.innerHTML = `
  <form class="memory-form">
    <div class="memory-form-heading"><div><p class="eyebrow">A moment for the scrapbook</p><h2 id="memory-dialog-title">Add a memory</h2></div><button type="button" class="memory-cancel icon-close" aria-label="Close memory editor">×</button></div>
    <label for="memory-title">Give it a title</label><input id="memory-title" name="title" maxlength="60" required placeholder="Our first coffee date" />
    <label for="memory-date">When was it?</label><input id="memory-date" name="date" type="date" required />
    <label for="memory-note">The little details <span>(optional)</span></label><textarea id="memory-note" name="note" rows="3" maxlength="220" placeholder="What made this moment yours?"></textarea>
    <label for="memory-cover">Choose an illustration</label><select id="memory-cover" name="cover"><option value="sunrise">A golden sunrise</option><option value="meadow">A quiet meadow</option><option value="night">Under the stars</option></select>
    <p class="memory-form-note">This is a demo. Your edits disappear when the page refreshes.</p>
    <div class="memory-form-actions"><button class="memory-cancel button button-outline" type="button">Cancel</button><button class="button" type="submit">Save memory</button></div>
  </form>`;
document.body.append(dialog);
const form = dialog.querySelector('form');
const grid = board.querySelector('.memory-board');
const add = board.querySelector('.timeline-add');
const defaults = [
  { id: 1, title: 'Our slow Sunday', date: '2026-09-06', note: 'Coffee, a long walk, and nowhere else to be.', cover: 'meadow' },
  { id: 2, title: 'Just one more sunset', date: '2026-09-19', note: 'We stayed until the sky turned pink.', cover: 'sunrise' },
  { id: 3, title: 'Under the same stars', date: '2026-10-02', note: 'Different places. The same little universe.', cover: 'night' },
];
let memories = structuredClone(defaults);
let nextId = 4;
let editing = null;
let returnFocus = add;
const reduced = window.matchMedia('(prefers-reduced-motion: reduce)');
let cardAnimation;
function announce(message) { board.querySelector('.timeline-status').textContent = message; }
function render(changedId) {
  grid.replaceChildren();
  memories.forEach((memory) => {
    const card = document.createElement('article');
    card.className = 'memory-card';
    card.dataset.id = memory.id;
    // Only fixed markup enters innerHTML; visitor text uses textContent below.
    card.innerHTML = '<div class="memory-cover" aria-hidden="true"><span></span></div><div class="memory-copy"><time></time><h4></h4><p></p><div class="memory-actions"><button type="button" data-action="edit">Edit</button><button type="button" data-action="remove">Remove</button></div></div>';
    card.querySelector('.memory-cover').classList.add(`cover-${memory.cover}`);
    const date = card.querySelector('time');
    date.dateTime = memory.date;
    date.textContent = new Intl.DateTimeFormat('en', { month: 'short', day: 'numeric', year: 'numeric' }).format(new Date(`${memory.date}T12:00:00`));
    card.querySelector('h4').textContent = memory.title;
    card.querySelector('.memory-copy > p').textContent = memory.note;
    card.querySelector('[data-action="edit"]').setAttribute('aria-label', `Edit ${memory.title}`);
    card.querySelector('[data-action="remove"]').setAttribute('aria-label', `Remove ${memory.title}`);
    grid.append(card);
    if (memory.id === changedId && !reduced.matches) {
      cardAnimation?.cancel();
      cardAnimation = card.animate([{ opacity: .2, transform: 'translateY(24px) rotate(-5deg) scale(.9)' }, { opacity: 1, transform: 'translateY(0) rotate(0) scale(1)' }], { duration: 550, easing: 'cubic-bezier(.2,.8,.2,1)' });
    }
  });
  if (!memories.length) {
    const empty = document.createElement('p');
    empty.className = 'memory-empty';
    empty.textContent = 'Your next chapter starts here. Add your first memory.';
    grid.append(empty);
  }
  add.disabled = memories.length >= 8;
  add.textContent = add.disabled ? '8 memories added' : '+ Add memory';
}
function openEditor(memory, trigger) {
  editing = memory?.id ?? null;
  returnFocus = trigger;
  form.reset();
  dialog.querySelector('h2').textContent = memory ? 'Edit your memory' : 'Add a memory';
  form.elements.title.value = memory?.title ?? '';
  const today = new Date();
  const localDate = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-${String(today.getDate()).padStart(2, '0')}`;
  form.elements.date.value = memory?.date ?? localDate;
  form.elements.note.value = memory?.note ?? '';
  form.elements.cover.value = memory?.cover ?? 'sunrise';
  dialog.showModal();
  form.elements.title.focus();
}
add.addEventListener('click', () => openEditor(null, add));
grid.addEventListener('click', (event) => {
  const button = event.target.closest('[data-action]');
  if (!button) return;
  const id = Number(button.closest('.memory-card').dataset.id);
  if (button.dataset.action === 'edit') openEditor(memories.find((memory) => memory.id === id), button);
  else {
    memories = memories.filter((memory) => memory.id !== id);
    render();
    add.focus();
    announce('Memory removed from the demo.');
  }
});
form.addEventListener('submit', (event) => {
  event.preventDefault();
  const title = form.elements.title.value.trim();
  if (!title) { form.elements.title.value = ''; form.elements.title.reportValidity(); return; }
  const memory = { id: editing ?? nextId++, title, date: form.elements.date.value, note: form.elements.note.value.trim(), cover: form.elements.cover.value };
  if (editing !== null) memories = memories.map((item) => item.id === editing ? memory : item);
  else if (memories.length < 8) memories.push(memory);
  render(memory.id);
  returnFocus = grid.querySelector(`[data-id="${memory.id}"] [data-action="edit"]`);
  dialog.close();
  announce(`“${title}” saved to the demo Timeline. It will reset on refresh.`);
});
dialog.querySelectorAll('.memory-cancel').forEach((button) => button.addEventListener('click', () => dialog.close()));
dialog.addEventListener('close', () => { if (returnFocus?.isConnected) returnFocus.focus(); });
board.querySelector('.timeline-reset').addEventListener('click', () => { memories = structuredClone(defaults); render(); announce('Demo Timeline reset to its sample memories.'); });
reduced.addEventListener('change', () => { if (reduced.matches) cardAnimation?.cancel(); });
render();
export function showTimelinePreview(visible) {
  board.hidden = !visible;
  document.querySelector('.preview-device').hidden = visible;
  document.querySelector('#preview-panel').classList.toggle('shows-timeline', visible);
}
showTimelinePreview(true);
