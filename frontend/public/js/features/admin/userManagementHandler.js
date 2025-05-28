// frontend/public/js/features/admin/userManagementHandler.js
import { initPasswordMatcher } from "../../components/passwordMatcher.js";
import { initPasswordStrengthChecker } from "../../components/passwordStrengthChecker.js";
import {
  initializeModal,
  showModal,
  hideModal,
  setText,
  showElement,
  hideElement,
} from "./adminUtils.js";

let userModalInstance = null;
let deleteUserConfirmModalInstance = null;

let activeCardDataset = {};
let currentUserId = null;
let currentModalMode = "view";

let passwordMatcherInstance = null;
let passwordStrengthCheckerInstance = null;

function setFormFieldsDisabled(formElement, disabled, exceptIds = []) {
  Array.from(formElement.elements).forEach((element) => {
    if (element.type !== "hidden" && !exceptIds.includes(element.id)) {
      element.disabled = disabled;
    }
  });
}

function enablePasswordFields(formElement, enable, mode) {
  const passwordField = formElement.elements["user[new_password]"];
  const confirmField = formElement.elements["user[password_confirmation]"];
  const strengthIndicator = document.getElementById("password-strength");
  const confirmGroup = document.getElementById("passwordConfirmationGroup");
  const helpText = document.getElementById("passwordHelpText");
  const matchIndicator = document.getElementById("match");

  if (passwordField) passwordField.disabled = !enable;
  if (confirmField) confirmField.disabled = !enable;

  if (enable) {
    showElement(strengthIndicator);
    showElement(confirmGroup);
    if (mode === "add") {
      setText(
          helpText,
          "Password is required. Please choose a strong password."
      );
      if (passwordField) {
        passwordField.placeholder = "Enter password";
        passwordField.required = true;
      }
      if (confirmField) {
        confirmField.placeholder = "Confirm password";
        confirmField.required = true;
      }
    } else {
      setText(
          helpText,
          "Enter new password to change it. Leave blank to keep current."
      );
      if (passwordField) {
        passwordField.placeholder = "New password (optional)";
        passwordField.required = false;
      }
      if (confirmField) {
        confirmField.placeholder = "Confirm new password";
        confirmField.required = false;
      }
    }
    if (!passwordStrengthCheckerInstance) {
      passwordStrengthCheckerInstance = initPasswordStrengthChecker({
        passwordInputId: "userPasswordField",
      });
    }
    if (!passwordMatcherInstance) {
      passwordMatcherInstance = initPasswordMatcher({
        passwordInputId: "userPasswordField",
        confirmInputId: "userPasswordConfirmationField",
      });
    }
    if (passwordField && passwordField.value)
      passwordStrengthCheckerInstance?.validate();
    if (confirmField && confirmField.value) passwordMatcherInstance?.check();
  } else {
    hideElement(strengthIndicator);
    hideElement(confirmGroup);
    if (matchIndicator) matchIndicator.hidden = true;
    if (passwordField) {
      passwordField.value = "";
      passwordField.required = false;
      passwordField.placeholder =
          mode === "view" && currentModalMode !== "add"
              ? "********"
              : "Leave blank to keep current password";
    }
    if (confirmField) {
      confirmField.value = "";
      confirmField.required = false;
    }
    if (helpText && mode === "view" && currentModalMode !== "add")
      setText(
          helpText,
          'Password is not displayed. Click "Edit" to enable password change.'
      );
  }
}

function populateUserForm(formElement, userData) {
  formElement.reset();

  formElement.elements["user[username]"].value = userData.username || "";
  formElement.elements["user[email]"].value = userData.email || "";
  formElement.elements["user[first_name]"].value = userData.firstName || "";
  formElement.elements["user[last_name]"].value = userData.lastName || "";

  const isActiveCheckbox = formElement.elements["user[is_active]"];
  if (isActiveCheckbox) {
    isActiveCheckbox.checked =
        userData.isActive === "true" ||
        (currentModalMode === "add" && userData.isActive === undefined);
  }

  const roleCheckboxes = formElement.querySelectorAll(".user-role-checkbox");
  roleCheckboxes.forEach((cb) => (cb.checked = false));
  if (userData.roleIds) {
    const selectedRoleIds = userData.roleIds.split(",");
    selectedRoleIds.forEach((roleId) => {
      const checkbox = formElement.querySelector(
          `.user-role-checkbox[value="${roleId.trim()}"]`
      );
      if (checkbox) checkbox.checked = true;
    });
  }
  hideElement("rolesError");
}

