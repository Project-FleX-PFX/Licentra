// frontend/public/js/features/admin/userManagementHandler.js
import { initPasswordMatcher } from '../../components/passwordMatcher.js';
import { initPasswordStrengthChecker } from '../../components/passwordStrengthChecker.js';
import {
    initializeModal,
    showModal,
    hideModal,
    setFormFieldsDisabled as utilSetFormFieldsDisabled, // Alias, um Kollision zu vermeiden, falls lokale Version benötigt wird
    populateForm as utilPopulateForm, // Alias
    resetAndClearForm as utilResetAndClearForm, // Alias
    handleFormSubmit,
    handleDelete,
    showElement,
    hideElement,
    setText
} from './adminUtils.js'; // Pfad ggf. anpassen

// Globale Variablen für dieses Modul
let userModalInstance = null;
let deleteConfirmModalInstance = null;
let activeCardElement = null; // Hält die aktuell bearbeitete Benutzerkarte
let isCurrentlyEditingForm = false; // Ist das Formular im Modal gerade im Editier-Modus (nicht nur View)?
let currentModalMode = 'view'; // 'add', 'view', 'edit' (für internen Zustand des Formulars)
let passwordMatcherInstance = null;
let passwordStrengthCheckerInstance = null;

// --- User-spezifische Hilfsfunktionen ---

/**
 * Aktiviert oder deaktiviert Passwortfelder und zugehörige Validierungsanzeigen.
 * @param {HTMLFormElement} formElement Das Formular-Element.
 * @param {boolean} enable True, um Felder und Validierung zu aktivieren.
 * @param {string} mode 'add', 'edit' oder 'view' - steuert Platzhalter und Verhalten.
 */
function enableUserPasswordFieldsAndValidation(formElement, enable, mode = 'view') {
  const passwordField = formElement.password;
  const confirmPasswordField = formElement.password_confirmation;
  const passwordConfirmationGroup = document.getElementById('passwordConfirmationGroup');
  const strengthIndicator = document.getElementById('password-strength');
  const matchIndicator = document.getElementById('match'); // ID aus HTML
  const passwordHelpText = document.getElementById('passwordHelpText'); // ID aus HTML

  if (passwordField) passwordField.disabled = !enable;
  if (confirmPasswordField) confirmPasswordField.disabled = !enable;

  if (enable) {
    if (passwordConfirmationGroup) showElement(passwordConfirmationGroup);
    if (passwordHelpText) setText(passwordHelpText, "Enter new password. Will be validated if set.");
    if (strengthIndicator) strengthIndicator.hidden = false;

    if (!passwordStrengthCheckerInstance) {
      passwordStrengthCheckerInstance = initPasswordStrengthChecker({ passwordInputId: 'password' });
    }
    if (!passwordMatcherInstance) {
      passwordMatcherInstance = initPasswordMatcher({ passwordInputId: 'password', confirmInputId: 'password_confirmation' });
    }
  } else {
    if (passwordConfirmationGroup) hideElement(passwordConfirmationGroup);
    if (strengthIndicator) strengthIndicator.hidden = true;
    if (matchIndicator) matchIndicator.hidden = true;
    if (passwordHelpText) {
      if (mode === 'add') {
         setText(passwordHelpText, "Password is required.");
      } else {
         setText(passwordHelpText, "Leave blank to keep current password. Will be validated if set.");
      }
    }
    // Passwortfelder leeren, wenn sie deaktiviert werden (optional, aber oft gut für UX)
    if (passwordField) passwordField.value = '';
    if (confirmPasswordField) confirmPasswordField.value = '';
  }
}

/**
 * Befüllt das Benutzerformular mit Daten oder setzt es zurück.
 * Nutzt die generische populateForm aus adminUtils.
 * @param {HTMLFormElement} formElement Das Formular-Element.
 * @param {object} userData Die Benutzerdaten (aus card.dataset).
 * @param {string} mode 'add' oder 'edit' (oder 'view' für den initialen Zustand im Edit-Modus)
 */
