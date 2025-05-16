// frontend/public/js/features/licenses/myLicensesHandler.js

// Hilfsfunktion, um den Text des Collapse-Toggle-Buttons zu ändern
function toggleButtonText(button, targetCollapseElement) {
  const showTextElement = button.querySelector('.show-text');
  const hideTextElement = button.querySelector('.hide-text');

  if (!showTextElement || !hideTextElement) return;

  if (targetCollapseElement.classList.contains('show')) { // oder 'collapsing' während der Transition zum Öffnen
    showTextElement.classList.add('d-none');
    hideTextElement.classList.remove('d-none');
  } else {
    showTextElement.classList.remove('d-none');
    hideTextElement.classList.add('d-none');
  }
}

// Funktion für die Bestätigung der Lizenzrückgabe
function confirmLicenseReturn(productName) {
  return confirm(`Are you sure you want to return the license for '${productName}'?`);
}

// Initialisierungsfunktion, die Event-Listener bindet
export function initMyLicensesPage() {
  // Event-Listener für Bootstrap Collapse-Events zum Ändern des Button-Textes
  document.querySelectorAll('[data-bs-toggle="collapse"]').forEach(button => {
    const targetId = button.getAttribute('data-bs-target');
    // Stelle sicher, dass wir nur Buttons auf der "My Licenses"-Seite ansprechen
    if (targetId && targetId.startsWith('#collapseMyLicense')) {
      const targetCollapseElement = document.querySelector(targetId);
      if (targetCollapseElement) {
        // Event-Listener für das Anzeigen des Collapse-Elements
        targetCollapseElement.addEventListener('show.bs.collapse', function() {
          toggleButtonText(button, targetCollapseElement);
        });
        // Event-Listener für das Verstecken des Collapse-Elements
        targetCollapseElement.addEventListener('hide.bs.collapse', function() {
          toggleButtonText(button, targetCollapseElement);
        });

        // Initialen Text setzen, falls Elemente beim Laden schon offen sind (unwahrscheinlich für .collapse)
        // toggleButtonText(button, targetCollapseElement); // Kann man machen, ist aber bei .collapse meist nicht nötig
      }
    }
  });

  // Mache confirmReturn global verfügbar oder binde es spezifischer,
  // falls es nur von onsubmit-Attributen auf dieser Seite verwendet wird.
  // Für onsubmit ist es am einfachsten, wenn es global ist.
  window.confirmReturn = confirmLicenseReturn;
}

