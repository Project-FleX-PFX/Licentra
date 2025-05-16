// frontend/public/js/features/admin/productManagementHandler.js
import {
    initializeModal, showModal, hideModal,
    setFormFieldsDisabled, populateForm, resetAndClearForm,
    handleFormSubmit, handleDelete,
    showElement, hideElement, setText
} from './adminUtils.js';

// Modul-spezifische Zustandsvariablen
// frontend/public/js/features/admin/productManagementHandler.js
// ... (Importe und temporäre Hilfsfunktionen wie zuvor) ...

let productModalInstance = null;
let deleteProductConfirmModalInstance = null;
let activeProductCardElement = null; // Wird auf null gesetzt, wenn "Add" geklickt wird
let isProductFormEditable = false; // Ist das Formular gerade editierbar?
let currentProductModalMode = 'view'; // 'add', 'view' (für existierendes Produkt), 'edit' (exist. Produkt wird editiert)


function populateProductForm(formElement, productData = {}, mode = 'add') {
    if (!formElement) return;
    formElement.reset(); // Beginnt mit dem Zurücksetzen auf HTML-Standardwerte

    // WICHTIG: ID-Feld explizit leeren, wenn es sich um den Add-Modus handelt oder keine Daten vorhanden sind
    formElement.product_id.value = (mode === 'add' || !productData.productId) ? '' : productData.productId;
    formElement.product_name.value = productData.productName || '';

    const licenseInfoContainer = document.getElementById('licenseInfoContainer');
    const licenseCountDisplay = document.getElementById('licenseCountDisplay');

    if (mode !== 'add' && productData.productId) { // Nur im View/Edit-Modus für existierende Produkte anzeigen
        if (licenseCountDisplay) licenseCountDisplay.textContent = productData.licenseCount || '0';
        if (licenseInfoContainer) licenseInfoContainer.style.display = 'block';
    } else { // Add-Modus
        if (licenseInfoContainer) licenseInfoContainer.style.display = 'none';
    }
}

function openProductModal(mode, cardElement = null) {
    const formElement = document.getElementById('productForm');
    const modalTitleElement = document.getElementById('productModalLabel');
    const editButton = document.getElementById('editProductBtn');
    const saveButton = document.getElementById('saveProductBtn');
    const deleteButton = document.getElementById('deleteProductBtn');

    currentProductModalMode = mode; // 'add' oder 'view'
    activeProductCardElement = (mode === 'add') ? null : cardElement; // WICHTIG: activeCardElement für Add zurücksetzen
    isProductFormEditable = (mode === 'add'); // Im Add-Modus ist das Formular direkt editierbar

    const cardData = cardElement ? cardElement.dataset : {};
    // cardData ist leer, wenn mode === 'add', da activeProductCardElement dann null ist
    populateProductForm(formElement, (mode === 'add' ? {} : cardData), mode);

    if (mode === 'add') {
        modalTitleElement.textContent = 'Add New Product';
        setFormFieldsDisabled(formElement, false, ['deleteProductBtn']); // Alles editierbar außer Delete
        if(editButton) editButton.style.display = 'none';
        if(deleteButton) deleteButton.style.display = 'none';
        if(saveButton) { saveButton.disabled = false; saveButton.textContent = 'Add Product'; }
        formElement.product_name.focus();
    } else { // 'view' mode für existierendes Produkt
        modalTitleElement.textContent = `Product: ${cardData.productName || 'Details'}`;
        setFormFieldsDisabled(formElement, true, ['editProductBtn', 'deleteProductBtn', 'saveProductBtn']);
        if(editButton) { editButton.style.display = 'inline-block'; editButton.textContent = 'Edit'; editButton.classList.remove('btn-warning');}
        if(deleteButton) deleteButton.style.display = 'inline-block';
        if(saveButton) { saveButton.disabled = true; saveButton.textContent = 'Save Changes'; }
    }
    showModal(productModalInstance);
}

