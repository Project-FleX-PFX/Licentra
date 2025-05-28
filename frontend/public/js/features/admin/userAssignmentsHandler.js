// frontend/public/js/features/admin/userAssignmentsHandler.js
import {
  initializeModal,
  showModal,
  hideModal,
  showElement,
  hideElement,
  setText,
  setHtml,
} from "./adminUtils.js";

let statusConfirmModalInstance = null;
let addAssignmentModalInstance = null;
let deleteAssignmentConfirmModalInstance = null;

let currentAssignmentIdToModify = null;
let currentActionToConfirm = null;
let currentUserIdForAssignments = null;

function openStatusConfirmModal(assignmentId, action, productName) {
  currentAssignmentIdToModify = assignmentId;
  currentActionToConfirm = action;

  setText(
      "statusConfirmModalLabel",
      action === "activate" ? "Activate Assignment" : "Deactivate Assignment"
  );
  setText(
      "statusModalMessage",
      `Are you sure you want to ${action} the assignment for ${productName}?`
  );

  const confirmBtn = document.getElementById("confirmStatusBtn");
  if (confirmBtn) {
    setText(confirmBtn, action === "activate" ? "Activate" : "Deactivate");
    confirmBtn.className = `btn ${
        action === "activate" ? "btn-success" : "btn-warning"
    }`;
  }
  showModal(statusConfirmModalInstance);
}

async function handleConfirmStatusChange() {
  if (
      !currentAssignmentIdToModify ||
      !currentActionToConfirm ||
      !currentUserIdForAssignments
  )
    return;

  const url = `/admin/users/${currentUserIdForAssignments}/assignments/${currentAssignmentIdToModify}/${currentActionToConfirm}`;
  const confirmBtn = document.getElementById("confirmStatusBtn");

  if (confirmBtn) {
    confirmBtn.disabled = true;
    setText(confirmBtn, "Processing...");
  }

  try {
    await fetch(url, {
      method: "PUT",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
    });

    window.location.reload();
  } catch (error) {
    console.error("Status change error:", error);
    window.location.reload();
  }
}

async function openAddAssignmentModal() {
  if (!currentUserIdForAssignments) return;
  hideElement("licenseSelectionContainer");
  hideElement("noLicensesAvailable");
  hideElement("errorLoadingLicenses");
  showElement("licenseLoadingIndicator");
  showModal(addAssignmentModalInstance);

  try {
    const response = await fetch(
        `/admin/users/${currentUserIdForAssignments}/available_licenses`
    );
    if (!response.ok)
      throw new Error(
          `HTTP error loading available licenses! Status: ${response.status}`
      );
    const licenses = await response.json();

    hideElement("licenseLoadingIndicator");
    const licenseListContainer = document.getElementById(
        "availableLicensesList"
    );
    if (!licenseListContainer) return;
    setHtml(licenseListContainer, "");

    if (licenses.length === 0) {
      showElement("noLicensesAvailable");
      return;
    }

    licenses.forEach((license) => {
      const licenseItem = document.createElement("button");
      licenseItem.className =
          "list-group-item list-group-item-action d-flex justify-content-between align-items-center";
      licenseItem.type = "button";
      licenseItem.dataset.licenseId = license.license_id;

      const displayName = `${license.product_name || "N/A Product"} - ${
          license.license_name || "Unnamed License"
      }`;
      const seatsText = license.seat_count
          ? `Seats: ${license.available_seats} / ${license.seat_count}`
          : "Seats: N/A";
      setHtml(
          licenseItem,
          `
        <div>
          <h6 class="mb-1">${displayName}</h6>
          <small class="text-muted">Key: ${
              license.license_key || "N/A"
          } | ${seatsText}</small>
        </div>
        <span class="badge bg-primary rounded-pill">Assign</span>
      `
      );
      licenseItem.addEventListener("click", () =>
          handleAssignLicense(license.license_id)
      );
      licenseListContainer.appendChild(licenseItem);
    });
    showElement("licenseSelectionContainer");
  } catch (error) {
    console.error("Error loading available licenses:", error);
    hideElement("licenseLoadingIndicator");
    setText("errorLoadingLicenses", `Error loading licenses: ${error.message}`);
    showElement("errorLoadingLicenses");
  }
}

async function handleAssignLicense(licenseId) {
  if (!currentUserIdForAssignments || !licenseId) return;
  const formData = new URLSearchParams();
  formData.append("license_id", licenseId);

  try {
    await fetch(
        `/admin/users/${currentUserIdForAssignments}/assignments`,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
          },
          body: formData,
        }
    );

    window.location.reload();
  } catch (error) {
    console.error("Assign license error:", error);
    window.location.reload();
  }
}

function openDeleteAssignmentConfirmModal(assignmentId) {
  currentAssignmentIdToModify = assignmentId;
  showModal(deleteAssignmentConfirmModalInstance);
}

async function handleConfirmDeleteAssignment() {
  if (!currentAssignmentIdToModify || !currentUserIdForAssignments) return;

  const confirmBtn = document.getElementById("confirmAssignmentDeleteBtn");
  if (confirmBtn) {
    confirmBtn.disabled = true;
    setText(confirmBtn, "Deleting...");
  }

  try {
    await fetch(
        `/admin/users/${currentUserIdForAssignments}/assignments/${currentAssignmentIdToModify}`,
        {
          method: "DELETE",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
          },
        }
    );

    window.location.reload();
  } catch (error) {
    console.error("Delete assignment error:", error);
    window.location.reload();
  }
}

export function initAdminUserAssignments(userId) {
  currentUserIdForAssignments = userId;

  statusConfirmModalInstance = initializeModal("statusConfirmModal");
  addAssignmentModalInstance = initializeModal("addAssignmentModal");
  deleteAssignmentConfirmModalInstance = initializeModal(
      "deleteAssignmentConfirmModal"
  );

  document.querySelectorAll(".toggle-status-btn").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const card = btn.closest(".assignment-card");
      const assignmentId = card.dataset.assignmentId;
      const action = btn.dataset.action;
      const productName =
          card.querySelector("h2.card-title")?.textContent || "this assignment";
      openStatusConfirmModal(assignmentId, action, productName.trim());
    });
  });

  const addBtn = document.getElementById("addAssignmentBtn");
  if (addBtn) {
    addBtn.addEventListener("click", openAddAssignmentModal);
  }

  const confirmStatusBtnEl = document.getElementById("confirmStatusBtn");
  if (confirmStatusBtnEl) {
    confirmStatusBtnEl.addEventListener("click", handleConfirmStatusChange);
  }

  document
      .querySelectorAll(".delete-assignment-btn:not([disabled])")
      .forEach((btn) => {
        btn.addEventListener("click", (e) => {
          e.stopPropagation();
          const card = btn.closest(".assignment-card");
          const assignmentId = card.dataset.assignmentId;
          openDeleteAssignmentConfirmModal(assignmentId);
        });
      });

  const confirmDelAssignBtnEl = document.getElementById(
      "confirmAssignmentDeleteBtn"
  );
  if (confirmDelAssignBtnEl) {
    confirmDelAssignBtnEl.addEventListener(
        "click",
        handleConfirmDeleteAssignment
    );
  }

  const addModalEl = document.getElementById("addAssignmentModal");
  if (addModalEl) {
    addModalEl.addEventListener("hidden.bs.modal", () => {
      setHtml(document.getElementById("availableLicensesList"), "");
      hideElement("licenseSelectionContainer");
      hideElement("noLicensesAvailable");
      hideElement("errorLoadingLicenses");
    });
  }
}
