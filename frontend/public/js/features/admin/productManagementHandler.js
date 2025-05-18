// frontend/public/js/features/admin/productManagementHandler.js
import {
  initializeModal, showModal, hideModal,
  setFormFieldsDisabled, populateForm, resetAndClearForm,
  handleFormSubmit, handleDelete,
  showElement, hideElement, setText,
} from './adminUtils.js';

// Module-specific state variables
let productModalInstance = null;
let deleteProductConfirmModalInstance = null;
let activeProductCardElement = null;
let isProductFormEditable = false;
let currentProductModalMode = 'view'; // 'add', 'view', 'edit'

/**
 * Populates the product form with data
 * @param {HTMLFormElement} formElement - The form element to populate
 * @param {Object} productData - Product data object (usually from dataset)
 * @param {string} mode - 'add', 'view', or 'edit'
 */
function populateProductForm(formElement, productData = {}, mode = 'add') {
  if (!formElement) return;
  formElement.reset();

  // Explicitly clear ID field in add mode or if no data is provided
  formElement.product_id.value = (mode === 'add' || !productData.productId) ? '' : productData.productId;
  formElement.product_name.value = productData.productName || '';

  const licenseInfoContainer = document.getElementById('licenseInfoContainer');
  const licenseCountDisplay = document.getElementById('licenseCountDisplay');

  if (mode !== 'add' && productData.productId) {
    // Only show license count for existing products
    if (licenseCountDisplay) licenseCountDisplay.textContent = productData.licenseCount || '0';
    if (licenseInfoContainer) licenseInfoContainer.style.display = 'block';
  } else {
    // Hide license info in add mode
    if (licenseInfoContainer) licenseInfoContainer.style.display = 'none';
  }
}

/**
 * Opens the product modal in the specified mode
 * @param {string} mode - 'add' or 'view'
 * @param {HTMLElement} cardElement - The product card element (null for add mode)
 */
function openProductModal(mode, cardElement = null) {
  const formElement = document.getElementById('productForm');
  const modalTitleElement = document.getElementById('productModalLabel');
  const editButton = document.getElementById('editProductBtn');
  const saveButton = document.getElementById('saveProductBtn');
  const deleteButton = document.getElementById('deleteProductBtn');

  currentProductModalMode = mode;
  activeProductCardElement = (mode === 'add') ? null : cardElement;
  isProductFormEditable = (mode === 'add');

  const cardData = cardElement ? cardElement.dataset : {};
  populateProductForm(formElement, (mode === 'add' ? {} : cardData), mode);

  if (mode === 'add') {
    setText(modalTitleElement, 'Add New Product');
    setFormFieldsDisabled(formElement, false, ['deleteProductBtn']);
    if (editButton) editButton.style.display = 'none';
    if (deleteButton) deleteButton.style.display = 'none';
    if (saveButton) {
      saveButton.disabled = false;
      setText(saveButton, 'Add Product');
    }
    formElement.product_name.focus();
  } else {
    // 'view' mode for existing product
    setText(modalTitleElement, `Product: ${cardData.productName || 'Details'}`);
    setFormFieldsDisabled(formElement, true, ['editProductBtn', 'deleteProductBtn', 'saveProductBtn']);
    if (editButton) {
      editButton.style.display = 'inline-block';
      setText(editButton, 'Edit');
      editButton.classList.remove('btn-warning');
    }
    if (deleteButton) deleteButton.style.display = 'inline-block';
    if (saveButton) {
      saveButton.disabled = true;
      setText(saveButton, 'Save Changes');
    }
  }
  showModal(productModalInstance);
}

/**
 * Initializes the product management functionality
 */
export function initAdminProductManagement() {
  productModalInstance = initializeModal('productModal');
  deleteProductConfirmModalInstance = initializeModal('deleteProductConfirmModal');

  document.querySelectorAll('.product-card .product-edit-btn').forEach(button => {
    button.addEventListener('click', (event) => {
      event.stopPropagation();
      // Open in 'view' mode, user clicks 'Edit' to toggle isProductFormEditable
      openProductModal('view', button.closest('.product-card'));
    });
  });

  const addProductButton = document.getElementById('addProductBtn');
  if (addProductButton) {
    addProductButton.addEventListener('click', () => {
      // Ensure clean state for adding a new product
      activeProductCardElement = null;
      openProductModal('add');
    });
  }

  const editProductButton = document.getElementById('editProductBtn');
  const saveProductButton = document.getElementById('saveProductBtn');
  const productForm = document.getElementById('productForm');

  if (editProductButton && saveProductButton && productForm) {
    editProductButton.addEventListener('click', () => {
      isProductFormEditable = !isProductFormEditable;
      setFormFieldsDisabled(productForm, !isProductFormEditable, ['editProductBtn', 'deleteProductBtn', 'saveProductBtn']);
      saveProductButton.disabled = !isProductFormEditable;

      if (isProductFormEditable) {
        setText(editProductButton, 'Cancel');
        editProductButton.classList.add('btn-warning');
        productForm.product_name.focus();
      } else {
        // Cancel editing
        setText(editProductButton, 'Edit');
        editProductButton.classList.remove('btn-warning');
        
        // If canceling in add mode, close modal
        if (currentProductModalMode === 'add') {
          hideModal(productModalInstance);
        } else if (activeProductCardElement) {
          // Reset form to active card data (view mode)
          populateProductForm(productForm, activeProductCardElement.dataset, 'view');
        }
      }
    });
  }

  if (productForm) {
    productForm.addEventListener('submit', (event) => {
      handleFormSubmit({
        event,
        formElement: productForm,
        itemId: productForm.product_id.value,
        baseUrl: '/product_management',
      });
    });
  }

  // Delete product functionality
  const deleteProductButtonInModal = document.getElementById('deleteProductBtn');
  if (deleteProductButtonInModal) {
    deleteProductButtonInModal.addEventListener('click', () => {
      if (activeProductCardElement && activeProductCardElement.dataset.productId) {
        const productName = activeProductCardElement.dataset.productName || 'this product';
        setText('deleteProductNameSpan', productName);
        showModal(deleteProductConfirmModalInstance);
      }
    });
  }

  const confirmProductDeleteBtn = document.getElementById('confirmProductDeleteBtn');
  if (confirmProductDeleteBtn) {
    confirmProductDeleteBtn.addEventListener('click', () => {
      if (activeProductCardElement && activeProductCardElement.dataset.productId) {
        handleDelete({
          itemId: activeProductCardElement.dataset.productId,
          baseUrl: '/product_management',
          modalToDeleteInstance: deleteProductConfirmModalInstance,
        });
        hideModal(productModalInstance);
      }
    });
  }
  
  // Reset modal state when closed
  const productModalElement = document.getElementById('productModal');
  if (productModalElement) {
    productModalElement.addEventListener('hidden.bs.modal', () => {
      const form = document.getElementById('productForm');
      if (form) {
        // Reset form to empty state
        populateProductForm(form, {}, 'add');
        setFormFieldsDisabled(form, true, ['editProductBtn', 'deleteProductBtn', 'saveProductBtn']);
      }
      
      const editBtn = document.getElementById('editProductBtn');
      if (editBtn) {
        setText(editBtn, 'Edit');
        editBtn.classList.remove('btn-warning');
      }
      
      const saveBtn = document.getElementById('saveProductBtn');
      if (saveBtn) saveBtn.disabled = true;
      
      activeProductCardElement = null;
      isProductFormEditable = false;
      currentProductModalMode = 'view';
    });
  }
}

