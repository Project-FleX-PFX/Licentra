// /js/features/profile/profileFormHandler.js
import { initPasswordMatcher } from '../../components/passwordMatcher.js';
import { initPasswordStrengthChecker } from '../../components/passwordStrengthChecker.js';
import { showElement, hideElement, setHidden, setText } from '../../utils/domUtils.js';
import { updateProfileData } from '../../core/profileService.js';

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
  // Check if edit button is visible (not having 'd-none' class)
  const isInDisplayMode = elements.editButton && !elements.editButton.classList.contains('d-none');

  if (isInDisplayMode) {
    // Switch to edit mode
    if (field === 'password') {
      setHidden(elements.displayElem, true);
      setHidden(elements.passwordFields, false);
      // Don't show password strength indicator immediately, only on input or focus
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
    newValue = elements.passwordInput.value; // Don't trim passwords
    
    if (passwordStrengthCheckerInstance && !passwordStrengthCheckerInstance.validate()) {
      if (elements.strengthIndicator) elements.strengthIndicator.hidden = false;
      return; // Abort if requirements not met
    }
    
    if (passwordMatcherInstance && !passwordMatcherInstance.check()) {
      if (elements.matchMessage) elements.matchMessage.hidden = false;
      return; // Abort if passwords don't match
    }
  } else {
    newValue = elements.inputElem.value.trim();
    
    if (newValue === '') {
      alert('Field cannot be empty.');
      elements.inputElem.value = elements.inputElem.getAttribute('data-original');
      return;
    }
    
    if (field === 'email') {
      const emailRegExp = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$/;
      if (!emailRegExp.test(newValue)) {
        alert('Please enter a valid email address.');
        elements.inputElem.value = elements.inputElem.getAttribute('data-original');
        return;
      }
    }
  }

  const result = await updateProfileData(field, newValue);

  if (result.success) {
    if (field === 'password') {
      setText(elements.displayElem, '********');
      elements.passwordInput.value = '';
      elements.confirmInput.value = '';
      if (passwordStrengthCheckerInstance) passwordStrengthCheckerInstance.hideIndicator();
      if (elements.matchMessage) setHidden(elements.matchMessage, true);
    } else {
      setText(elements.displayElem, newValue);
      elements.inputElem.setAttribute('data-original', newValue);
    }
    toggleEdit(field); // Switch UI back to display mode
  } else {
    alert(result.message || 'Error updating profile');
    if (field !== 'password' && elements.inputElem) {
      elements.inputElem.value = elements.inputElem.getAttribute('data-original');
    }
  }
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

