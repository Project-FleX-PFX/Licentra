// frontend/public/js/features/admin/productManagementHandler.js
import {
  initializeModal,
  showModal,
  hideModal,
  setText,
  showElement,
  hideElement,
} from "./adminUtils.js";

let productModalInstance = null;
let deleteProductConfirmModalInstance = null;
let activeProductCardElement = null;
let currentProductId = null;

function populateProductFormAndModal(
  formElement,
  productData = {},
  mode = "add"
) {
  if (!formElement) return;
  formElement.reset();

  const modalTitleElement = document.getElementById("productModalLabel");
  const editButton = document.getElementById("editProductBtnInModal");
  const saveButton = document.getElementById("saveProductBtnInModal");
  const deleteButton = document.getElementById("deleteProductBtnInModal");
  const formMethodField = document.getElementById("formMethodField");
  const licenseInfoContainer = document.getElementById("licenseInfoContainer");
  const licenseCountDisplay = document.getElementById("licenseCountDisplay");
  const productNameField = formElement.elements["product[product_name]"];

  currentProductId = productData.productId || null;
  productNameField.value = productData.productName || "";

  if (mode === "add") {
    setText(modalTitleElement, "Add New Product");
    formElement.action = "/admin/products";
    formMethodField.value = ""; // POST
    productNameField.disabled = false;
    hideElement(editButton);
    hideElement(deleteButton);
    showElement(saveButton);
    saveButton.disabled = false;
    setText(saveButton, "Add Product");
    hideElement(licenseInfoContainer);
    productNameField.focus();
  } else {
    setText(
      modalTitleElement,
      `Product: ${productData.productName || "Details"}`
    );
    formElement.action = `/admin/products/${currentProductId}`;
    formMethodField.value = "PATCH";
    productNameField.disabled = true;
    showElement(editButton);
    setText(editButton, "Edit");
    editButton.classList.remove("btn-warning");
    showElement(deleteButton);
    showElement(saveButton);
    saveButton.disabled = true;
    setText(saveButton, "Save Changes");

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
  const formElement = document.getElementById("productForm");
  const editButton = document.getElementById("editProductBtnInModal");
  const saveButton = document.getElementById("saveProductBtnInModal");
  const productNameField = formElement.elements["product[product_name]"];
  const currentlyEditable = !productNameField.disabled;

  productNameField.disabled = currentlyEditable;
  saveButton.disabled = currentlyEditable;

  if (!currentlyEditable) {
    setText(editButton, "Cancel");
    editButton.classList.add("btn-warning");
    productNameField.focus();
  } else {
    setText(editButton, "Edit");
    editButton.classList.remove("btn-warning");
    if (
      activeProductCardElement &&
      activeProductCardElement.dataset.productId
    ) {
      populateProductFormAndModal(
        formElement,
        activeProductCardElement.dataset,
        "view"
      );
    }
  }
}

async function handleProductFormSubmit(event) {
  event.preventDefault();
  const form = event.target;
  const productNameInput = form.elements["product[product_name]"];

  if (!productNameInput.value || productNameInput.value.trim() === "") {
    // Anstatt alert, könnte man hier eine kleine Meldung im Modal anzeigen
    // Für jetzt belassen wir es dabei, dass das `required` Attribut greift
    // oder die serverseitige Validierung den Fehler per Flash zurückgibt.
    console.warn(
      "Product Name cannot be empty. Serverseitige Validierung sollte greifen."
    );
    productNameInput.focus();
    return; // Stoppt den Submit, wenn clientseitig leer
  }

  const formData = new FormData(form);
  // Stelle sicher, dass product_id nicht als Teil von formData gesendet wird, wenn es nicht im Formular ist
  // (außer du hast ein hidden input dafür)
  // Wenn currentProductId existiert (Edit-Modus), ist es in form.action.
  // Wenn Add-Modus (POST), wird keine product_id im Body benötigt.

  const method =
    form.elements.formMethodField.value === "PATCH" ? "PATCH" : "POST";
  const url = form.action;

  const saveButton = document.getElementById("saveProductBtnInModal");
  if (saveButton) {
    saveButton.disabled = true;
    setText(saveButton, "Saving...");
  }

  try {
    const response = await fetch(url, {
      method,
      body: new URLSearchParams(formData), // Sendet als x-www-form-urlencoded
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          ?.content,
        // 'Accept': 'application/json', // Server gibt HTML mit Redirect zurück, daher nicht zwingend nötig
      },
    });

    // Da der Server bei Erfolg und Fehler einen Redirect zur Index-Seite macht
    // (wo Flash-Nachrichten angezeigt werden), ist die einfachste Reaktion hier,
    // die Seite ebenfalls neu zu laden, damit der User den Redirect und die Flash-Nachricht sieht.
    // Der Server-Redirect wird vom Browser automatisch gefolgt.
    // Dieser explizite Reload stellt sicher, dass auch bei nicht-redirectenden OK-Responses
    // (was hier nicht der Fall sein sollte) die Seite aktualisiert wird.
    if (response.ok || response.redirected) {
      window.location.reload();
    } else {
      // Wenn der Server einen Fehlerstatus OHNE Redirect sendet (z.B. 422 mit JSON-Fehler),
      // was bei der aktuellen Routenimplementierung (immer Redirect) nicht der Fall ist.
      // Dieser Block ist ein Fallback.
      console.error(
        "Server responded with an error:",
        response.status,
        response.statusText
      );
      // Wir laden trotzdem neu, damit die serverseitige Flash-Fehlermeldung angezeigt wird.
      window.location.reload();
    }
  } catch (error) {
    console.error("Form submission error:", error);
    // Generischer Fehler, Seite neu laden, um ggf. eine Server-Flash-Nachricht anzuzeigen,
    // oder hier eine clientseitige Fehlermeldung anzeigen.
    // alert('An error occurred. Please try again.'); // Alert entfernt
    window.location.reload(); // Im Zweifelsfall neu laden
  }
}

