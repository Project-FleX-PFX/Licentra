// frontend/public/js/features/admin/userManagementHandler.js
import { initPasswordMatcher } from '../../components/passwordMatcher.js';
import { initPasswordStrengthChecker } from '../../components/passwordStrengthChecker.js';
import {
  initializeModal,
  showModal,
  hideModal,
  setFormFieldsDisabled as utilSetFormFieldsDisabled,
  populateForm as utilPopulateForm,
  resetAndClearForm as utilResetAndClearForm,
  handleFormSubmit,
  handleDelete,
  showElement,
  hideElement,
  setText,
} from './adminUtils.js';

// Module-specific state variables
let userModalInstance = null;
let deleteConfirmModalInstance = null;
let activeCardElement = null;
let isCurrentlyEditingForm = false;
let currentModalMode = 'view'; // 'add', 'view', 'edit'
let passwordMatcherInstance = null;
let passwordStrengthCheckerInstance = null;

/**
 * Enables or disables password fields and associated validation indicators
 * @param {HTMLFormElement} formElement - The form element
 * @param {boolean} enable - True to enable fields and validation
 * @param {string} mode - 'add', 'edit', or 'view' - controls placeholder and behavior
 */
function enableUserPasswordFieldsAndValidation(formElement, enable, mode = 'view') {
  const passwordField = formElement.password;
  const confirmPasswordField = formElement.password_confirmation;
  const passwordConfirmationGroup = document.getElementById('passwordConfirmationGroup');
  const strengthIndicator = document.getElementById('password-strength');
  const matchIndicator = document.getElementById('match');
  const passwordHelpText = document.getElementById('passwordHelpText');

  if (passwordField) passwordField.disabled = !enable;
  if (confirmPasswordField) confirmPasswordField.disabled = !enable;

  if (passwordHelpText) {
    if (enable) {
      if (mode === 'add') {
        setText(passwordHelpText, 'Password is required. Please choose a strong password.');
        if (passwordField) passwordField.placeholder = 'Enter password';
      } else if (mode === 'edit') {
        setText(passwordHelpText, 'Enter new password to change it. Leave blank to keep current password.');
        if (passwordField) passwordField.placeholder = 'Enter new password (optional)';
      } else {
        setText(passwordHelpText, 'Password field.');
      }
    } else {
      if (mode === 'view') {
        setText(passwordHelpText, 'Password is not displayed. Click \'Edit\' to change.');
        if (passwordField) passwordField.placeholder = '********';
      } else {
        setText(passwordHelpText, 'Password will be set.');
      }
    }
  }

  if (enable) {
    if (passwordConfirmationGroup) showElement(passwordConfirmationGroup);
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
    
    // Clear password fields when disabled (except in pure view mode before edit)
    if (mode !== 'view' || isCurrentlyEditingForm) {
      if (passwordField) passwordField.value = '';
      if (confirmPasswordField) confirmPasswordField.value = '';
    } else if (mode === 'view' && !isCurrentlyEditingForm) {
      if (passwordField) passwordField.placeholder = '********';
    }
  }
}

/**
 * Populates the user form with data or resets it
 * Uses the generic populateForm from adminUtils
 * @param {HTMLFormElement} formElement - The form element
 * @param {Object} userData - User data (from card.dataset)
 * @param {string} mode - 'add', 'edit', or 'view' for initial state in edit mode
 */
