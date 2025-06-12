// frontend/public/js/features/history/historyPageHandler.js

/**
 * Converts all UTC timestamps with the class 'local-timestamp' to the user's local time.
 * The column header indicates that the times are local.
 * The original UTC time is added to the element's title attribute for viewing on hover.
 */
function convertTimestampsToLocal() {
  document.querySelectorAll("time.local-timestamp").forEach(function (timeElement) {
    const utcTimestamp = timeElement.getAttribute("datetime");
    const originalUtcText = timeElement.textContent.trim();

    if (utcTimestamp) {
      const localDate = new Date(utcTimestamp);

      // Format the local date to "YYYY-MM-DD HH:MM:SS" without timezone indicator
      const formattedLocalDate =
          localDate.getFullYear() +
          "-" +
          ("0" + (localDate.getMonth() + 1)).slice(-2) +
          "-" +
          ("0" + localDate.getDate()).slice(-2) +
          " " +
          ("0" + localDate.getHours()).slice(-2) +
          ":" +
          ("0" + localDate.getMinutes()).slice(-2) +
          ":" +
          ("0" + localDate.getSeconds()).slice(-2);

      timeElement.textContent = formattedLocalDate;
      timeElement.setAttribute("title", `Original UTC Time: ${originalUtcText}`);
    }
  });
}

/**
 * Displays a dismissible Bootstrap alert in a specified container.
 * @param {string} containerId - The ID of the element to display the alert in.
 * @param {string} message - The message to display in the alert.
 * @param {string} type - The Bootstrap alert type (e.g., 'danger', 'success').
 */
function displayAlert(containerId, message, type = 'danger') {
  const alertContainer = document.getElementById(containerId);
  if (alertContainer) {
    const alertHTML = `
      <div class="alert alert-${type} alert-dismissible fade show mb-3" role="alert">
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
      </div>`;
    alertContainer.innerHTML = alertHTML;
  }
}

/**
 * Sets up form submission validation for a date range using Bootstrap alerts.
 * @param {string} formId The ID of the form to validate.
 * @param {string} fromId The ID of the 'date from' input field.
 * @param {string} toId The ID of the 'date to' input field.
 * @param {string} alertContainerId The ID of the container for alerts.
 */
function setupDateRangeValidation(formId, fromId, toId, alertContainerId) {
  const form = document.getElementById(formId);
  if (!form) return;

  form.addEventListener('submit', function(event) {
    const dateFromInput = document.getElementById(fromId);
    const dateToInput = document.getElementById(toId);
    const alertContainer = document.getElementById(alertContainerId);

    // Clear any previous alerts
    if (alertContainer) {
      alertContainer.innerHTML = '';
    }

    const dateFrom = dateFromInput.value;
    const dateTo = dateToInput.value;

    if (dateFrom && dateTo && dateFrom > dateTo) {
      event.preventDefault(); // Stop form submission
      displayAlert(alertContainerId, "'Date From' cannot be after 'Date To'. Please select a valid date range.", 'danger');
    }
  });
}

/**
 * Sets up an event listener for a PDF export button.
 * When clicked, it gathers filter parameters from the specified form,
 * constructs an export URL, and opens it in a new tab.
 * @param {string} buttonId - The ID of the export button element.
 * @param {string} formId - The ID of the filter form element.
 * @param {string} exportUrlPath - The base path for the PDF export API endpoint.
 */
function setupExportButton(buttonId, formId, exportUrlPath) {
  const exportButton = document.getElementById(buttonId);
  const filterForm = document.getElementById(formId);

  if (exportButton && filterForm) {
    exportButton.addEventListener("click", function (event) {
      event.preventDefault();

      const formData = new FormData(filterForm);
      const params = new URLSearchParams();

      // Collect parameters for Assignment Log export
      if (formId === "assignmentFilterForm") {
        if (formData.get("assignment_user_id_filter"))
          params.append("assignment_user_id_filter", formData.get("assignment_user_id_filter"));
        if (formData.get("assignment_license_id_filter"))
          params.append("assignment_license_id_filter", formData.get("assignment_license_id_filter"));
        if (formData.get("assignment_action_filter"))
          params.append("assignment_action_filter", formData.get("assignment_action_filter"));
        if (formData.get("assignment_details_filter"))
          params.append("assignment_details_filter", formData.get("assignment_details_filter"));
        if (formData.get("assignment_date_from_filter"))
          params.append("assignment_date_from_filter", formData.get("assignment_date_from_filter"));
        if (formData.get("assignment_date_to_filter"))
          params.append("assignment_date_to_filter", formData.get("assignment_date_to_filter"));
      }
      // Collect parameters for Security Log export
      else if (formId === "securityFilterForm") {
        if (formData.get("security_user_id_filter"))
          params.append("security_user_id_filter", formData.get("security_user_id_filter"));
        if (formData.get("security_action_filter"))
          params.append("security_action_filter", formData.get("security_action_filter"));
        if (formData.get("security_object_filter"))
          params.append("security_object_filter", formData.get("security_object_filter"));
        if (formData.get("security_details_filter"))
          params.append("security_details_filter", formData.get("security_details_filter"));
        if (formData.get("security_date_from_filter"))
          params.append("security_date_from_filter", formData.get("security_date_from_filter"));
        if (formData.get("security_date_to_filter"))
          params.append("security_date_to_filter", formData.get("security_date_to_filter"));
      }

      const exportUrl = `${exportUrlPath}?${params.toString()}`;
      window.open(exportUrl, "_blank");
    });
  } else {
    if (!exportButton) console.error(`Export button with ID '${buttonId}' not found.`);
    if (!filterForm) console.error(`Filter form with ID '${formId}' not found.`);
  }
}

/**
 * Initializes all functionalities for the history page.
 */
function initHistoryPage() {
  convertTimestampsToLocal();

  const historyTabs = document.getElementById("historyTabs");
  if (historyTabs) {
    const tabButtons = historyTabs.querySelectorAll(".nav-link");
    tabButtons.forEach((button) => {
      button.addEventListener("shown.bs.tab", function (event) {
        convertTimestampsToLocal();
      });
    });
  }

  // Set up date range validation with Bootstrap alerts for both forms
  setupDateRangeValidation('assignmentFilterForm', 'assignment_date_from_filter', 'assignment_date_to_filter', 'assignment-alert-container');
  setupDateRangeValidation('securityFilterForm', 'security_date_from_filter', 'security_date_to_filter', 'security-alert-container');

  // Set up the PDF export buttons for both log types
  setupExportButton("exportAssignmentsPdf", "assignmentFilterForm", "/history/assignments/export.pdf");
  setupExportButton("exportSecurityPdf", "securityFilterForm", "/history/security/export.pdf");
}

// Ensures the initHistoryPage function is called only after the DOM is fully loaded
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initHistoryPage);
} else {
  initHistoryPage();
}
