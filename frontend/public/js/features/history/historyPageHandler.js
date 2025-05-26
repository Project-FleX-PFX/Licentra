// frontend/public/js/features/history/historyPageHandler.js

/**
 * Converts all UTC timestamps with the class 'local-timestamp' to the user's local time.
 * It reads the UTC timestamp from the 'datetime' attribute of <time> elements,
 * formats it, and updates the element's text content and title.
 */
function convertTimestampsToLocal() {
  document
    .querySelectorAll("time.local-timestamp")
    .forEach(function (timeElement) {
      const utcTimestamp = timeElement.getAttribute("datetime"); // Get UTC timestamp from datetime attribute
      if (utcTimestamp) {
        const localDate = new Date(utcTimestamp); // Convert UTC string to local Date object

        // Format the local date to YYYY-MM-DD HH:MM:SS Local
        const formattedLocalDate =
          localDate.getFullYear() +
          "-" +
          ("0" + (localDate.getMonth() + 1)).slice(-2) + // Month is 0-indexed, add 1
          "-" +
          ("0" + localDate.getDate()).slice(-2) +
          " " +
          ("0" + localDate.getHours()).slice(-2) +
          ":" +
          ("0" + localDate.getMinutes()).slice(-2) +
          ":" +
          ("0" + localDate.getSeconds()).slice(-2) +
          " Local";

        timeElement.textContent = formattedLocalDate; // Update the displayed text
        // Update the title attribute to show the original UTC time on hover
        timeElement.setAttribute(
          "title",
          `Original: ${timeElement.textContent.replace(" Local", " UTC")}`
        );
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

  // Ensure both the button and form elements exist before attaching the event listener
  if (exportButton && filterForm) {
    exportButton.addEventListener("click", function (event) {
      event.preventDefault(); // Prevent the default link behavior

      const formData = new FormData(filterForm); // Get data from the filter form
      const params = new URLSearchParams(); // Used to build the query string

      // Collect parameters for Assignment Log export
      if (formId === "assignmentFilterForm") {
        // Check and append each filter parameter if it exists in the form data
        if (formData.get("assignment_user_id_filter"))
          params.append(
            "assignment_user_id_filter",
            formData.get("assignment_user_id_filter")
          );
        if (formData.get("assignment_license_id_filter"))
          params.append(
            "assignment_license_id_filter",
            formData.get("assignment_license_id_filter")
          );
        if (formData.get("assignment_action_filter"))
          params.append(
            "assignment_action_filter",
            formData.get("assignment_action_filter")
          );
        if (formData.get("assignment_details_filter"))
          params.append(
            "assignment_details_filter",
            formData.get("assignment_details_filter")
          );
        if (formData.get("assignment_date_from_filter"))
          params.append(
            "assignment_date_from_filter",
            formData.get("assignment_date_from_filter")
          );
        if (formData.get("assignment_date_to_filter"))
          params.append(
            "assignment_date_to_filter",
            formData.get("assignment_date_to_filter")
          );
      }
      // Collect parameters for Security Log export
      else if (formId === "securityFilterForm") {
        if (formData.get("security_user_id_filter"))
          params.append(
            "security_user_id_filter",
            formData.get("security_user_id_filter")
          );
        if (formData.get("security_action_filter"))
          params.append(
            "security_action_filter",
            formData.get("security_action_filter")
          );
        if (formData.get("security_object_filter"))
          params.append(
            "security_object_filter",
            formData.get("security_object_filter")
          );
        if (formData.get("security_details_filter"))
          params.append(
            "security_details_filter",
            formData.get("security_details_filter")
          );
        if (formData.get("security_date_from_filter"))
          params.append(
            "security_date_from_filter",
            formData.get("security_date_from_filter")
          );
        if (formData.get("security_date_to_filter"))
          params.append(
            "security_date_to_filter",
            formData.get("security_date_to_filter")
          );
      }

      // Construct the full export URL with query parameters
      const exportUrl = `${exportUrlPath}?${params.toString()}`;
      window.open(exportUrl, "_blank"); // Open the PDF export URL in a new tab
    });
  } else {
    // Log an error if the button or form elements are not found, aiding in debugging
    if (!exportButton)
      console.error(`Export button with ID '${buttonId}' not found.`);
    if (!filterForm)
      console.error(`Filter form with ID '${formId}' not found.`);
  }
}

/**
 * Initializes all functionalities for the history page.
 * This includes converting timestamps, setting up tab change listeners,
 * and configuring export buttons.
 */
function initHistoryPage() {
  convertTimestampsToLocal(); // Convert timestamps on initial page load

  // Set up an event listener for Bootstrap 5 tabs
  // to re-convert timestamps when a new tab is shown
  const historyTabs = document.getElementById("historyTabs");
  if (historyTabs) {
    const tabButtons = historyTabs.querySelectorAll(".nav-link");
    tabButtons.forEach((button) => {
      // 'shown.bs.tab' is a Bootstrap event that fires after a tab has been shown
      button.addEventListener("shown.bs.tab", function (event) {
        convertTimestampsToLocal(); // Re-convert timestamps for the content of the newly shown tab
      });
    });
  }

  // Set up the PDF export buttons for both log types
  setupExportButton(
    "exportAssignmentsPdf", // Button ID
    "assignmentFilterForm", // Form ID for assignment filters
    "/history/assignments/export.pdf" // Export URL path
  );
  setupExportButton(
    "exportSecurityPdf", // Button ID
    "securityFilterForm", // Form ID for security filters
    "/history/security/export.pdf" // Export URL path
  );
}

// Ensures the initHistoryPage function is called only after the DOM is fully loaded.
// This is standard practice to prevent errors from trying to manipulate DOM elements
// that haven't been created yet.
// `type="module"` scripts are deferred by default, so this also works well in that context.
if (document.readyState === "loading") {
  // The document is still loading, so wait for DOMContentLoaded.
  document.addEventListener("DOMContentLoaded", initHistoryPage);
} else {
  // The DOM has already been loaded, so we can initialize immediately.
  initHistoryPage();
}
