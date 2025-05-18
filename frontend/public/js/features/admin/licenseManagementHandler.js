// frontend/public/js/features/admin/licenseManagementHandler.js
import {
  initializeModal, showModal, hideModal,
  setFormFieldsDisabled, populateForm, resetAndClearForm,
  handleFormSubmit, handleDelete,
  setText, showElement,
} from './adminUtils.js';

// Module-specific variables
let editLicenseModalInstance = null;
let addLicenseModalInstance = null;
let deleteLicenseConfirmModalInstance = null;
let activeLicenseCardElement = null;
let isLicenseFormEditable = false;

/**
 * Populates the license edit form with license data
 * @param {HTMLFormElement} formElement - The form element to populate
 * @param {Object} licenseData - License data object (usually from dataset)
 */
function populateEditLicenseForm(formElement, licenseData = {}) {
  // Mapping from dataset keys to form field names
  const fieldMappings = {
    'licenseId': 'license_id',
    'licenseName': 'license_name',
    'licenseKey': 'license_key',
    'seatCount': 'seat_count',
    'productId': 'product_id',
    'licenseTypeId': 'license_type_id',
    'purchaseDate': 'purchase_date',
    'expireDate': 'expire_date',
    'cost': 'cost',
    'vendor': 'vendor',
    'notes': 'notes',
  };
  
  populateForm(formElement, licenseData, fieldMappings);
  
  // Special formatting for cost field after general population
  const costField = formElement.cost;
  if (costField && (licenseData.cost !== undefined && licenseData.cost !== null && String(licenseData.cost).trim() !== '')) {
    const numCost = parseFloat(licenseData.cost);
    if (!isNaN(numCost)) {
      costField.value = numCost.toFixed(2);
    }
  } else if (costField) {
    costField.value = '0.00'; // Set to 0.00 if empty or undefined
  }
}

/**
 * Opens the edit license modal with data from the selected license card
 * @param {HTMLElement} cardElement - The license card element
 */
function openEditLicenseModal(cardElement) {
  const formElement = document.getElementById('editLicenseForm');
  activeLicenseCardElement = cardElement;
  isLicenseFormEditable = false; // Initially in view mode

  populateEditLicenseForm(formElement, cardElement.dataset);
  setFormFieldsDisabled(formElement, true); // All fields disabled

  setText('editLicenseModalLabel', `License: ${cardElement.dataset.licenseName || 'Details'}`);
  const editBtn = document.getElementById('editLicenseFormBtn');
  const saveBtn = document.getElementById('saveLicenseBtn');
  showElement(editBtn); 
  setText(editBtn, 'Edit'); 
  editBtn.classList.remove('btn-warning');
  showElement('deleteLicenseBtn');
  if (saveBtn) saveBtn.disabled = true; 
  setText(saveBtn, 'Save Changes');
  
  showModal(editLicenseModalInstance);
}

/**
 * Opens the add license modal with default values
 */
function openAddLicenseModal() {
  const formElement = document.getElementById('addLicenseForm');
  if (formElement) {
    formElement.reset();
    const purchaseDateField = formElement.querySelector('#addPurchaseDateField');
    if (purchaseDateField) {
      // Set today's date as default for purchase date
      purchaseDateField.value = new Date().toISOString().split('T')[0];
    }
    const costField = formElement.querySelector('#addCostField');
    if (costField) costField.value = '0.00'; // Default value for cost
  }
  setFormFieldsDisabled(formElement, false); // Make all fields editable
  setText('addLicenseModalLabel', 'Add New License');
  showModal(addLicenseModalInstance);
}

/**
 * Prevents scientific notation in number inputs
 * @param {Event} event - The keydown event
 */
function preventScientificNotationOnKeydown(event) {
  if (['e', 'E', '+'].includes(event.key)) event.preventDefault();
  if (event.key === '-' && event.target.value.length > 0 && event.target.selectionStart > 0) event.preventDefault();
}

/**
 * Formats cost input to always show two decimal places
 * @param {Event} event - The blur event
 */
function formatCostOnBlur(event) {
  const numValue = parseFloat(event.target.value);
  if (!isNaN(numValue)) {
    event.target.value = numValue.toFixed(2);
  } else if (event.target.value.trim() !== '') {
    event.target.value = '0.00'; // For invalid input
  }
}

/**
 * Initializes the license management functionality
 */