function setupModalForMode(mode, cardDataset = {}) {
  const form = document.getElementById("userForm");
  const modalLabel = document.getElementById("userModalLabel");
  const editBtn = document.getElementById("editUserToggleBtn");
  const saveBtn = document.getElementById("saveUserChangesBtn");
  const deleteBtn = document.getElementById("deleteUserBtnInModal");
  const formMethodField = document.getElementById("userFormMethodField");

  currentModalMode = mode;
  activeCardDataset = { ...cardDataset };
  currentUserId = cardDataset.userId || null;

  populateUserForm(form, activeCardDataset);

  if (mode === "add") {
    setText(modalLabel, "Add New User");
    form.action = "/admin/users";
    formMethodField.value = "";
    setFormFieldsDisabled(form, false, ["saveUserChangesBtn"]);
    enablePasswordFields(form, true, "add");

    hideElement(editBtn);
    hideElement(deleteBtn);
    showElement(saveBtn);
    setText(saveBtn, "Add User");
    saveBtn.disabled = false;
    form.elements["user[username]"].focus();
  } else {
    setText(modalLabel, `User: ${activeCardDataset.username || "Details"}`);
    form.action = `/admin/users/${currentUserId}`;
    formMethodField.value = "PATCH";
    setFormFieldsDisabled(form, true, [
      "editUserToggleBtn",
      "saveUserChangesBtn",
      "deleteUserBtnInModal",
    ]);
    enablePasswordFields(form, false, "view");

    showElement(editBtn);
    setText(editBtn, "Edit");
    editBtn.classList.remove("btn-warning");
    if (currentUserId) {
      showElement(deleteBtn);
    } else {
      hideElement(deleteBtn);
    }
    showElement(saveBtn);
    setText(saveBtn, "Save Changes");
    saveBtn.disabled = true;
  }
  showModal(userModalInstance);
}

function toggleEditState() {
  const form = document.getElementById("userForm");
  const editBtn = document.getElementById("editUserToggleBtn");
  const saveBtn = document.getElementById("saveUserChangesBtn");
  const isCurrentlyViewMode = form.elements["user[username]"].disabled;

  if (isCurrentlyViewMode) {
    setFormFieldsDisabled(form, false, ["saveUserChangesBtn"]);
    enablePasswordFields(form, true, "edit");
    setText(editBtn, "Cancel");
    editBtn.classList.add("btn-warning");
    saveBtn.disabled = false;
    form.elements["user[username]"].focus();
  } else {
    populateUserForm(form, activeCardDataset);
    setFormFieldsDisabled(form, true, [
      "editUserToggleBtn",
      "saveUserChangesBtn",
      "deleteUserBtnInModal",
    ]);
    enablePasswordFields(form, false, "view");
    setText(editBtn, "Edit");
    editBtn.classList.remove("btn-warning");
    saveBtn.disabled = true;
    hideElement("rolesError");
  }
}

async function handleUserFormSubmit(event) {
  event.preventDefault();
  const form = event.target;

  const roleCheckboxes = form.querySelectorAll(".user-role-checkbox");
  const atLeastOneRoleSelected = Array.from(roleCheckboxes).some(
      (checkbox) => checkbox.checked
  );
  const rolesErrorEl = document.getElementById("rolesError");
  if (!atLeastOneRoleSelected) {
    showElement(rolesErrorEl);
    return;
  } else {
    hideElement(rolesErrorEl);
  }

  const passwordField = form.elements["user[new_password]"];
  const confirmField = form.elements["user[password_confirmation]"];

  if (
      currentModalMode === "add" ||
      (!passwordField.disabled && passwordField.value.trim() !== "")
  ) {
    if (
        passwordStrengthCheckerInstance &&
        !passwordStrengthCheckerInstance.validate()
    ) {
      passwordField.focus();
      return;
    }
    if (passwordMatcherInstance && !passwordMatcherInstance.check()) {
      confirmField.focus();
      return;
    }
    if (
        currentModalMode === "add" &&
        (passwordField.value.trim() === "" || confirmField.value.trim() === "")
    ) {
      alert("Password and confirmation are required for new users.");
      passwordField.focus();
      return;
    }
  }

  if (!form.checkValidity()) {
    form.reportValidity();
    return;
  }

  const formData = new FormData(form);
  const selectedRoleIds = Array.from(roleCheckboxes)
      .filter((cb) => cb.checked)
      .map((cb) => cb.value);

  formData.delete("user_role_ids[]");
  selectedRoleIds.forEach((id) => formData.append("user_role_ids[]", id));

  if (currentModalMode !== "add" && passwordField.value.trim() === "") {
    formData.delete("user[new_password]");
    formData.delete("user[password_confirmation]");
  }
  if (!formData.has("user[is_active]")) {
    formData.append("user[is_active]", "false");
  }

  const methodForFetch =
      form.elements.userFormMethodField.value === "PATCH" ? "PATCH" : "POST";
  const url = form.action;

  const saveButton = document.getElementById("saveUserChangesBtn");
  if (saveButton) {
    saveButton.disabled = true;
    setText(saveButton, "Saving...");
  }

  try {
    await fetch(url, {
      method: methodForFetch,
      body: new URLSearchParams(formData),
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
    });

    window.location.reload();
  } catch (error) {
    console.error("Form submission error:", error);
    window.location.reload();
  }
}

