// /js/features/profile/profileFormHandler.js
import { initPasswordMatcher } from '../../components/passwordMatcher.js';
import { initPasswordStrengthChecker } from '../../components/passwordStrengthChecker.js';
import { showElement, hideElement, setHidden, setText } from '../../utils/domUtils.js';
import { updateProfileData } from '../../core/profileService.js'; // NUR IMPORT

let passwordMatcherInstance;
let passwordStrengthCheckerInstance;

function getFieldElements(field) {
  return {
    displayElem: document.getElementById(field + '-display'),
    inputElem: document.getElementById(field + '-input'),
    editButton: document.querySelector('#' + field + '-item .edit-button'),
    buttonsContainer: document.getElementById(field + '-buttons'),
    passwordFields: field === 'password' ? document.querySelector('.password-fields') : null,
    passwordInput: field === 'password' ? document.getElementById('password') : null,
    confirmInput: field === 'password' ? document.getElementById('password_confirmation') : null,
    matchMessage: field === 'password' ? document.getElementById('match') : null,
    strengthIndicator: field === 'password' ? document.getElementById('password-strength') : null,
  };
}

function toggleEdit(field) {
  const elements = getFieldElements(field);
  // Prüfen, ob der Edit-Button sichtbar ist (d.h. keine 'd-none' Klasse hat)
  const isInDisplayMode = elements.editButton && !elements.editButton.classList.contains('d-none');

  if (isInDisplayMode) { // Wechsel zu Edit
    if (field === 'password') {
      setHidden(elements.displayElem, true);
      setHidden(elements.passwordFields, false);
      // Passwort-Stärke-Indikator nicht sofort zeigen, erst bei Eingabe oder Fokus
      if (passwordStrengthCheckerInstance) passwordStrengthCheckerInstance.hideIndicator(); 
    } else {
      elements.inputElem.setAttribute('data-original', elements.inputElem.value);
      setHidden(elements.displayElem, true);
      setHidden(elements.inputElem, false);
      elements.inputElem.focus(); // Fokus auf das Input-Feld setzen
    }
    hideElement(elements.editButton);
    showElement(elements.buttonsContainer);
  } else { // Wechsel zu Display (z.B. nach Save oder Cancel)
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

async function saveEdit(field) {
  const elements = getFieldElements(field);
  let newValue;

  if (field === 'password') {
    newValue = elements.passwordInput.value; // Passwörter nicht trimmen
    
    if (passwordStrengthCheckerInstance && !passwordStrengthCheckerInstance.validate()) {
      if (elements.strengthIndicator) elements.strengthIndicator.hidden = false; // Sicherstellen, dass es sichtbar ist
      return; // Abbruch, wenn Anforderungen nicht erfüllt
    }
     // Erst Anforderungen prüfen, dann Match. Match-Prüfung ist oft Teil von passwordMatcherInstance.check()
    if (passwordMatcherInstance && !passwordMatcherInstance.check()) {
      if (elements.matchMessage) elements.matchMessage.hidden = false; // Sicherstellen, dass es sichtbar ist
      return; // Abbruch, wenn Passwörter nicht übereinstimmen
    }

  } else {
    newValue = elements.inputElem.value.trim();
    
    if (newValue === '') {
      alert("Field cannot be empty.");
      elements.inputElem.value = elements.inputElem.getAttribute('data-original');
      return;
    }
    
    if (field === 'email') {
      const emailRegExp = /^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$/;
      if (!emailRegExp.test(newValue)) {
        alert("Please enter a valid email address.");
        elements.inputElem.value = elements.inputElem.getAttribute('data-original');
        return;
      }
    }
  }

  const result = await updateProfileData(field, newValue); // Ruft die importierte Funktion auf

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
    toggleEdit(field); // Schaltet UI zurück in den Display-Modus
  } else {
    alert(result.message || "Error updating profile");
    if (field !== 'password' && elements.inputElem) {
      elements.inputElem.value = elements.inputElem.getAttribute('data-original');
    }
  }
}

// Initialisierung
document.addEventListener('DOMContentLoaded', () => {
  passwordMatcherInstance = initPasswordMatcher(); // Keine Optionen -> Default IDs
  passwordStrengthCheckerInstance = initPasswordStrengthChecker(); // Keine Optionen -> Default IDs

  const fields = ['username', 'email', 'password'];
  fields.forEach(field => {
    const elements = getFieldElements(field); // Hole Elemente einmal pro Feld

    if (elements.editButton) {
      elements.editButton.addEventListener('click', () => toggleEdit(field));
    }
    
    const saveButton = document.getElementById(`${field}-save`); // Direkter Zugriff, da eindeutige ID
    if (saveButton) {
      saveButton.addEventListener('click', () => saveEdit(field));
    }
    
    const cancelButton = document.getElementById(`${field}-cancel`); // Direkter Zugriff
    if (cancelButton) {
      cancelButton.addEventListener('click', () => cancelEdit(field));
    }
  });
});