export function initAdminProductManagement() {
    productModalInstance = initializeModal('productModal');
    deleteProductConfirmModalInstance = initializeModal('deleteProductConfirmModal');

    document.querySelectorAll('.product-card .product-edit-btn').forEach(button => {
        button.addEventListener('click', (event) => {
            event.stopPropagation();
            // Öffnet im 'view'-Modus, der User klickt dann auf 'Edit', um isProductFormEditable zu toggeln
            openProductModal('view', button.closest('.product-card'));
        });
    });

    const addProductButton = document.getElementById('addProductBtn');
    if (addProductButton) {
        addProductButton.addEventListener('click', () => {
            // Wichtig: Sicherstellen, dass der Zustand für "Add" sauber ist
            activeProductCardElement = null; // Keine aktive Karte beim Hinzufügen
            openProductModal('add');
        });
    }

    const editProductButton = document.getElementById('editProductBtn');
    const saveProductButton = document.getElementById('saveProductBtn');
    const productForm = document.getElementById('productForm');

    if (editProductButton && saveProductButton && productForm) {
        editProductButton.addEventListener('click', () => {
            isProductFormEditable = !isProductFormEditable; // Toggle den Bearbeitungszustand
            setFormFieldsDisabled(productForm, !isProductFormEditable, ['editProductBtn', 'deleteProductBtn', 'saveProductBtn']);
            saveProductButton.disabled = !isProductFormEditable;

            if (isProductFormEditable) {
                editProductButton.textContent = 'Cancel';
                editProductButton.classList.add('btn-warning');
                productForm.product_name.focus();
            } else { // Bearbeitung abbrechen
                editProductButton.textContent = 'Edit';
                editProductButton.classList.remove('btn-warning');
                // Wenn currentProductModalMode 'add' war und abgebrochen wird -> Modal schließen
                if (currentProductModalMode === 'add') {
                    hideModal(productModalInstance); 
                } else if (activeProductCardElement) {
                    // Formular auf Daten der aktiven Karte zurücksetzen (View-Modus)
                    populateProductForm(productForm, activeProductCardElement.dataset, 'view');
                }
            }
        });
    }

    if (productForm) {
        productForm.addEventListener('submit', async (event) => {
            event.preventDefault();
            if (!productForm.checkValidity()) {
                productForm.reportValidity();
                return;
            }

            const formData = new URLSearchParams();
            const formElementData = new FormData(productForm);
            formElementData.forEach((value, key) => formData.set(key, value));

            let url = '/product_management';
            let method = 'POST';
            // Entscheidend: Hole die product_id aus dem FormData-Objekt, nicht aus einer globalen Variable
            const productId = formElementData.get('product_id'); 

            if (productId && productId !== '') { // Wenn eine ID vorhanden ist -> Update
                url = `/product_management/${productId}`;
                method = 'PUT';
            }
            // Wenn keine ID vorhanden (Feld ist leer), bleibt es POST an /product_management

            try {
                await fetch(url, { method: method, headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: formData.toString() });
                hideModal(productModalInstance);
                window.location.reload();
            } catch (error) {
                console.error('Product form submission error:', error);
                alert('A network error occurred. Please try again.');
            }
        });
    }

    // Delete Logic (bleibt ähnlich)
    const deleteProductButtonInModal = document.getElementById('deleteProductBtn');
    if (deleteProductButtonInModal) {
        deleteProductButtonInModal.addEventListener('click', () => {
            if (activeProductCardElement && activeProductCardElement.dataset.productId) {
                const productName = activeProductCardElement.dataset.productName || "this product";
                document.getElementById('deleteProductNameSpan').textContent = productName;
                showModal(deleteProductConfirmModalInstance);
            } else {
                console.warn("Cannot delete: No active product card element or product ID found.");
            }
        });
    }

    const confirmProductDeleteActualButton = document.getElementById('confirmProductDeleteBtn');
    if (confirmProductDeleteActualButton) {
        confirmProductDeleteActualButton.addEventListener('click', async () => {
            if (activeProductCardElement && activeProductCardElement.dataset.productId) {
                const productId = activeProductCardElement.dataset.productId;
                try {
                    await fetch(`/product_management/${productId}`, { method: 'DELETE' });
                    hideModal(deleteProductConfirmModalInstance);
                    hideModal(productModalInstance); // Auch das Hauptmodal schließen
                    window.location.reload();
                } catch (error) {
                    console.error('Error deleting product:', error);
                    alert('A network error occurred while trying to delete the product.');
                }
            }
        });
    }
    
    // Reset Modal on close
    const productModalElement = document.getElementById('productModal');
    if(productModalElement) {
        productModalElement.addEventListener('hidden.bs.modal', function () {
            const form = document.getElementById('productForm');
            if (form) {
                // Formular immer auf den "Add"-Zustand zurücksetzen (leer, editierbar)
                // oder besser: auf einen definierten initialen Leerzustand
                populateProductForm(form, {}, 'add'); // Setzt ID auf leer etc.
                setFormFieldsDisabled(form, true, ['editProductBtn', 'deleteProductBtn', 'saveProductBtn']); // Sperrt Felder
            }
            const editBtn = document.getElementById('editProductBtn');
            if(editBtn) { editBtn.textContent = 'Edit'; editBtn.classList.remove('btn-warning'); }
            const saveBtn = document.getElementById('saveProductBtn');
            if(saveBtn) saveBtn.disabled = true;
            
            activeProductCardElement = null;
            isProductFormEditable = false;
            currentProductModalMode = 'view'; // Zurück zum Standard
        });
    }
}

