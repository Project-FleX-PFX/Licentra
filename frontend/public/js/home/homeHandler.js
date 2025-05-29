// public/js/features/homeHandler.js

export function initHomeHandler() {
  // Bestehende Navigation Cards (My Profile, All Licenses, etc.)
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
        e.stopPropagation(); // Verhindert Event-Bubbling zur Karte
        window.location.href = card.getAttribute('data-target');
      });
    }
  });

  // Neue Funktionalität: License Cards (Your Active Licenses Bereich)
  document.querySelectorAll('.license-card').forEach(card => {
    card.addEventListener('click', () => {
      const target = card.getAttribute('data-target');
      if (target) {
        window.location.href = target;
      }
    });

    // Falls Badges oder andere klickbare Elemente in der Lizenzkarte sind,
    // verhindere Event-Bubbling (basierend auf den Suchergebnissen)
    const badges = card.querySelectorAll('.badge');
    badges.forEach(badge => {
      badge.addEventListener('click', e => {
        e.stopPropagation(); // Verhindert Klick auf die Karte selbst
        // Hier könnte spezifische Badge-Logik stehen, falls gewünscht
      });
    });
  });
}

