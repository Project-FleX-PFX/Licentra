// frontend/public/js/features/admin/userManagementHandler.js
import { initPasswordMatcher } from '../../components/passwordMatcher.js';
import { initPasswordStrengthChecker } from '../../components/passwordStrengthChecker.js';
import {
    initializeModal, showModal, hideModal,
    setFormFieldsDisabled, populateForm, resetAndClearForm,
    handleFormSubmit, handleDelete,
    showElement, hideElement, setText
} from './adminUtils.js';

// Modul-spezifische Zustandsvariablen
let userModalInstance = null;
let deleteConfirmModalInstance = null;
let activeCardElement = null;
let isCurrentlyEditingForm = false;
let currentModalMode = 'view'; // 'add', 'view', 'edit'

let passwordMatcherInstance = null;
let passwordStrengthCheckerInstance = null;

// --- User-spezifische Hilfsfunktionen ---
function enableUserPasswordFieldsAndValidation(formElement, enable, mode = 'edit') {
  const passwordField = formElement.password;
  const confirmPasswordField = formElement.password_confirmation;
  const passwordConfirmationGroup = document.getElementById('passwordConfirmationGroup');
  const strengthIndicator = document.getElementById('password-strength'); // Das Haupt-Div für die Stärke-Kriterien
  const matchIndicator = document.getElementById('match'); // Das P-Tag für die Match-Anzeige
  const passwordHelpText = document.getElementById('passwordHelpText');

  if (!passwordField || !confirmPasswordField || !passwordConfirmationGroup || !strengthIndicator || !matchIndicator || !passwordHelpText) {
    // console.warn("Password related DOM elements not found, skipping password validation setup.");
    return;
  }
  
  passwordField.disabled = !enable;
  confirmPasswordField.disabled = !enable;

  if (enable) { // Wenn die Passwortfelder editierbar werden
    showElement(passwordConfirmationGroup); // Bestätigungsfeld-Gruppe anzeigen
    if (mode === 'add') {
      passwordField.placeholder = "Enter password";
      passwordField.required = true;
      confirmPasswordField.required = true;
      setText(passwordHelpText, "Password is required and will be validated.");
    } else { // 'edit' mode
      passwordField.placeholder = "Enter new password (optional)";
      passwordField.required = false;
      confirmPasswordField.required = false; // Nur required wenn passwordField was enthält (HTML5 kann das nicht direkt)
      setText(passwordHelpText, "Leave blank to keep current password. Enter new password to change.");
    }

    // Initialisiere die Validatoren, WENN sie noch nicht existieren.
    // Die Komponenten selbst binden ihre Event-Listener.
    if (!passwordStrengthCheckerInstance) {
      passwordStrengthCheckerInstance = initPasswordStrengthChecker({ passwordInputId: 'password' });
    }
    if (!passwordMatcherInstance) {
      passwordMatcherInstance = initPasswordMatcher({ passwordInputId: 'password', confirmInputId: 'password_confirmation' });
    }
    
    // Stelle sicher, dass die Feedback-Container sichtbar sind, wenn die Felder aktiv sind
    // und bereits Text enthalten könnten (oder wenn der Benutzer zu tippen beginnt).
    // Die Komponenten sollten dies eigentlich intern steuern, aber eine explizite Kontrolle hier kann helfen.
    strengthIndicator.hidden = false; // passwordStrengthChecker sollte dies bei keyup/focus selbst tun
    // matchIndicator.hidden = (confirmPasswordField.value === ''); // passwordMatcher sollte dies selbst tun

    // Wichtig: Wenn die Komponenten beim Initialisieren nicht selbst eine erste Validierung auslösen,
    // und die Felder könnten schon Werte haben (z.B. durch Browser-Autofill, obwohl wir .reset() nutzen),
    // könnte man hier eine initiale Prüfung anstoßen:
    // passwordStrengthCheckerInstance.validate(); // Falls die Komponente das so exponiert
    // passwordMatcherInstance.check();         // Falls die Komponente das so exponiert

    // Deine Komponenten machen das gut über 'keyup' und 'focus' Listener.
    // Der passwordStrengthChecker zeigt seinen Indikator bei 'focus' und 'keyup'.
    // Der passwordMatcher zeigt seinen Indikator auch bei 'keyup' und 'focus'.
    // Das Problem könnte sein, dass die *Hauptcontainer* (#password-strength) initial 'hidden' sind
    // und die Komponenten das nicht überschreiben oder der Status nicht richtig gesetzt wird.

    // Explizit sicherstellen, dass der Strength-Indikator sichtbar ist, wenn das Feld aktiviert wird
    // und die Komponente existiert.
    if (passwordStrengthCheckerInstance && typeof passwordStrengthCheckerInstance.showIndicator === 'function') {
        passwordStrengthCheckerInstance.showIndicator();
    } else if (strengthIndicator) { // Fallback
        strengthIndicator.hidden = false;
    }
    // Der Match-Indikator wird durch den Matcher selbst gehandhabt (initial versteckt, dann bei Eingabe gezeigt).


  } else { // Passwortfelder deaktivieren
    hideElement(passwordConfirmationGroup);
    if (passwordStrengthCheckerInstance && typeof passwordStrengthCheckerInstance.hideIndicator === 'function') {
        passwordStrengthCheckerInstance.hideIndicator();
    } else if (strengthIndicator) { // Fallback
        strengthIndicator.hidden = true;
    }
    if (matchIndicator) matchIndicator.hidden = true; // Match-Indikator auch verstecken

    setText(passwordHelpText, "Password cannot be changed in view mode.");
    passwordField.required = false;
    confirmPasswordField.required = false;
    passwordField.placeholder = "••••••";
  }
}

