// frontend/public/js/features/admin/productManagementHandler.js
import {
  initializeModal,
  showModal,
  hideModal,
  setText,
  showElement,
  hideElement,
} from './adminUtils.js';

let productModalInstance = null;
let deleteProductConfirmModalInstance = null;
let activeProductCardElement = null;
let currentProductId = null;

function populateProductFormAndModal(
    formElement,
    productData = {},
    mode = 'add',
) {
  if (!formElement) return;
  formElement.reset();

  const modalTitleElement = document.getElementById('productModalLabel');
  const editButton = document.getElementById('editProductBtnInModal');
  const saveButton = document.getElementById('saveProductBtnInModal');
  const deleteButton = document.getElementById('deleteProductBtnInModal');
  const formMethodField = document.getElementById('formMethodField');
  const licenseInfoContainer = document.getElementById('licenseInfoContainer');
  const licenseCountDisplay = document.getElementById('licenseCountDisplay');
  const productNameField = formElement.elements['product[product_name]'];

  currentProductId = productData.productId || null;
  productNameField.value = productData.productName || '';

  if (mode === 'add') {
    setText(modalTitleElement, 'Add New Product');
    formElement.action = '/admin/products';
    formMethodField.value = '';
    productNameField.disabled = false;
    hideElement(editButton);
    hideElement(deleteButton);
    showElement(saveButton);
    saveButton.disabled = false;
    setText(saveButton, 'Add Product');
    hideElement(licenseInfoContainer);
    productNameField.focus();
  } else {
    setText(
        modalTitleElement,
        `Product: ${productData.productName || 'Details'}`,
    );
    formElement.action = `/admin/products/${currentProductId}`;
    formMethodField.value = 'PATCH';
    productNameField.disabled = true;
    showElement(editButton);
    setText(editButton, 'Edit');
    editButton.classList.remove('btn-warning');
    showElement(deleteButton);
    showElement(saveButton);
    saveButton.disabled = true;
    setText(saveButton, 'Save Changes');

    if (
        productData.licenseCount !== undefined &&
        productData.licenseCount !== null
    ) {
      setText(licenseCountDisplay, productData.licenseCount);
      showElement(licenseInfoContainer);
    } else {
      hideElement(licenseInfoContainer);
    }
  }
}

function toggleEditModeProductForm() {
  const formElement = document.getElementById('productForm');
  const editButton = document.getElementById('editProductBtnInModal');
  const saveButton = document.getElementById('saveProductBtnInModal');
  const productNameField = formElement.elements['product[product_name]'];
  const currentlyEditable = !productNameField.disabled;

  productNameField.disabled = currentlyEditable;
  saveButton.disabled = currentlyEditable;

  if (!currentlyEditable) {
    setText(editButton, 'Cancel');
    editButton.classList.add('btn-warning');
    productNameField.focus();
  } else {
    setText(editButton, 'Edit');
    editButton.classList.remove('btn-warning');
    if (
        activeProductCardElement &&
        activeProductCardElement.dataset.productId
    ) {
      populateProductFormAndModal(
          formElement,
          activeProductCardElement.dataset,
          'view',
      );
    }
  }
}

async function handleProductFormSubmit(event) {
  event.preventDefault();
  const form = event.target;
  const productNameInput = form.elements['product[product_name]'];

  if (!productNameInput.value || productNameInput.value.trim() === '') {
    productNameInput.focus();
    return;
  }

  const formData = new FormData(form);
  const method = form.elements.formMethodField.value === 'PATCH' ? 'PATCH' : 'POST';
  const url = form.action;

  const saveButton = document.getElementById('saveProductBtnInModal');
  if (saveButton) {
    saveButton.disabled = true;
    setText(saveButton, 'Saving...');
  }

  try {
    await fetch(url, {
      method,
      body: new URLSearchParams(formData),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
      },
    });

    window.location.reload();
  } catch (error) {
    console.error('Form submission error:', error);
    window.location.reload();
  }
}

async function handleDeleteProductFormSubmit(event) {
  event.preventDefault();
  const form = event.target;
  const url = form.action;

  const confirmDeleteButton = form.querySelector('button[type="submit"]');
  if (confirmDeleteButton) {
    confirmDeleteButton.disabled = true;
    setText(confirmDeleteButton, 'Deleting...');
  }

  try {
    await fetch(url, {
      method: 'POST',
      body: new URLSearchParams(new FormData(form)),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
      },
    });

    window.location.reload();
  } catch (error) {
    console.error('Delete submission error:', error);
    window.location.reload();
  }
}

export function initAdminProductManagement() {
  productModalInstance = initializeModal('productModal');
  deleteProductConfirmModalInstance = initializeModal('deleteProductConfirmModal');

  const addProductCard = document.getElementById('addProductCard');
  if (addProductCard) {
    addProductCard.addEventListener('click', () => {
      activeProductCardElement = null;
      const form = document.getElementById('productForm');
      populateProductFormAndModal(form, {}, 'add');
      showModal(productModalInstance);
    });
  }

  document.querySelectorAll('.product-configure-btn').forEach((button) => {
    button.addEventListener('click', (event) => {
      event.stopPropagation();
      activeProductCardElement = button.closest('.product-card');
      const form = document.getElementById('productForm');
      populateProductFormAndModal(
          form,
          activeProductCardElement.dataset,
          'view',
      );
      showModal(productModalInstance);
    });
  });

  const editButtonInModal = document.getElementById('editProductBtnInModal');
  if (editButtonInModal) {
    editButtonInModal.addEventListener('click', toggleEditModeProductForm);
  }

  const productFormElement = document.getElementById('productForm');
  if (productFormElement) {
    productFormElement.addEventListener('submit', handleProductFormSubmit);
  }

  const deleteButtonInMainModal = document.getElementById('deleteProductBtnInModal');
  if (deleteButtonInMainModal) {
    deleteButtonInMainModal.addEventListener('click', () => {
      if (currentProductId && activeProductCardElement) {
        setText(
            document.getElementById('deleteProductNameSpan'),
            activeProductCardElement.dataset.productName || 'this product',
        );
        const deleteForm = document.getElementById('deleteProductForm');
        if (deleteForm) {
          deleteForm.action = `/admin/products/${currentProductId}`;
        }
        showModal(deleteProductConfirmModalInstance);
      }
    });
  }

  const deleteProductFormElement = document.getElementById('deleteProductForm');
  if (deleteProductFormElement) {
    deleteProductFormElement.addEventListener('submit', handleDeleteProductFormSubmit);
  }

  const productModalElement = document.getElementById('productModal');
  if (productModalElement) {
    productModalElement.addEventListener('hidden.bs.modal', () => {
      const form = document.getElementById('productForm');
      if (form) {
        populateProductFormAndModal(form, {}, 'add');
      }
      activeProductCardElement = null;
      currentProductId = null;
      const editButton = document.getElementById('editProductBtnInModal');
      if (editButton) {
        setText(editButton, 'Edit');
        editButton.classList.remove('btn-warning');
      }
    });
  }
}