function populateUserModalForm(formElement, userData = {}, mode = 'view') {
  if (!formElement) return;

  // Mapping for populateForm, as data-* attributes are kebab-case
  const fieldMappings = {
    'user_id': 'userId',
    'first_name': 'firstName',
    'last_name': 'lastName',
    'username': 'username',
    'email': 'email',
  };
  
  // Use the generic function. It should call formElement.reset() internally.
  utilPopulateForm(formElement, userData, fieldMappings);
  
  // Explicitly set user_id as populateForm might not find it as 'userId'
  formElement.user_id.value = (mode !== 'add' && userData.userId) ? userData.userId : '';

  // Always clear password fields when populating/resetting
  if (formElement.password) formElement.password.value = '';
  if (formElement.password_confirmation) formElement.password_confirmation.value = '';

  // Set role checkboxes specially as populateForm can't handle this
  const roleCheckboxes = formElement.querySelectorAll('input[name="roles[]"]');
  roleCheckboxes.forEach(checkbox => checkbox.checked = false);
  
  if (mode !== 'add' && userData.roleIds) {
    const userRoleIds = userData.roleIds.split(',');
    userRoleIds.forEach(roleId => {
      const checkbox = formElement.querySelector(`input[name="roles[]"][value="${roleId.trim()}"]`);
      if (checkbox) checkbox.checked = true;
    });
  }
  
  hideElement('rolesError');

  // Show/hide "Manage Licenses" section
  const licenseSection = document.getElementById('licenseManagementSection');
  const manageLicensesBtn = document.getElementById('manageLicensesBtn');

  if (mode !== 'add' && userData.userId) {
    showElement(licenseSection);
    if (manageLicensesBtn) {
      // Reset event listener to avoid stale closures
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
 * Opens the user modal in the specified mode
 * @param {string} mode - 'add' (new user) or 'view' (view/edit existing user)
 * @param {HTMLElement|null} cardElement - The user card element (only for 'view')
 */
function openUserModal(mode, cardElement = null) {
  const formElement = document.getElementById('userForm');
  const modalTitleElement = document.getElementById('userModalLabel');
  const editButton = document.getElementById('editUserBtn');
  const saveButton = document.getElementById('saveUserBtn');
  const deleteButton = document.getElementById('deleteUserBtn');
  
  currentModalMode = mode;
  activeCardElement = cardElement;
  isCurrentlyEditingForm = (mode === 'add');

  const cardData = cardElement ? { ...cardElement.dataset } : {};

  populateUserModalForm(formElement, cardData, mode);

  if (mode === 'add') {
    setText(modalTitleElement, 'Add New User');
    utilSetFormFieldsDisabled(formElement, false, ['deleteUserBtn', 'manageLicensesBtn', 'editUserBtn']);
    enableUserPasswordFieldsAndValidation(formElement, true, 'add');
    hideElement(editButton);
    hideElement(deleteButton);
    if (saveButton) { 
      saveButton.disabled = false; 
      setText(saveButton, 'Add User'); 
    }
    const firstFocusableInput = formElement.querySelector('input:not([type="hidden"]):not([disabled]), select:not([disabled]), textarea:not([disabled])');
    if (firstFocusableInput) firstFocusableInput.focus();
  } else {
    setText(modalTitleElement, `User: ${cardData.username || 'Details'}`);
    utilSetFormFieldsDisabled(formElement, true, ['editUserBtn', 'deleteUserBtn', 'saveUserBtn', 'manageLicensesBtn']);
    enableUserPasswordFieldsAndValidation(formElement, false, 'view');
    showElement(editButton); 
    setText(editButton, 'Edit'); 
    editButton.classList.remove('btn-warning'); 
    editButton.disabled = false;
    showElement(deleteButton); 
    deleteButton.disabled = false;
    if (saveButton) { 
      saveButton.disabled = true; 
      setText(saveButton, 'Save Changes'); 
    }
  }
  showModal(userModalInstance);
}

/**
 * Initializes the user management functionality
 */
export function initAdminUserManagement() {
  userModalInstance = initializeModal('userModal');
  deleteConfirmModalInstance = initializeModal('deleteConfirmModal');

  // Event listeners for "Edit User" buttons on cards
  document.querySelectorAll('.user-card .user-edit-btn').forEach(button => {
    button.addEventListener('click', (event) => {
      event.stopPropagation();
      openUserModal('view', button.closest('.user-card'));
    });
  });

  // Event listener for "Add User" button
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
      
      utilSetFormFieldsDisabled(
        userForm, 
        !isCurrentlyEditingForm, 
        ['editUserBtn', 'deleteUserBtn', 'saveUserBtn', 'manageLicensesBtn', 'password', 'password_confirmation']
      );
      enableUserPasswordFieldsAndValidation(userForm, isCurrentlyEditingForm, 'edit');
      saveUserButton.disabled = !isCurrentlyEditingForm;

      if (isCurrentlyEditingForm) {
        setText(editUserButton, 'Cancel'); 
        editUserButton.classList.add('btn-warning');
        const firstFocusableInput = userForm.querySelector('input:not([type="hidden"]):not([disabled]), select:not([disabled]), textarea:not([disabled])');
        if (firstFocusableInput) firstFocusableInput.focus();
      } else {
        setText(editUserButton, 'Edit'); 
        editUserButton.classList.remove('btn-warning');
        if (activeCardElement && currentModalMode === 'view') {
          populateUserModalForm(userForm, activeCardElement.dataset, 'view');
        }
        hideElement('rolesError');
      }
    });
  }

  // Form submit handler
  if (userForm) {
    userForm.addEventListener('submit', async (event) => {
      const rolesCheckboxes = userForm.querySelectorAll('input[name="roles[]"]');
      const atLeastOneRoleSelected = Array.from(rolesCheckboxes).some(checkbox => checkbox.checked);
      const rolesError = document.getElementById('rolesError');

      if (!atLeastOneRoleSelected) {
        if (rolesError) {
          setText(rolesError, 'Please select at least one role.');
          showElement(rolesError);
          rolesError.scrollIntoView({ behavior: 'smooth', block: 'center' });
        }
        event.preventDefault();
        return;
      } else {
        if (rolesError) hideElement(rolesError);
      }
      
      // Client-side password validation
      const passwordField = userForm.password;
      if (!passwordField.disabled && passwordField.value.trim() !== '') {
        if (passwordStrengthCheckerInstance && !passwordStrengthCheckerInstance.validate()) {
          alert('Password does not meet the requirements. Please check the indicators.');
          passwordField.focus();
          event.preventDefault(); 
          return;
        }
        if (passwordMatcherInstance && !passwordMatcherInstance.check()) {
          alert('Passwords do not match.');
          userForm.password_confirmation.focus();
          event.preventDefault(); 
          return;
        }
      }

      // HTML5 form validation
      if (!userForm.checkValidity()) {
        userForm.reportValidity();
        event.preventDefault();
        return;
      }

      const userId = userForm.user_id.value;

      handleFormSubmit({
        event,
        formElement: userForm,
        itemId: userId,
        baseUrl: '/user_management',
      });
    });
  }

  // Delete user button in modal
  const deleteUserButtonInModal = document.getElementById('deleteUserBtn');
  if (deleteUserButtonInModal) {
    deleteUserButtonInModal.addEventListener('click', () => {
      if (activeCardElement) {
        const username = activeCardElement.dataset.username || 'this user';
        setText('deleteUserNameSpan', username);
        showModal(deleteConfirmModalInstance);
      }
    });
  }

  // Confirm delete button
  const confirmDeleteActualButton = document.getElementById('confirmDeleteBtn');
  if (confirmDeleteActualButton) {
    confirmDeleteActualButton.addEventListener('click', async () => {
      if (activeCardElement) {
        const userId = activeCardElement.dataset.userId;
        if (userId) {
          handleDelete({
            itemId: userId,
            baseUrl: '/user_management',
            modalToDeleteInstance: deleteConfirmModalInstance,
          });
          if (userModalInstance) hideModal(userModalInstance);
        }
      }
    });
  }

  // Event listener for closing the main modal
  const userModalElement = document.getElementById('userModal');
  if (userModalElement) {
    userModalElement.addEventListener('hidden.bs.modal', function () {
      const form = document.getElementById('userForm');
      if (form) {
        populateUserModalForm(form, {}, 'add');
        utilSetFormFieldsDisabled(form, true, ['editUserBtn', 'saveUserBtn', 'deleteUserBtn', 'manageLicensesBtn']);
        enableUserPasswordFieldsAndValidation(form, false, 'view');
      }
      
      const editBtn = document.getElementById('editUserBtn');
      if (editBtn) { 
        setText(editBtn, 'Edit'); 
        editBtn.classList.remove('btn-warning'); 
      }
      const saveBtn = document.getElementById('saveUserBtn');
      if (saveBtn) {
        saveBtn.disabled = true; 
        setText(saveBtn, 'Save Changes');
      }
      
      hideElement('rolesError');
      
      document.querySelectorAll('.user-card.border-primary').forEach(c => c.classList.remove('border-primary', 'border-3'));
      activeCardElement = null;
      isCurrentlyEditingForm = false;
      currentModalMode = 'view';
    });
  }
}

