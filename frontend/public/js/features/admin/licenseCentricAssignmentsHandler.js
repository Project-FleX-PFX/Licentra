// public/js/features/admin/licenseCentricAssignmentsHandler.js
import {
  initializeModal,
  showModal,
  hideModal,
  setText,
} from "/js/features/admin/adminUtils.js";

let currentLicenseId;
let assignmentIdToProcess;
let actionToConfirm;
let availableSeats;
let totalLicenseSeats;

const STATUS_CONFIRM_MODAL_ID = "statusConfirmModal";
const DELETE_ASSIGNMENT_CONFIRM_MODAL_ID = "deleteAssignmentConfirmModal";

function updateAvailableSeatsDisplay(newAvailableSeats) {
  availableSeats = newAvailableSeats;
  const displayElement = document.getElementById("availableSeatsInfo");
  if (displayElement) {
    displayElement.textContent = `${availableSeats} / ${totalLicenseSeats}`;
  }
  document
    .querySelectorAll('.toggle-status-btn[data-action="activate"]')
    .forEach((btn) => {
      btn.disabled = availableSeats <= 0 && totalLicenseSeats > 0;
    });
}

async function handleStatusToggle(assignmentId, action) {
  const url = `/admin/licenses/${currentLicenseId}/assignments/${assignmentId}/${action}`;
  const confirmBtn = document.getElementById("confirmStatusBtn");

  if (confirmBtn) {
    confirmBtn.disabled = true;
    setText(confirmBtn, "Processing...");
  }

  try {
    const response = await fetch(url, {
      method: "PUT",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          ?.content,
        Accept: "application/json",
      },
    });
    if (!response.ok) {
      try {
        const errorResult = await response.json();
        console.error(
          `Failed to ${action} assignment:`,
          errorResult.error || response.statusText
        );
      } catch (e) {
        console.error(
          `Failed to ${action} assignment and parse error response:`,
          response.statusText
        );
      }
    }
  } catch (error) {
    console.error(`Error during ${action}:`, error);
  } finally {
    window.location.reload();
  }
}

async function handleDeleteAssignment(assignmentId) {
  const url = `/admin/licenses/${currentLicenseId}/assignments/${assignmentId}`;
  const confirmBtn = document.getElementById("confirmAssignmentDeleteBtn");

  if (confirmBtn) {
    confirmBtn.disabled = true;
    setText(confirmBtn, "Deleting...");
  }

  try {
    const response = await fetch(url, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          ?.content,
        Accept: "application/json",
      },
    });
    if (!response.ok) {
      try {
        const errorResult = await response.json();
        console.error(
          `Failed to delete assignment:`,
          errorResult.error || response.statusText
        );
      } catch (e) {
        console.error(
          `Failed to delete assignment and parse error response:`,
          response.statusText
        );
      }
    }
  } catch (error) {
    console.error("Error deleting assignment:", error);
  } finally {
    window.location.reload();
  }
}

export function initAdminLicenseCentricAssignments(config) {
  currentLicenseId = config.licenseId;
  availableSeats = config.initialAvailableSeats;
  totalLicenseSeats = config.totalSeats;

  initializeModal(STATUS_CONFIRM_MODAL_ID);
  initializeModal(DELETE_ASSIGNMENT_CONFIRM_MODAL_ID);

  const confirmStatusBtnEl = document.getElementById("confirmStatusBtn");
  if (confirmStatusBtnEl) {
    confirmStatusBtnEl.addEventListener("click", () => {
      if (assignmentIdToProcess && actionToConfirm) {
        handleStatusToggle(assignmentIdToProcess, actionToConfirm);
      }
    });
  }

  const confirmDelAssignBtnEl = document.getElementById(
    "confirmAssignmentDeleteBtn"
  );
  if (confirmDelAssignBtnEl) {
    confirmDelAssignBtnEl.addEventListener("click", () => {
      if (assignmentIdToProcess) {
        handleDeleteAssignment(assignmentIdToProcess);
      }
    });
  }

  updateAvailableSeatsDisplay(availableSeats);

  document.querySelectorAll(".toggle-status-btn").forEach((button) => {
    button.addEventListener("click", function () {
      assignmentIdToProcess = this.closest("tr").dataset.assignmentId;
      actionToConfirm = this.dataset.action;
      const userCell = this.closest("tr").querySelector("td:first-child");
      const username = userCell ? userCell.textContent.trim() : "this user";

      const modalMessage = document.getElementById("statusModalMessage");
      const modalConfirmBtn = document.getElementById("confirmStatusBtn");

      if (modalMessage && modalConfirmBtn) {
        setText(
          modalMessage,
          `Are you sure you want to ${actionToConfirm} the assignment for ${username}?`
        );
        modalConfirmBtn.className = `btn ${
          actionToConfirm === "activate" ? "btn-success" : "btn-warning"
        }`;
        setText(
          modalConfirmBtn,
          actionToConfirm.charAt(0).toUpperCase() + actionToConfirm.slice(1)
        );
        modalConfirmBtn.disabled = false;
        showModal(STATUS_CONFIRM_MODAL_ID);
      }
    });
  });

  document.querySelectorAll(".delete-assignment-btn").forEach((button) => {
    button.addEventListener("click", function () {
      if (this.disabled) return;
      assignmentIdToProcess = this.closest("tr").dataset.assignmentId;
      const userCell = this.closest("tr").querySelector("td:first-child");
      const username = userCell ? userCell.textContent.trim() : "this user";

      const userInfoP = document.getElementById("deleteAssignmentUserInfo");
      if (userInfoP) setText(userInfoP, `User: ${username}`);

      const modalConfirmBtn = document.getElementById(
        "confirmAssignmentDeleteBtn"
      );
      if (modalConfirmBtn) modalConfirmBtn.disabled = false;

      showModal(DELETE_ASSIGNMENT_CONFIRM_MODAL_ID);
    });
  });

  const assignNewUsersForm = document.getElementById("assignNewUsersForm");
  if (assignNewUsersForm) {
    assignNewUsersForm.addEventListener("submit", function (event) {
      const selectElement = document.getElementById("usersToAssignSelect");
      const saveButton = assignNewUsersForm.querySelector(
        'button[type="submit"]'
      );

      if (selectElement.selectedOptions.length === 0) {
        event.preventDefault();
        selectElement.classList.add("is-invalid");
      } else {
        selectElement.classList.remove("is-invalid");
        if (saveButton) {
          saveButton.disabled = true;
          setText(saveButton, "Assigning...");
        }
      }
    });
  }
}