function populateUserModalForm(formElement, userData = {}, mode = 'view') { // Default zu 'view'
  if (!formElement) return;

  // Mapping für populateForm, da data-* Attribute kebab-case sind
  const fieldMappings = {
    'user_id': 'userId',
    'first_name': 'firstName',
    'last_name': 'lastName',
    'username': 'username',
    'email': 'email',
    // Rollen werden speziell behandelt
  };
  
  // Nutze die generische Funktion. Sie sollte formElement.reset() intern aufrufen.
  // Sie wird mit userData befüllt, oder mit {} für den Add-Modus (was einem Reset gleichkommt).
  utilPopulateForm(formElement, userData, fieldMappings);
  
  // Explizit user_id setzen, da populateForm es vielleicht nicht als 'userId' findet
  // oder es durch das allgemeine Reset gelöscht wird.
  formElement.user_id.value = (mode !== 'add' && userData.userId) ? userData.userId : '';

  // Passwortfelder immer leeren beim Befüllen/Zurücksetzen
  if (formElement.password) formElement.password.value = '';
  if (formElement.password_confirmation) formElement.password_confirmation.value = '';

  // Rollen-Checkboxes speziell setzen, da populateForm das nicht kann
  const roleCheckboxes = formElement.querySelectorAll('input[name="roles[]"]');
  roleCheckboxes.forEach(checkbox => checkbox.checked = false); // Zuerst alle deselektieren
  
  if (mode !== 'add' && userData.roleIds) { // userData.roleIds ist ein String "1,2,3"
    const userRoleIds = userData.roleIds.split(',');
    userRoleIds.forEach(roleId => {
      const checkbox = formElement.querySelector(`input[name="roles[]"][value="${roleId.trim()}"]`);
      if (checkbox) checkbox.checked = true;
    });
  }
  
  hideElement('rolesError'); // Rollenfehler beim Neubefüllen ausblenden

  // "Manage Licenses" Sektion anzeigen/verstecken
  const licenseSection = document.getElementById('licenseManagementSection');
  const manageLicensesBtn = document.getElementById('manageLicensesBtn');

  if (mode !== 'add' && userData.userId) {
    showElement(licenseSection);
    if (manageLicensesBtn) {
      // Event Listener neu setzen, um Stale Closures zu vermeiden
      const newBtn = manageLicensesBtn.cloneNode(true);
      manageLicensesBtn.parentNode.replaceChild(newBtn, manageLicensesBtn);
      newBtn.addEventListener('click', () => {
        window.location.href = `/user_management/${userData.userId}/assignments`;
      });
    }
  } else {
    hideElement(licenseSection);
  }
}

/**
 * Öffnet das User-Modal im spezifizierten Modus.
 * @param {string} mode 'add' (neuer User) oder 'view' (bestehenden User ansehen/bearbeiten).
 * @param {HTMLElement|null} cardElement Das Karten-Element des Users (nur für 'view').
 */
function openUserModal(mode, cardElement = null) {
  const formElement = document.getElementById('userForm');
  const modalTitleElement = document.getElementById('userModalLabel');
  const editButton = document.getElementById('editUserBtn');
  const saveButton = document.getElementById('saveUserBtn');
  const deleteButton = document.getElementById('deleteUserBtn');
  
  currentModalMode = mode; // 'add' oder 'view' (initial)
  activeCardElement = cardElement;
  isCurrentlyEditingForm = (mode === 'add'); // Im Add-Modus ist das Formular direkt editierbar

  const cardData = cardElement ? { ...cardElement.dataset } : {}; // Leere Daten für Add-Modus

  // Formular befüllen/zurücksetzen
  populateUserModalForm(formElement, cardData, mode);

  if (mode === 'add') {
    setText(modalTitleElement, 'Add New User');
    utilSetFormFieldsDisabled(formElement, false, ['deleteUserBtn', 'manageLicensesBtn', 'editUserBtn']);
    enableUserPasswordFieldsAndValidation(formElement, true, 'add'); // Passwortfelder sind im Add-Modus editierbar
    hideElement(editButton);
    hideElement(deleteButton);
    if (saveButton) { saveButton.disabled = false; setText(saveButton, 'Add User'); }
     const firstFocusableInput = formElement.querySelector('input:not([type="hidden"]):not([disabled]), select:not([disabled]), textarea:not([disabled])');
    if (firstFocusableInput) firstFocusableInput.focus();
  } else { // 'view' mode (initialer Zustand, wenn ein User ausgewählt wird)
    setText(modalTitleElement, `User: ${cardData.username || 'Details'}`);
    utilSetFormFieldsDisabled(formElement, true, ['editUserBtn', 'deleteUserBtn', 'saveUserBtn', 'manageLicensesBtn']);
    enableUserPasswordFieldsAndValidation(formElement, false, 'view'); // Passwortfelder sind im View-Modus gesperrt
    showElement(editButton); setText(editButton, 'Edit'); editButton.classList.remove('btn-warning'); editButton.disabled = false;
    showElement(deleteButton); deleteButton.disabled = false;
    if (saveButton) { saveButton.disabled = true; setText(saveButton, 'Save Changes'); }
  }
  showModal(userModalInstance);
}