async function handleDeleteUserFormSubmit(event) {
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
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content,
      },
    });

    window.location.reload();
  } catch (error) {
    console.error("Delete submission error:", error);
    window.location.reload();
  }
}

export function initAdminUserManagement() {
  userModalInstance = initializeModal("userModal");
  deleteUserConfirmModalInstance = initializeModal("deleteUserConfirmModal");

  document.querySelectorAll(".user-configure-btn").forEach((button) => {
    button.addEventListener("click", (event) => {
      event.stopPropagation();
      const card = button.closest(".user-card");
      setupModalForMode("view", card.dataset);
    });
  });

  document.querySelectorAll('form[action*="/lock"], form[action*="/unlock"]').forEach(form => {
    form.addEventListener('submit', async (event) => {
      event.preventDefault(); // Verhindert normalen Form-Submit

      const url = form.action;
      const button = form.querySelector('button[type="submit"]');
      const originalText = button.innerHTML;

      // Button-Feedback während Request
      if (button) {
        button.disabled = true;
        if (url.includes('/lock')) {
          button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Locking...';
        } else {
          button.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Unlocking...';
        }
      }

      try {
        await fetch(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
          },
        });

        window.location.reload();
      } catch (error) {
        console.error('Lock/Unlock action error:', error);
        // Button zurücksetzen bei Fehler
        if (button) {
          button.disabled = false;
          button.innerHTML = originalText;
        }
        window.location.reload(); // Fallback
      }
    });
  });

  const addUserCard = document.getElementById("addUserCardBtn");
  if (addUserCard) {
    addUserCard.addEventListener("click", () => {
      setupModalForMode("add");
    });
  }

  const editToggleButton = document.getElementById("editUserToggleBtn");
  if (editToggleButton) {
    editToggleButton.addEventListener("click", toggleEditState);
  }

  const userFormElement = document.getElementById("userForm");
  if (userFormElement) {
    userFormElement.addEventListener("submit", handleUserFormSubmit);
  }

  const deleteBtnInModal = document.getElementById("deleteUserBtnInModal");
  if (deleteBtnInModal) {
    deleteBtnInModal.addEventListener("click", () => {
      if (currentUserId && activeCardDataset.username) {
        setText("deleteConfirmUserNameSpan", activeCardDataset.username);
        const deleteForm = document.getElementById("deleteUserForm");
        if (deleteForm) deleteForm.action = `/admin/users/${currentUserId}`;
        showModal(deleteUserConfirmModalInstance);
      }
    });
  }

  const deleteUserFormElement = document.getElementById("deleteUserForm");
  if (deleteUserFormElement) {
    deleteUserFormElement.addEventListener("submit", handleDeleteUserFormSubmit);
  }

  const userModalElement = document.getElementById("userModal");
  if (userModalElement) {
    userModalElement.addEventListener("shown.bs.modal", () => {
      if (currentModalMode === "add") {
        enablePasswordFields(document.getElementById("userForm"), true, "add");
      } else if (
          document.getElementById("userPasswordField")?.disabled === false
      ) {
        enablePasswordFields(document.getElementById("userForm"), true, "edit");
      } else {
        enablePasswordFields(
            document.getElementById("userForm"),
            false,
            "view"
        );
      }
    });

    userModalElement.addEventListener("hidden.bs.modal", () => {
      const form = document.getElementById("userForm");
      populateUserForm(form, {});
      setFormFieldsDisabled(form, true, [
        "editUserToggleBtn",
        "saveUserChangesBtn",
        "deleteUserBtnInModal",
      ]);
      enablePasswordFields(form, false, "view");
      setText("editUserToggleBtn", "Edit");
      document
          .getElementById("editUserToggleBtn")
          .classList.remove("btn-warning");
      const saveBtn = document.getElementById("saveUserChangesBtn");
      setText(saveBtn, "Save Changes");
      saveBtn.disabled = true;
      hideElement("rolesError");
      hideElement("password-strength");
      document.getElementById("match").hidden = true;
      activeCardDataset = {};
      currentUserId = null;
      currentModalMode = "view";
    });
  }
}
