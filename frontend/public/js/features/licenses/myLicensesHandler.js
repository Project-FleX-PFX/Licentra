// frontend/public/js/features/licenses/myLicensesHandler.js
import { convertUTCTimesToLocal, showElement, hideElement, setText } from '../../utils/index.js';

// Bootstrap Modal for license return
let returnLicenseModal = null;

/**
 * Changes the text of the toggle button based on the state of the collapse element
 * @param {HTMLElement} button - The toggle button
 * @param {boolean} isExpanded - Whether the collapse element is open
 */
function toggleButtonText(button, isExpanded) {
  const showTextElement = button.querySelector('.show-text');
  const hideTextElement = button.querySelector('.hide-text');

  if (!showTextElement || !hideTextElement) return;

  if (isExpanded) {
    showTextElement.classList.add('d-none');
    hideTextElement.classList.remove('d-none');
  } else {
    showTextElement.classList.remove('d-none');
    hideTextElement.classList.add('d-none');
  }
}

/**
 * Shows the modal to confirm license return
 * @param {string} assignmentId - ID of the license assignment
 * @param {string} productName - Name of the product/license
 */
function showReturnLicenseModal(assignmentId, productName) {
  const form = document.getElementById('returnLicenseForm');
  const productNameElement = document.getElementById('returnLicenseProductName');
  
  if (form) form.action = `/my-licenses/${assignmentId}/return`;
  if (productNameElement) productNameElement.textContent = productName;
  
  if (returnLicenseModal) returnLicenseModal.show();
}

/**
 * Initializes the collapse functionality for license cards
 */
function initCollapseButtons() {
  document.querySelectorAll('.collapse').forEach(collapseElement => {
    const cardHeader = collapseElement.closest('.card').querySelector('.card-header');
    const toggleButton = cardHeader.querySelector('.toggle-details');
    
    if (!toggleButton) return;
    
    // Set initial state
    toggleButtonText(toggleButton, collapseElement.classList.contains('show'));
    
    // Event listeners for collapse events
    collapseElement.addEventListener('show.bs.collapse', () => toggleButtonText(toggleButton, true));
    collapseElement.addEventListener('hide.bs.collapse', () => toggleButtonText(toggleButton, false));
  });
}

/**
 * Makes license cards clickable (except on buttons/links)
 */
function makeCardsClickable() {
  document.querySelectorAll('.license-card').forEach(card => {
    card.addEventListener('click', function(event) {
      // Only trigger if not clicked on a button or link
      if (!event.target.closest('button') && !event.target.closest('a') && !event.target.closest('form')) {
        const targetId = this.getAttribute('data-bs-target');
        if (!targetId) return;
        
        const collapseElement = document.querySelector(targetId);
        if (!collapseElement) return;
        
        const bsCollapse = bootstrap.Collapse.getInstance(collapseElement) || 
                           new bootstrap.Collapse(collapseElement, { toggle: false });
        
        // Manually trigger toggle
        collapseElement.classList.contains('show') ? bsCollapse.hide() : bsCollapse.show();
      }
    });
  });
}

/**
 * Initializes the return license buttons
 */
function initReturnButtons() {
  document.querySelectorAll('.return-license-btn').forEach(button => {
    button.addEventListener('click', function(event) {
      event.preventDefault();
      event.stopPropagation(); // Prevents bubble-up to card click handler
      
      const assignmentId = this.getAttribute('data-assignment-id');
      const productName = this.getAttribute('data-product-name');
      
      if (assignmentId && productName) {
        showReturnLicenseModal(assignmentId, productName);
      }
    });
  });
}

/**
 * Initializes the My Licenses page
 */
export function initMyLicensesPage() {
  // Initialize Bootstrap Modal
  returnLicenseModal = new bootstrap.Modal(document.getElementById('returnLicenseModal'));
  
  // Convert UTC times to local times (imported from utils)
  convertUTCTimesToLocal('time.utc-time');
  
  // Initialize UI components
  initCollapseButtons();
  makeCardsClickable();
  initReturnButtons();
}

