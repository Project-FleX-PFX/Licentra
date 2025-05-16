// frontend/public/js/features/licenses/availableLicensesHandler.js

// Hält die Instanz des Modals, um sie wiederverwenden zu können
let activatePopupModalInstance = null;

function showActivateLicensePopup(assignmentId, productName) {
  const productNameElement = document.getElementById("popupActivateProductName");
  if (productNameElement) {
    productNameElement.textContent = productName;
  }

  const activateForm = document.getElementById("activateForm");
  if (activateForm) {
    activateForm.action = `/licenses/${assignmentId}/activate`;
  }

  const modalElement = document.getElementById('activateLicensePopup');
  if (modalElement) {
    // Erstelle die Modal-Instanz nur einmal oder hole die bestehende
    if (!activatePopupModalInstance) {
      activatePopupModalInstance = new bootstrap.Modal(modalElement);
    }
    activatePopupModalInstance.show();
  }
}

function hideActivateLicensePopup() {
  // Wenn das Modal über data-bs-dismiss geschlossen wird, brauchen wir hier nichts zu tun.
  // Diese Funktion ist nützlich, wenn man das Schließen programmatisch auslösen muss
  // oder die onclick-Handler auf den Buttons beibehalten möchte.
  const modalElement = document.getElementById('activateLicensePopup');
  if (modalElement && activatePopupModalInstance) { // activatePopupModalInstance wird oben gesetzt
    activatePopupModalInstance.hide();
  } else if (modalElement) { // Fallback, falls Instanz nicht gespeichert wurde
    const modal = bootstrap.Modal.getInstance(modalElement);
    if (modal) {
        modal.hide();
    }
  }
}

// Initialisierungsfunktion (bindet Funktionen an globale Objekte oder setzt Event-Listener)
export function initAvailableLicensesPage() {
  // Mache die show-Funktion global verfügbar, da sie von onclick-Attributen im HTML aufgerufen wird.
  // Alternativ: Event-Listener auf die Buttons setzen und Parameter über data-Attribute übergeben.
  window.showActivatePopup = showActivateLicensePopup;
  
  // Die hide-Funktion ist optional global, wenn sie auch per onclick verwendet wird.
  // Für data-bs-dismiss="modal" ist sie nicht zwingend global nötig.
  window.hideActivatePopup = hideActivateLicensePopup; 
}