function populateUserModalForm(formElement, userData = {}, mode = 'add') {
    // Debugging: Prüfen, welche Daten tatsächlich ankommen
    console.log("User data to populate:", userData);
    
    // Spezifisches Mapping für User-Formular
    const fieldMappings = {
        'user_id': 'userId', // dataset.userId
        'first_name': 'firstName',
        'last_name': 'lastName',
        'username': 'username',
        'email': 'email',
        // Die Rollen werden separat gehandhabt
    };
    console.log("Field mappings for user form:", fieldMappings);
    
    populateForm(formElement, userData, fieldMappings); // Generische Funktion
    if (formElement.password) formElement.password.value = ''; // Passwort immer leeren

    // Spezifische Behandlung für Rollen-Checkboxes
    console.log("Handling roles checkboxes...");
    const roleCheckboxes = formElement.querySelectorAll('input[name="roles[]"]');
    console.log("Found role checkboxes:", roleCheckboxes.length);
    roleCheckboxes.forEach(checkbox => {
        checkbox.checked = false;
        console.log(`Reset checkbox with value '${checkbox.value}' to unchecked.`);
    });
    
    // Extrahiere die Rollen-IDs aus den Daten
    const userRoleIdsString = userData['role-ids'] || userData['roleIds'] || '';
    console.log("User role IDs string:", userRoleIdsString);
    const userRoleIds = userRoleIdsString ? String(userRoleIdsString).split(',') : [];
    console.log("Parsed user role IDs:", userRoleIds);
    
    // Setze die Checkboxen basierend auf den Rollen-IDs
    userRoleIds.forEach(roleId => {
        const checkbox = formElement.querySelector(`input[name="roles[]"][value="${roleId}"]`);
        if (checkbox) {
            checkbox.checked = true;
            console.log(`Checked role checkbox with value '${roleId}'.`);
        } else {
            console.warn(`No checkbox found for role ID '${roleId}'.`);
        }
    });
    
    hideElement('rolesError'); // Stelle sicher, dass der Rollenfehler initial versteckt ist

    const licenseSection = document.getElementById('licenseManagementSection');
    const manageLicensesBtn = document.getElementById('manageLicensesBtn');
    if (mode !== 'add' && userData.userId) { // userData.userId kommt aus dataset.userId
        showElement(licenseSection);
        if (manageLicensesBtn) {
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

function openUserModal(mode, cardElement = null) {
  const formElement = document.getElementById('userForm');
  const modalTitleElement = document.getElementById('userModalLabel');
  const editButton = document.getElementById('editUserBtn');
  const saveButton = document.getElementById('saveUserBtn');
  const deleteButton = document.getElementById('deleteUserBtn');
  
  currentModalMode = mode;
  activeCardElement = cardElement;
  isCurrentlyEditingForm = (mode === 'add');

  const cardData = cardElement ? cardElement.dataset : {};
  populateUserModalForm(formElement, cardData, mode);

  if (mode === 'add') {
    setText(modalTitleElement, 'Add New User');
    setFormFieldsDisabled(formElement, false, ['deleteUserBtn', 'manageLicensesBtn']);
    enableUserPasswordFieldsAndValidation(formElement, true, 'add');
    hideElement(editButton);
    hideElement(deleteButton);
    if(saveButton) { saveButton.disabled = false; setText(saveButton, 'Add User'); }
    formElement.first_name.focus();
  } else { // 'view' mode
    setText(modalTitleElement, `User Details: ${cardData.username || 'N/A'}`);
    setFormFieldsDisabled(formElement, true, ['editUserBtn', 'deleteUserBtn', 'saveUserBtn', 'manageLicensesBtn']);
    enableUserPasswordFieldsAndValidation(formElement, false, 'view');
    showElement(editButton); setText(editButton, 'Edit'); editButton.classList.remove('btn-warning');
    showElement(deleteButton);
    if(saveButton) { saveButton.disabled = true; setText(saveButton, 'Save Changes'); }
  }
  showModal(userModalInstance);
}

// --- HAUPTINITIALISIERUNG ---
export function initAdminUserManagement() {
  userModalInstance = initializeModal('userModal');
  deleteConfirmModalInstance = initializeModal('deleteConfirmModal');

  document.querySelectorAll('.user-card .user-edit-btn').forEach(button => {
    button.addEventListener('click', (event) => {
      event.stopPropagation();
      openUserModal('view', button.closest('.user-card'));
    });
  });

  const addUserButton = document.getElementById('addUserBtn');
  if (addUserButton) {
    addUserButton.addEventListener('click', () => openUserModal('add'));
  }

  const editUserButton = document.getElementById('editUserBtn');
  const saveUserButton = document.getElementById('saveUserBtn');
  const userForm = document.getElementById('userForm');

  if (editUserButton && saveUserButton && userForm) {
    editUserButton.addEventListener('click', () => {
      isCurrentlyEditingForm = !isCurrentlyEditingForm;
      const effectivePwMode = (currentModalMode === 'add' && isCurrentlyEditingForm) ? 'add' : (isCurrentlyEditingForm ? 'edit' : 'view');

      setFormFieldsDisabled(userForm, !isCurrentlyEditingForm, ['editUserBtn', 'deleteUserBtn', 'saveUserBtn', 'manageLicensesBtn', 'password', 'password_confirmation']);
      enableUserPasswordFieldsAndValidation(userForm, isCurrentlyEditingForm, effectivePwMode);
      saveUserButton.disabled = !isCurrentlyEditingForm;

      if (isCurrentlyEditingForm) {
        setText(editUserButton, 'Cancel'); editUserButton.classList.add('btn-warning');
        userForm.first_name.focus();
      } else {
        setText(editUserButton, 'Edit'); editUserButton.classList.remove('btn-warning');
        if (currentModalMode === 'add') {
            hideModal(userModalInstance);
        } else if (activeCardElement) {
          populateUserModalForm(userForm, activeCardElement.dataset, 'view');
          // enableUserPasswordFieldsAndValidation wird indirekt durch populateUserModalForm gerufen, wenn mode 'view'
        }
        hideElement('rolesError');
      }
    });
  }

  if (userForm) {
    userForm.addEventListener('submit', (event) => {
      // Client-seitige Validierung spezifisch für User form
      const rolesCheckboxes = userForm.querySelectorAll('input[name="roles[]"]');
      if (!Array.from(rolesCheckboxes).some(cb => cb.checked)) {
        setText('rolesError', 'Please select at least one role.'); showElement('rolesError');
        document.getElementById('rolesError').scrollIntoView({ behavior: 'smooth', block: 'center' });
        event.preventDefault(); return;
      } else {
        hideElement('rolesError');
      }
      
      const passwordField = userForm.password;
      const isAddingNewUser = !userForm.user_id.value;

      if (!passwordField.disabled) { // Nur validieren, wenn Passwortfelder aktiv sind
        if (isAddingNewUser && passwordField.value.trim() === '') {
            alert('Password is required when adding a new user.'); passwordField.focus();
            event.preventDefault(); return;
        }
        if (passwordField.value.trim() !== '' || (isAddingNewUser && passwordField.value.trim() !== '')) { // PW muss nicht leer sein, wenn Edit oder Add
            if (passwordStrengthCheckerInstance && !passwordStrengthCheckerInstance.validate()) {
              alert('Password does not meet requirements.'); passwordField.focus();
              event.preventDefault(); return;
            }
            if (passwordMatcherInstance && !passwordMatcherInstance.check()) {
              alert('Passwords do not match.'); userForm.password_confirmation.focus();
              event.preventDefault(); return;
            }
        }
      }
      // Ende spezifische Validierung

      handleFormSubmit({ // Generischen Handler verwenden
        event, // Stellt sicher, dass preventDefault() am Anfang aufgerufen wird
        formElement: userForm,
        itemId: userForm.user_id.value,
        baseUrl: '/user_management'
      });
    });
  }

  const deleteUserButtonInModal = document.getElementById('deleteUserBtn');
  if (deleteUserButtonInModal) {
    deleteUserButtonInModal.addEventListener('click', () => {
      if (activeCardElement) {
        setText('deleteUserNameSpan', activeCardElement.dataset.username || "this user");
        showModal(deleteConfirmModalInstance);
      }
    });
  }

  const confirmDeleteActualButton = document.getElementById('confirmDeleteBtn');
  if (confirmDeleteActualButton) {
    confirmDeleteActualButton.addEventListener('click', () => {
      if (activeCardElement && activeCardElement.dataset.userId) {
        handleDelete({ // Generischen Handler verwenden
          itemId: activeCardElement.dataset.userId,
          baseUrl: '/user_management'
        });
      }
    });
  }

  const userModalEl = document.getElementById('userModal');
  if (userModalEl) {
      userModalEl.addEventListener('hidden.bs.modal', () => {
          const form = document.getElementById('userForm');
          // Verwende eine spezifische Reset-Funktion, die auch die PW-Felder korrekt handhabt
          if (form) {
            populateUserModalForm(form, {}, 'add'); // Reset zum leeren Add-Zustand
            setFormFieldsDisabled(form, true, ['editUserBtn', 'saveUserBtn', 'deleteUserBtn']); // Standard-Sperrung
            enableUserPasswordFieldsAndValidation(form, false, 'view'); // PW-Felder zurücksetzen
          }
          
          const editBtn = document.getElementById('editUserBtn');
          if(editBtn) { setText(editBtn, 'Edit'); editBtn.classList.remove('btn-warning'); }
          const saveBtn = document.getElementById('saveUserBtn');
          if(saveBtn) saveBtn.disabled = true;
          
          document.querySelectorAll('.user-card.border-primary').forEach(c => c.classList.remove('border-primary', 'border-3'));
          activeCardElement = null;
          isCurrentlyEditingForm = false;
          currentModalMode = 'view';
      });
  }
}