export function initAdminProductManagement() {
  productModalInstance = initializeModal("productModal");
  deleteProductConfirmModalInstance = initializeModal(
    "deleteProductConfirmModal"
  );

  const addProductCard = document.getElementById("addProductCard");
  if (addProductCard) {
    addProductCard.addEventListener("click", () => {
      activeProductCardElement = null;
      const form = document.getElementById("productForm");
      populateProductFormAndModal(form, {}, "add");
      showModal(productModalInstance);
    });
  }

  document.querySelectorAll(".product-configure-btn").forEach((button) => {
    button.addEventListener("click", (event) => {
      event.stopPropagation();
      activeProductCardElement = button.closest(".product-card");
      const form = document.getElementById("productForm");
      populateProductFormAndModal(
        form,
        activeProductCardElement.dataset,
        "view"
      );
      showModal(productModalInstance);
    });
  });

  const editButtonInModal = document.getElementById("editProductBtnInModal");
  if (editButtonInModal) {
    editButtonInModal.addEventListener("click", toggleEditModeProductForm);
  }

  const productFormElement = document.getElementById("productForm");
  if (productFormElement) {
    productFormElement.addEventListener("submit", handleProductFormSubmit);
  }

  const deleteButtonInMainModal = document.getElementById(
    "deleteProductBtnInModal"
  );
  if (deleteButtonInMainModal) {
    deleteButtonInMainModal.addEventListener("click", () => {
      if (currentProductId && activeProductCardElement) {
        setText(
          "deleteProductNameSpan",
          activeProductCardElement.dataset.productName || "this product"
        );
        const deleteForm = document.getElementById("deleteProductForm");
        if (deleteForm)
          deleteForm.action = `/admin/products/${currentProductId}`;
        showModal(deleteProductConfirmModalInstance);
      }
    });
  }

  const productModalElement = document.getElementById("productModal");
  if (productModalElement) {
    productModalElement.addEventListener("hidden.bs.modal", () => {
      const form = document.getElementById("productForm");
      if (form) {
        populateProductFormAndModal(form, {}, "add");
      }
      activeProductCardElement = null;
      currentProductId = null;
      // Stelle sicher, dass der Edit-Button zurückgesetzt wird
      const editButton = document.getElementById("editProductBtnInModal");
      if (editButton) {
        setText(editButton, "Edit");
        editButton.classList.remove("btn-warning");
      }
    });
  }
}
