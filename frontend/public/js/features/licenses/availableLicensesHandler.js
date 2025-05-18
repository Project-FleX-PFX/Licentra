// frontend/public/js/features/licenses/availableLicensesHandler.js

// Modal instance for reuse
let activatePopupModalInstance = null;

/**
 * Shows the license activation confirmation modal
 * @param {string} assignmentId - ID of the license assignment to activate
 * @param {string} productName - Name of the product to display in the modal
 */
function showActivateLicensePopup(assignmentId, productName) {
  const productNameElement = document.getElementById('popupActivateProductName');
  if (productNameElement) {
    productNameElement.textContent = productName;
  }

  const activateForm = document.getElementById('activateForm');
  if (activateForm) {
    activateForm.action = `/licenses/${assignmentId}/activate`;
  }

  const modalElement = document.getElementById('activateLicensePopup');
  if (modalElement) {
    // Create modal instance only once or reuse existing one
    if (!activatePopupModalInstance) {
      activatePopupModalInstance = new bootstrap.Modal(modalElement);
    }
    activatePopupModalInstance.show();
  }
}

/**
 * Hides the license activation modal
 * This function is useful for programmatic closing or when keeping onclick handlers
 */
function hideActivateLicensePopup() {
  const modalElement = document.getElementById('activateLicensePopup');
  if (modalElement && activatePopupModalInstance) {
    activatePopupModalInstance.hide();
  } else if (modalElement) {
    // Fallback if instance wasn't stored
    const modal = bootstrap.Modal.getInstance(modalElement);
    if (modal) {
      modal.hide();
    }
  }
}

/**
 * Initializes the available licenses page
 * Makes functions globally available for inline onclick handlers
 */
export function initAvailableLicensesPage() {
  // Make functions globally available for onclick attributes in HTML
  // Alternative: Add event listeners to buttons and pass parameters via data attributes
  window.showActivatePopup = showActivateLicensePopup;
  window.hideActivatePopup = hideActivateLicensePopup;
}

