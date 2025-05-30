// frontend/public/js/features/admin/licenseManagementHandler.js
import {
  initializeModal,
  showModal,
  hideModal,
  setText,
  showElement,
  hideElement,
} from "./adminUtils.js";

let editLicenseModalInstance = null;
let addLicenseModalInstance = null;
let deleteLicenseConfirmModalInstance = null;

let currentLicenseDataForEdit = {};
let currentLicenseId = null;

const CURRENCY_SYMBOLS = {
  EUR: "€",
  USD: "$",
};

function updateCostCurrencySymbol(modalPrefix, selectedCurrency) {
  const symbolElement = document.getElementById(
    `${modalPrefix}CostCurrencySymbol`
  );
  if (symbolElement) {
    symbolElement.textContent =
      CURRENCY_SYMBOLS[selectedCurrency] || selectedCurrency;
  }
}

function populateEditLicenseForm(formElement, licenseData) {
  formElement.reset();

  const fieldMap = {
    licenseName: "editLicenseNameField",
    licenseKey: "editLicenseKeyField",
    seatCount: "editSeatCountField",
    productId: "editProductIdField",
    licenseTypeId: "editLicenseTypeIdField",
    purchaseDate: "editPurchaseDateField",
    expireDate: "editExpireDateField",
    cost: "editCostField",
    currency: "editCurrencyField",
    vendor: "editVendorField",
    notes: "editNotesField",
  };

  for (const dataKey in licenseData) {
    if (fieldMap[dataKey]) {
      const fieldId = fieldMap[dataKey];
      const field = document.getElementById(fieldId);
      if (field) {
        if (field.type === "date" && !licenseData[dataKey]) {
          field.value = "";
        } else if (dataKey === "cost") {
          const numCost = parseFloat(licenseData[dataKey]);
          field.value = isNaN(numCost) ? "" : numCost.toFixed(2);
        } else if (dataKey === "currency") {
          field.value = licenseData[dataKey] || "EUR";
          updateCostCurrencySymbol("edit", field.value);
        } else {
          field.value = licenseData[dataKey] || "";
        }
      }
    }
  }

  const currencyField = document.getElementById("editCurrencyField");
  if (currencyField && !currencyField.value) {
    currencyField.value = "EUR";
    updateCostCurrencySymbol("edit", "EUR");
  }

  const costField = document.getElementById("editCostField");
  if (costField && costField.value === "") costField.value = "0.00";

  currentLicenseDataForEdit = { ...licenseData };
  if (currencyField) currentLicenseDataForEdit.currency = currencyField.value;
}

function setEditFormDisabledState(disabled) {
  const form = document.getElementById("editLicenseForm");
  const fieldsToToggle = [
    "license[license_name]",
    "license[license_key]",
    "license[seat_count]",
    "license[product_id]",
    "license[license_type_id]",
    "license[purchase_date]",
    "license[expire_date]",
    "license[cost]",
    "license[currency]",
    "license[vendor]",
    "license[notes]",
  ];
  fieldsToToggle.forEach((name) => {
    const field = form.elements[name];
    if (field) field.disabled = disabled;
  });
  document.getElementById("saveLicenseChangesBtn").disabled = disabled;
}

function openEditLicenseModal(cardElement) {
  const licenseData = cardElement.dataset;
  currentLicenseId = licenseData.licenseId;
  const form = document.getElementById("editLicenseForm");

  setText(
    "editLicenseModalLabel",
    `License: ${licenseData.licenseName || "Details"}`
  );
  populateEditLicenseForm(form, licenseData);
  setEditFormDisabledState(true);

  setText("editLicenseToggleBtn", "Edit");
  document
    .getElementById("editLicenseToggleBtn")
    .classList.remove("btn-warning");
  showElement("deleteLicenseBtnInModal");
  document.getElementById("saveLicenseChangesBtn").disabled = true;

  showModal(editLicenseModalInstance);
}

function openAddLicenseModal() {
  const form = document.getElementById("addLicenseForm");
  form.reset();
  document.getElementById("addSeatCountField").value = "1";
  document.getElementById("addPurchaseDateField").value = new Date()
    .toISOString()
    .split("T")[0];
  document.getElementById("addCostField").value = "0.00";
  document.getElementById("addCurrencyField").value = "EUR";
  updateCostCurrencySymbol("add", "EUR");

  document.getElementById("addLicenseTypeIdField").selectedIndex = 0;

  showModal(addLicenseModalInstance);
}

async function handleLicenseFormSubmit(event, formType) {
  event.preventDefault();
  const form = event.target;
  const formData = new FormData(form);
  let url, method;

  const saveButton =
    formType === "add"
      ? document.getElementById("createLicenseSubmitBtn")
      : document.getElementById("saveLicenseChangesBtn");

  if (saveButton) {
    saveButton.disabled = true;
    setText(saveButton, "Saving...");
  }

  if (formType === "add") {
    url = "/admin/licenses";
    method = "POST";
  } else {
    if (!currentLicenseId) {
      console.error("No currentLicenseId for edit.");
      if (saveButton) {
        saveButton.disabled = false;
        setText(saveButton, "Save Changes");
      }
      return;
    }
    url = `/admin/licenses/${currentLicenseId}`;
    method = "POST";
    formData.append("_method", "PATCH");
  }

  try {
    await fetch(url, {
      method: "POST",
      body: new URLSearchParams(formData),
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          ?.content,
      },
    });

    window.location.reload();
  } catch (error) {
    console.error("Form submission error:", error);
    window.location.reload();
  }
}

