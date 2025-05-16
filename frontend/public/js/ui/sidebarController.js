// /js/ui/sidebarController.js
export function initSidebar(options = {}) {
  const config = {
    sidebarId: 'sidebar',
    toggleButtonId: 'sidebarToggleBtn',
    openClass: 'open', // Klasse für den mobilen offenen Zustand
    mobileBreakpoint: 768,
    ...options
  };

  const sidebar = document.getElementById(config.sidebarId);
  const toggleButton = document.getElementById(config.toggleButtonId);

  if (!sidebar || !toggleButton) {
    console.warn('Sidebar or Toggle Button not found. Sidebar functionality may be impaired.');
    return { // Fallback-Objekt
      toggle: () => {}, open: () => {}, close: () => {}, isOpen: () => false 
    };
  }

  // Funktion, die nur auf mobilen Geräten das Togglen erlaubt
  function toggleSidebarOnMobile() {
    if (window.innerWidth < config.mobileBreakpoint) {
      sidebar.classList.toggle(config.openClass);
    }
    // Auf Desktop tut der Klick nichts, da der Button via CSS unsichtbar sein sollte
    // und die Sidebar immer offen ist.
  }

  // Stellt den korrekten Sidebar-Zustand beim Laden und bei Größenänderung sicher
  function handleResizeAndInitialLoad() {
    const isMobile = window.innerWidth < config.mobileBreakpoint;

    if (isMobile) {
      // Auf Mobil: Button ist sichtbar (gesteuert durch CSS).
      // Die Sidebar ist standardmäßig geschlossen (CSS: left: -250px).
      // Die .open-Klasse wird nur durch User-Interaktion (Button, Klick außerhalb) gesetzt/entfernt.
      // Wenn das Fenster von Desktop zu Mobil verkleinert wird und die Sidebar
      // keine .open Klasse hat (Desktop-Standard), bleibt sie auf Mobil geschlossen.
    } else {
      // Auf Desktop:
      // 1. Sidebar ist immer offen (CSS: left: 0).
      // 2. Die .open Klasse von der Sidebar entfernen, da sie hier keine Funktion hat
      //    und auf Desktop ein unerwünschtes "Schließen" (gemäß globaler CSS-Regel) bewirken könnte.
      sidebar.classList.remove(config.openClass);
      // 3. Button ist unsichtbar (gesteuert durch CSS).
    }
  }

  // Event-Listener
  toggleButton.addEventListener('click', toggleSidebarOnMobile);

  document.addEventListener('click', function(event) {
    const target = event.target;
    // "Klick außerhalb" nur auf Mobilgeräten und wenn Sidebar offen ist
    if (window.innerWidth < config.mobileBreakpoint &&
        sidebar.classList.contains(config.openClass) &&
        !sidebar.contains(target) &&
        target !== toggleButton &&
        !toggleButton.contains(target)) {
      sidebar.classList.remove(config.openClass);
    }
  });

  window.addEventListener('resize', handleResizeAndInitialLoad);

  // Initialen Zustand beim Laden der Seite setzen
  handleResizeAndInitialLoad();

  // Öffentliche Methoden für den Fall, dass sie extern benötigt werden (primär für Mobil relevant)
  return {
    toggle: () => { // toggle nur, wenn mobil
        if (window.innerWidth < config.mobileBreakpoint) {
            sidebar.classList.toggle(config.openClass);
        }
    },
    open: () => { // open nur, wenn mobil
        if (window.innerWidth < config.mobileBreakpoint) {
            sidebar.classList.add(config.openClass);
        }
    },
    close: () => { // close nur, wenn mobil
        if (window.innerWidth < config.mobileBreakpoint) {
            sidebar.classList.remove(config.openClass);
        }
    },
    isOpen: () => sidebar.classList.contains(config.openClass) && window.innerWidth < config.mobileBreakpoint
  };
}

