// frontend/public/js/features/admin/licenseManagementHandler.js
import {
    initializeModal, showModal, hideModal,
    setFormFieldsDisabled, populateForm, resetAndClearForm,
    handleFormSubmit, handleDelete,
    setText, showElement
} from './adminUtils.js';

// Modul-spezifische Variablen
let editLicenseModalInstance = null;
let addLicenseModalInstance = null;
let deleteLicenseConfirmModalInstance = null;
let activeLicenseCardElement = null;
let isLicenseFormEditable = false;

// Spezifische Funktion zum Befüllen des Lizenzformulars (Edit-Modus)
function populateEditLicenseForm(formElement, licenseData = {}) {
    // Mapping von dataset-Keys (camelCase oder wie im HTML) zu Formularfeldnamen
    const fieldMappings = {
        // dataset key (oft camelCase) : form field name/id
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
    
    // Debugging: Prüfen, welche Daten tatsächlich ankommen
    console.log("License data to populate:", licenseData);
    console.log("Field mappings:", fieldMappings);
    
    populateForm(formElement, licenseData, fieldMappings); // Generische Funktion nutzen
    
    // Spezifische Formatierung für das Kostenfeld NACH dem allgemeinen Befüllen
    const costField = formElement.cost;
    if (costField && (licenseData.cost !== undefined && licenseData.cost !== null && String(licenseData.cost).trim() !== '')) {
        const numCost = parseFloat(licenseData.cost);
        if (!isNaN(numCost)) {
            costField.value = numCost.toFixed(2);
        }
    } else if (costField) {
        costField.value = "0.00"; // Setze auf 0.00 wenn leer oder undefiniert
    }
}

function openEditLicenseModal(cardElement) {
    const formElement = document.getElementById('editLicenseForm');
    activeLicenseCardElement = cardElement;
    isLicenseFormEditable = false; // Initial im View-Modus

    populateEditLicenseForm(formElement, cardElement.dataset);
    setFormFieldsDisabled(formElement, true); // Alles gesperrt

    setText('editLicenseModalLabel', `License: ${cardElement.dataset.licenseName || 'Details'}`);
    const editBtn = document.getElementById('editLicenseFormBtn');
    const saveBtn = document.getElementById('saveLicenseBtn');
    showElement(editBtn); setText(editBtn, 'Edit'); editBtn.classList.remove('btn-warning');
    showElement('deleteLicenseBtn');
    if(saveBtn) saveBtn.disabled = true; setText(saveBtn, 'Save Changes');
    
    showModal(editLicenseModalInstance);
}

function openAddLicenseModal() {
    const formElement = document.getElementById('addLicenseForm');
    if (formElement) {
        formElement.reset(); // Standard-Reset
        const purchaseDateField = formElement.querySelector('#addPurchaseDateField'); // ID aus HTML
        if (purchaseDateField) { // Heutiges Datum als Standard für Kaufdatum
            purchaseDateField.value = new Date().toISOString().split('T')[0];
        }
        const costField = formElement.querySelector('#addCostField'); // ID aus HTML
        if (costField) costField.value = "0.00"; // Standardwert für Kosten
    }
    setFormFieldsDisabled(formElement, false); // Alle Felder editierbar machen
    setText('addLicenseModalLabel', 'Add New License');
    showModal(addLicenseModalInstance);
}

function preventScientificNotationOnKeydown(event) {
    if (["e", "E", "+"].includes(event.key)) event.preventDefault();
    if (event.key === "-" && event.target.value.length > 0 && event.target.selectionStart > 0) event.preventDefault();
}

function formatCostOnBlur(event) {
    const numValue = parseFloat(event.target.value);
    if (!isNaN(numValue)) {
        event.target.value = numValue.toFixed(2);
    } else if (event.target.value.trim() !== '') {
        event.target.value = "0.00"; // Bei ungültiger Eingabe
    }
}

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

    // --- Edit License Modal Logic ---
    const editFormButton = document.getElementById('editLicenseFormBtn');
    const saveFormButton = document.getElementById('saveLicenseBtn');
    const editForm = document.getElementById('editLicenseForm');

    if (editFormButton && saveFormButton && editForm) {
        editFormButton.addEventListener('click', () => {
            isLicenseFormEditable = !isLicenseFormEditable;
            setFormFieldsDisabled(editForm, !isLicenseFormEditable);
            saveFormButton.disabled = !isLicenseFormEditable;
            if (isLicenseFormEditable) {
                setText(editFormButton, 'Cancel'); editFormButton.classList.add('btn-warning');
                editForm.license_name.focus();
            } else {
                setText(editFormButton, 'Edit'); editFormButton.classList.remove('btn-warning');
                if (activeLicenseCardElement) { // Reset auf Kartendaten
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
                itemId: editForm.license_id.value, // license_id ist der Name des Hidden-Fields
                baseUrl: '/license_management',
                methodOverride: 'PUT' // Da HTML-Forms kein PUT unterstützen, nutzen wir POST + _method oder interpretieren es serverseitig
            });
        });
    }

    // --- Add License Modal Logic ---
    const addForm = document.getElementById('addLicenseForm');
    if (addForm) {
        addForm.addEventListener('submit', (event) => {
            handleFormSubmit({
                event,
                formElement: addForm,
                itemId: null, // Kein itemId für neue Lizenzen (POST)
                baseUrl: '/license_management'
            });
        });
    }

    // --- Delete License Logic ---
    const deleteButtonInModal = document.getElementById('deleteLicenseBtn');
    if (deleteButtonInModal) {
        deleteButtonInModal.addEventListener('click', () => {
            if (activeLicenseCardElement) {
                setText('deleteLicenseNameSpan', activeLicenseCardElement.dataset.licenseName || "this license");
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
                    modalToDeleteInstance: deleteLicenseConfirmModalInstance
                });
            }
        });
    }
    
    // Reset Modals on close
    const editModalEl = document.getElementById('editLicenseModal');
    if(editModalEl) {
        editModalEl.addEventListener('hidden.bs.modal', () => {
            resetAndClearForm(document.getElementById('editLicenseForm'), populateEditLicenseForm, setFormFieldsDisabled);
            const editBtn = document.getElementById('editLicenseFormBtn');
            if(editBtn) { setText(editBtn, 'Edit'); editBtn.classList.remove('btn-warning'); }
            const saveBtn = document.getElementById('saveLicenseBtn');
            if(saveBtn) saveBtn.disabled = true;
            activeLicenseCardElement = null;
            isLicenseFormEditable = false;
        });
    }
    const addModalEl = document.getElementById('addLicenseModal');
    if(addModalEl) {
        addModalEl.addEventListener('hidden.bs.modal', () => {
            resetAndClearForm(document.getElementById('addLicenseForm'));
        });
    }
}