async function handleDeleteLicenseFormSubmit(event) {
  event.preventDefault();
  const form = event.target;
  const url = form.action;

  const confirmDeleteButton = form.querySelector('button[type="submit"]');
  if (confirmDeleteButton) {
    confirmDeleteButton.disabled = true;
    setText(confirmDeleteButton, "Deleting...");
  }

  try {
    await fetch(url, {
      method: "POST",
      body: new URLSearchParams(new FormData(form)),
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          ?.content,
      },
    });

    window.location.reload();
  } catch (error) {
    console.error("Delete submission error:", error);
    window.location.reload();
  }
}

export function initAdminLicenseManagement() {
  editLicenseModalInstance = initializeModal("editLicenseModal");
  addLicenseModalInstance = initializeModal("addLicenseModal");
  deleteLicenseConfirmModalInstance = initializeModal(
    "deleteLicenseConfirmModal"
  );

  document.querySelectorAll(".license-configure-btn").forEach((button) => {
    button.addEventListener("click", (event) => {
      event.stopPropagation();
      openEditLicenseModal(button.closest(".license-card"));
    });
  });

  const addLicenseCard = document.getElementById("addLicenseCardBtn");
  if (addLicenseCard) {
    addLicenseCard.addEventListener("click", openAddLicenseModal);
  }

  const editToggleButton = document.getElementById("editLicenseToggleBtn");
  if (editToggleButton) {
    editToggleButton.addEventListener("click", () => {
      const editLicenseForm = document.getElementById("editLicenseForm");
      const isCurrentlyEditable =
        !editLicenseForm.elements["license[license_name]"].disabled;
      setEditFormDisabledState(isCurrentlyEditable);
      if (!isCurrentlyEditable) {
        setText(editToggleButton, "Cancel");
        editToggleButton.classList.add("btn-warning");
        editLicenseForm.elements["license[license_name]"].focus();
      } else {
        setText(editToggleButton, "Edit");
        editToggleButton.classList.remove("btn-warning");
        populateEditLicenseForm(editLicenseForm, currentLicenseDataForEdit);
      }
    });
  }

  const addLicenseForm = document.getElementById("addLicenseForm");
  if (addLicenseForm) {
    addLicenseForm.addEventListener("submit", (event) =>
      handleLicenseFormSubmit(event, "add")
    );
  }

  const editLicenseForm = document.getElementById("editLicenseForm");
  if (editLicenseForm) {
    editLicenseForm.addEventListener("submit", (event) =>
      handleLicenseFormSubmit(event, "edit")
    );
  }

  const deleteBtnInEditModal = document.getElementById(
    "deleteLicenseBtnInModal"
  );
  if (deleteBtnInEditModal) {
    deleteBtnInEditModal.addEventListener("click", () => {
      if (currentLicenseId && currentLicenseDataForEdit.licenseName) {
        setText("deleteLicenseNameSpan", currentLicenseDataForEdit.licenseName);
        const deleteForm = document.getElementById("deleteLicenseForm");
        if (deleteForm)
          deleteForm.action = `/admin/licenses/${currentLicenseId}`;
        showModal(deleteLicenseConfirmModalInstance);
      }
    });
  }

  const deleteLicenseForm = document.getElementById("deleteLicenseForm");
  if (deleteLicenseForm) {
    deleteLicenseForm.addEventListener("submit", handleDeleteLicenseFormSubmit);
  }

  const addCurrencySelect = document.getElementById("addCurrencyField");
  if (addCurrencySelect) {
    addCurrencySelect.addEventListener("change", (event) => {
      updateCostCurrencySymbol("add", event.target.value);
    });
  }
  const editCurrencySelect = document.getElementById("editCurrencyField");
  if (editCurrencySelect) {
    editCurrencySelect.addEventListener("change", (event) => {
      updateCostCurrencySymbol("edit", event.target.value);
    });
  }

  const editModalElement = document.getElementById("editLicenseModal");
  if (editModalElement) {
    editModalElement.addEventListener("hidden.bs.modal", () => {
      document.getElementById("editLicenseForm").reset();
      setEditFormDisabledState(true);
      setText("editLicenseToggleBtn", "Edit");
      document
        .getElementById("editLicenseToggleBtn")
        .classList.remove("btn-warning");
      updateCostCurrencySymbol("edit", "EUR");
      currentLicenseDataForEdit = {};
      currentLicenseId = null;
    });
  }
  const addModalElement = document.getElementById("addLicenseModal");
  if (addModalElement) {
    addModalElement.addEventListener("hidden.bs.modal", () => {
      document.getElementById("addLicenseForm").reset();
      updateCostCurrencySymbol("add", "EUR");
    });
  }

  document.querySelectorAll('input[name="license[cost]"]').forEach((field) => {
    field.addEventListener("keydown", (event) => {
      if (
        ["e", "E", "+", "-"].includes(event.key) &&
        event.target.value.includes(event.key) &&
        event.key !== "-"
      ) {
        event.preventDefault();
      } else if (["e", "E", "+"].includes(event.key)) {
        event.preventDefault();
      }
    });
    field.addEventListener("blur", (event) => {
      const numValue = parseFloat(event.target.value);
      if (!isNaN(numValue)) {
        event.target.value = numValue.toFixed(2);
      } else if (event.target.value.trim() === "") {
        event.target.value = "";
      }
    });
  });
}