// --- HAUPTINITIALISIERUNG ---
export function initAdminUserManagement() {
  userModalInstance = initializeModal('userModal');
  deleteConfirmModalInstance = initializeModal('deleteConfirmModal');

  // Event Listener für "Edit User" Buttons auf den Karten
  document.querySelectorAll('.user-card .user-edit-btn').forEach(button => {
    button.addEventListener('click', (event) => {
      event.stopPropagation();
      openUserModal('view', button.closest('.user-card')); // Öffnet Modal im View-Modus
    });
  });

  // Event Listener für "Add User" Button
  const addUserButton = document.getElementById('addUserBtn');
  if (addUserButton) {
    addUserButton.addEventListener('click', () => openUserModal('add'));
  }

  const editUserButton = document.getElementById('editUserBtn'); // Innerhalb des Modals
  const saveUserButton = document.getElementById('saveUserBtn'); // Innerhalb des Modals
  const userForm = document.getElementById('userForm');

  if (editUserButton && saveUserButton && userForm) {
    editUserButton.addEventListener('click', () => {
      isCurrentlyEditingForm = !isCurrentlyEditingForm; // Toggle Editier-Zustand
      // currentModalMode sollte 'view' sein, wenn dieser Button geklickt wird.
      // Der eigentliche Bearbeitungsmodus der Felder wird durch isCurrentlyEditingForm gesteuert.
      
      utilSetFormFieldsDisabled(userForm, !isCurrentlyEditingForm, ['editUserBtn', 'deleteUserBtn', 'saveUserBtn', 'manageLicensesBtn', 'password', 'password_confirmation']);
      enableUserPasswordFieldsAndValidation(userForm, isCurrentlyEditingForm, 'edit'); // 'edit' signalisiert, dass Passwort geändert werden kann
      saveUserButton.disabled = !isCurrentlyEditingForm;

      if (isCurrentlyEditingForm) {
        setText(editUserButton, 'Cancel'); editUserButton.classList.add('btn-warning');
        const firstFocusableInput = userForm.querySelector('input:not([type="hidden"]):not([disabled]), select:not([disabled]), textarea:not([disabled])');
        if (firstFocusableInput) firstFocusableInput.focus();
      } else { // "Cancel" wurde geklickt
        setText(editUserButton, 'Edit'); editUserButton.classList.remove('btn-warning');
        // Formular auf Daten der aktiven Karte zurücksetzen (falls vorhanden)
        if (activeCardElement && currentModalMode === 'view') { // Nur wenn im View-Modus einer Karte
          populateUserModalForm(userForm, activeCardElement.dataset, 'view');
        }
        // Passwortfelder werden durch enableUserPasswordFieldsAndValidation(..., false, 'view') behandelt.
        hideElement('rolesError');
      }
    });
  }

  // Formular-Submit-Handler
  if (userForm) {
    userForm.addEventListener('submit', async (event) => {
      // event.preventDefault() wird in handleFormSubmit gemacht
      
      const rolesCheckboxes = userForm.querySelectorAll('input[name="roles[]"]');
      const atLeastOneRoleSelected = Array.from(rolesCheckboxes).some(checkbox => checkbox.checked);
      const rolesError = document.getElementById('rolesError');

      if (!atLeastOneRoleSelected) {
        if (rolesError) {
            setText(rolesError,'Please select at least one role.');
            showElement(rolesError);
            rolesError.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
        event.preventDefault(); // Verhindere Submit, wenn Validierung fehlschlägt
        return;
      } else {
        if (rolesError) hideElement(rolesError);
      }
      
      // Client-seitige Passwortvalidierung, wenn Passwort geändert wird
      const passwordField = userForm.password;
      if (!passwordField.disabled && passwordField.value.trim() !== '') {
        if (passwordStrengthCheckerInstance && !passwordStrengthCheckerInstance.validate()) {
          alert('Password does not meet the requirements. Please check the indicators.');
          passwordField.focus();
          event.preventDefault(); return;
        }
        if (passwordMatcherInstance && !passwordMatcherInstance.check()) {
          alert('Passwords do not match.');
          userForm.password_confirmation.focus();
          event.preventDefault(); return;
        }
      }

      // HTML5 Formularvalidierung (sollte in handleFormSubmit enthalten sein, aber hier zur Sicherheit)
      if (!userForm.checkValidity()) {
        userForm.reportValidity();
        event.preventDefault();
        return;
      }

      const userId = userForm.user_id.value; // Holen der ID für handleFormSubmit

      // handleFormSubmit kümmert sich um das Erstellen der FormData und das Setzen von _method
      handleFormSubmit({
          event,
          formElement: userForm,
          itemId: userId, // Wenn userId leer, dann POST, sonst PUT (intern mit _method)
          baseUrl: '/user_management',
          // onSuccess und onError werden durch den window.location.reload() in handleFormSubmit abgedeckt
      });
    });
  }

  // Delete User Button im Modal
  const deleteUserButtonInModal = document.getElementById('deleteUserBtn');
  if (deleteUserButtonInModal) {
    deleteUserButtonInModal.addEventListener('click', () => {
      if (activeCardElement) {
        const username = activeCardElement.dataset.username || "this user";
        setText('deleteUserNameSpan', username); // ID des Span im Bestätigungsmodal
        showModal(deleteConfirmModalInstance);
      }
    });
  }

  // Bestätigung des Löschens
  const confirmDeleteActualButton = document.getElementById('confirmDeleteBtn');
  if (confirmDeleteActualButton) {
    confirmDeleteActualButton.addEventListener('click', async () => {
      if (activeCardElement) {
        const userId = activeCardElement.dataset.userId;
        if (userId) {
          handleDelete({
            itemId: userId,
            baseUrl: '/user_management',
            modalToDeleteInstance: deleteConfirmModalInstance, // Das Bestätigungsmodal schließen
            // onSuccess wird durch window.location.reload() in handleDelete abgedeckt
          });
          // Hauptmodal ebenfalls schließen, da der User weg ist
          if (userModalInstance) hideModal(userModalInstance);
        }
      }
    });
  }

  // Event Listener für das Schließen des Hauptmodals (userModal)
  const userModalElement = document.getElementById('userModal');
  if (userModalElement) {
      userModalElement.addEventListener('hidden.bs.modal', function () {
          const form = document.getElementById('userForm');
          if (form) {
            // Nutze utilResetAndClearForm, die populateForm intern mit {} aufruft.
            // Die populateUserModalForm kümmert sich dann um spezifische Felder.
            populateUserModalForm(form, {}, 'add'); // Setzt Form zurück in "add"-ähnlichen Zustand
            utilSetFormFieldsDisabled(form, true, ['editUserBtn', 'saveUserBtn', 'deleteUserBtn', 'manageLicensesBtn']);
            enableUserPasswordFieldsAndValidation(form, false, 'view'); // Passwortfelder in View-Zustand
          }
          
          const editBtn = document.getElementById('editUserBtn');
          if(editBtn) { setText(editBtn, 'Edit'); editBtn.classList.remove('btn-warning'); }
          const saveBtn = document.getElementById('saveUserBtn');
          if(saveBtn) saveBtn.disabled = true; setText(saveBtn, 'Save Changes');

          hideElement('rolesError');
          
          document.querySelectorAll('.user-card.border-primary').forEach(c => c.classList.remove('border-primary', 'border-3'));
          activeCardElement = null;
          isCurrentlyEditingForm = false;
          currentModalMode = 'view'; // Zurück zum Standard
      });
  }
}