export function initAdminLicenseManagement() {
  editLicenseModalInstance = initializeModal('editLicenseModal');
  addLicenseModalInstance = initializeModal('addLicenseModal');
  deleteLicenseConfirmModalInstance = initializeModal('deleteLicenseConfirmModal');

  document.querySelectorAll('.license-card .license-edit-btn').forEach(button => {
    button.addEventListener('click', (event) => {
      event.stopPropagation();
      openEditLicenseModal(button.closest('.license-card'));
    });
  });

  const addLicenseCardButton = document.getElementById('addLicenseBtn');
  if (addLicenseCardButton) {
    addLicenseCardButton.addEventListener('click', openAddLicenseModal);
  }
  
  document.querySelectorAll('input[name="cost"]').forEach(field => {
    field.addEventListener('keydown', preventScientificNotationOnKeydown);
    field.addEventListener('blur', formatCostOnBlur);
  });

  // Edit License Modal Logic
  const editFormButton = document.getElementById('editLicenseFormBtn');
  const saveFormButton = document.getElementById('saveLicenseBtn');
  const editForm = document.getElementById('editLicenseForm');

  if (editFormButton && saveFormButton && editForm) {
    editFormButton.addEventListener('click', () => {
      isLicenseFormEditable = !isLicenseFormEditable;
      setFormFieldsDisabled(editForm, !isLicenseFormEditable);
      saveFormButton.disabled = !isLicenseFormEditable;
      if (isLicenseFormEditable) {
        setText(editFormButton, 'Cancel'); 
        editFormButton.classList.add('btn-warning');
        editForm.license_name.focus();
      } else {
        setText(editFormButton, 'Edit'); 
        editFormButton.classList.remove('btn-warning');
        if (activeLicenseCardElement) {
          // Reset to card data
          populateEditLicenseForm(editForm, activeLicenseCardElement.dataset);
        }
      }
    });
  }

  if (editForm) {
    editForm.addEventListener('submit', (event) => {
      handleFormSubmit({
        event,
        formElement: editForm,
        itemId: editForm.license_id.value,
        baseUrl: '/license_management',
        methodOverride: 'PUT',
      });
    });
  }

  // Add License Modal Logic
  const addForm = document.getElementById('addLicenseForm');
  if (addForm) {
    addForm.addEventListener('submit', (event) => {
      handleFormSubmit({
        event,
        formElement: addForm,
        itemId: null, // No itemId for new licenses (POST)
        baseUrl: '/license_management',
      });
    });
  }

  // Delete License Logic
  const deleteButtonInModal = document.getElementById('deleteLicenseBtn');
  if (deleteButtonInModal) {
    deleteButtonInModal.addEventListener('click', () => {
      if (activeLicenseCardElement) {
        setText('deleteLicenseNameSpan', activeLicenseCardElement.dataset.licenseName || 'this license');
        showModal(deleteLicenseConfirmModalInstance);
      }
    });
  }

  const confirmDeleteBtn = document.getElementById('confirmLicenseDeleteBtn');
  if (confirmDeleteBtn) {
    confirmDeleteBtn.addEventListener('click', () => {
      if (activeLicenseCardElement && activeLicenseCardElement.dataset.licenseId) {
        handleDelete({
          itemId: activeLicenseCardElement.dataset.licenseId,
          baseUrl: '/license_management',
          modalToDeleteInstance: deleteLicenseConfirmModalInstance,
        });
      }
    });
  }
  
  // Reset Modals on close
  const editModalEl = document.getElementById('editLicenseModal');
  if (editModalEl) {
    editModalEl.addEventListener('hidden.bs.modal', () => {
      resetAndClearForm(document.getElementById('editLicenseForm'), populateEditLicenseForm, setFormFieldsDisabled);
      const editBtn = document.getElementById('editLicenseFormBtn');
      if (editBtn) { 
        setText(editBtn, 'Edit'); 
        editBtn.classList.remove('btn-warning'); 
      }
      const saveBtn = document.getElementById('saveLicenseBtn');
      if (saveBtn) saveBtn.disabled = true;
      activeLicenseCardElement = null;
      isLicenseFormEditable = false;
    });
  }
  
  const addModalEl = document.getElementById('addLicenseModal');
  if (addModalEl) {
    addModalEl.addEventListener('hidden.bs.modal', () => {
      resetAndClearForm(document.getElementById('addLicenseForm'));
    });
  }
}

