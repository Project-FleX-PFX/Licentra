// /js/features/profile/profileFormHandler.js
import { initPasswordMatcher } from '../../components/passwordMatcher.js';
import { initPasswordStrengthChecker } from '../../components/passwordStrengthChecker.js';
import { showElement, hideElement, setHidden, setText } from '../../utils/domUtils.js';

let passwordMatcherInstance;
let passwordStrengthCheckerInstance;

/**
 * Gets all DOM elements related to a specific profile field
 * @param {string} field - Field name (username, email, password)
 * @returns {Object} Object containing all related DOM elements
 */
function getFieldElements(field) {
  return {
    displayElem: document.getElementById(`${field}-display`),
    inputElem: document.getElementById(`${field}-input`),
    editButton: document.querySelector(`#${field}-item .edit-button`),
    buttonsContainer: document.getElementById(`${field}-buttons`),
    passwordFields: field === 'password' ? document.querySelector('.password-fields') : null,
    passwordInput: field === 'password' ? document.getElementById('password') : null,
    confirmInput: field === 'password' ? document.getElementById('password_confirmation') : null,
    matchMessage: field === 'password' ? document.getElementById('match') : null,
    strengthIndicator: field === 'password' ? document.getElementById('password-strength') : null,
  };
}

/**
 * Toggles between display and edit mode for a field
 * @param {string} field - Field name to toggle
 */
function toggleEdit(field) {
  const elements = getFieldElements(field);
  const isInDisplayMode = elements.editButton && !elements.editButton.classList.contains('d-none');

  if (isInDisplayMode) {
    // Switch to edit mode
    if (field === 'password') {
      setHidden(elements.displayElem, true);
      setHidden(elements.passwordFields, false);
      if (passwordStrengthCheckerInstance) passwordStrengthCheckerInstance.hideIndicator();
    } else {
      elements.inputElem.setAttribute('data-original', elements.inputElem.value);
      setHidden(elements.displayElem, true);
      setHidden(elements.inputElem, false);
      elements.inputElem.focus();
    }
    hideElement(elements.editButton);
    showElement(elements.buttonsContainer);
  } else {
    // Switch to display mode (after save or cancel)
    if (field === 'password') {
      setHidden(elements.passwordFields, true);
      setHidden(elements.displayElem, false);
      if (passwordStrengthCheckerInstance) passwordStrengthCheckerInstance.hideIndicator();
    } else {
      setHidden(elements.inputElem, true);
      setHidden(elements.displayElem, false);
    }
    showElement(elements.editButton);
    hideElement(elements.buttonsContainer);
  }
}

/**
 * Cancels edit mode and reverts changes
 * @param {string} field - Field name to cancel editing
 */
function cancelEdit(field) {
  const elements = getFieldElements(field);

  if (field === 'password') {
    if (elements.passwordInput) elements.passwordInput.value = '';
    if (elements.confirmInput) elements.confirmInput.value = '';
    setHidden(elements.passwordFields, true);
    setHidden(elements.displayElem, false);
    if (passwordStrengthCheckerInstance) passwordStrengthCheckerInstance.hideIndicator();
    if (elements.matchMessage) setHidden(elements.matchMessage, true);
  } else {
    if (elements.inputElem) {
      elements.inputElem.value = elements.inputElem.getAttribute('data-original');
      setHidden(elements.inputElem, true);
      setHidden(elements.displayElem, false);
    }
  }

  showElement(elements.editButton);
  hideElement(elements.buttonsContainer);
}

/**
 * Validates and saves the edited field value
 * @param {string} field - Field name to save
 */
async function saveEdit(field) {
  const elements = getFieldElements(field);
  let newValue;

  if (field === 'password') {
    newValue = elements.passwordInput.value;

    if (passwordStrengthCheckerInstance && !passwordStrengthCheckerInstance.validate()) {
      if (elements.strengthIndicator) elements.strengthIndicator.hidden = false;
      return;
    }

    if (passwordMatcherInstance && !passwordMatcherInstance.check()) {
      if (elements.matchMessage) elements.matchMessage.hidden = false;
      return;
    }
  } else {
    newValue = elements.inputElem.value.trim();

    if (newValue === '') {
      // Zeige Flash-Nachricht statt alert
      showClientSideFlash('error', 'Field cannot be empty.');
      elements.inputElem.value = elements.inputElem.getAttribute('data-original');
      return;
    }

    if (field === 'email') {
      const emailRegExp = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
      if (!emailRegExp.test(newValue)) {
        showClientSideFlash('error', 'Please enter a valid email address.');
        elements.inputElem.value = elements.inputElem.getAttribute('data-original');
        return;
      }
    }
  }

  // Disable save button während Request
  const saveButton = document.getElementById(`${field}-save`);
  if (saveButton) {
    saveButton.disabled = true;
    setText(saveButton.querySelector('i').nextSibling, 'Saving...');
  }

  try {
    const response = await fetch('/update_profile', {
      method: 'POST',
      body: new URLSearchParams({
        field: field,
        value: newValue
      }),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
      },
    });

    // Flash-Nachrichten werden über Rack Flash gesetzt und bei Page Reload angezeigt
    window.location.reload();

  } catch (error) {
    console.error('Profile update error:', error);
    // Fallback bei Network-Fehlern
    showClientSideFlash('error', 'Network error occurred. Please try again.');

    // Button zurücksetzen
    if (saveButton) {
      saveButton.disabled = false;
      setText(saveButton.querySelector('i').nextSibling, 'Save');
    }
  }
}

/**
 * Zeigt eine client-seitige Flash-Nachricht (für Validierungsfehler vor dem Request)
 * @param {string} type - 'success', 'error', 'notice'
 * @param {string} message - Nachricht
 */
function showClientSideFlash(type, message) {
  // Entferne existierende Flash-Nachrichten
  const existingFlash = document.querySelector('.alert');
  if (existingFlash) {
    existingFlash.remove();
  }

  // Erstelle neue Flash-Nachricht
  const alertClass = type === 'error' ? 'alert-danger' :
      type === 'success' ? 'alert-success' : 'alert-info';

  const flashHtml = `
    <div class="alert ${alertClass} alert-dismissible fade show" role="alert">
      ${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    </div>
  `;

  // Füge Flash-Nachricht am Anfang des Containers ein
  const container = document.querySelector('.container');
  container.insertAdjacentHTML('afterbegin', flashHtml);

  // Auto-hide nach 5 Sekunden
  setTimeout(() => {
    const flashElement = document.querySelector('.alert');
    if (flashElement) {
      flashElement.remove();
    }
  }, 5000);
}

/**
 * Initializes the profile form with event listeners
 */
function initProfileForm() {
  passwordMatcherInstance = initPasswordMatcher();
  passwordStrengthCheckerInstance = initPasswordStrengthChecker();

  const fields = ['username', 'email', 'password'];
  fields.forEach((field) => {
    const elements = getFieldElements(field);

    if (elements.editButton) {
      elements.editButton.addEventListener('click', () => toggleEdit(field));
    }

    const saveButton = document.getElementById(`${field}-save`);
    if (saveButton) {
      saveButton.addEventListener('click', () => saveEdit(field));
    }

    const cancelButton = document.getElementById(`${field}-cancel`);
    if (cancelButton) {
      cancelButton.addEventListener('click', () => cancelEdit(field));
    }
  });
}

// Initialize form when DOM is ready
document.addEventListener('DOMContentLoaded', initProfileForm);
