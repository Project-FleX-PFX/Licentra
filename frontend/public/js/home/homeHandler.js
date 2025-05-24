// public/js/features/homeHandler.js

export function initHomeHandler() {
  document.querySelectorAll('.home-nav-card').forEach(card => {
    card.addEventListener('click', () => {
      const target = card.getAttribute('data-target');
      if (target) {
        window.location.href = target;
      }
    });
    // Optional: Button inside Card klickbar machen
    const btn = card.querySelector('button');
    if (btn) {
      btn.addEventListener('click', e => {
        e.stopPropagation();
        window.location.href = card.getAttribute('data-target');
      });
    }
  });
}
