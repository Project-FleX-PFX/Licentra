// public/js/features/admin/settingsFormHandler.js

/**
 * Initializes form validation for SMTP settings and test email forms on the admin settings page.
 */
export function initSettingsForms() {
    const smtpForm = document.getElementById('smtp-settings-form');
    const testForm = document.getElementById('test-smtp-form');

    if (smtpForm) {
        smtpForm.addEventListener('submit', (e) => {
            if (!validateSmtpForm()) {
                e.preventDefault();
            }
        });
    }

    if (testForm) {
        testForm.addEventListener('submit', (e) => {
            if (!validateTestEmailForm()) {
                e.preventDefault();
            }
        });
    }
}

/**
 * Validates the SMTP settings form before submission.
 * @returns {boolean} True if the form is valid, false otherwise.
 */
function validateSmtpForm() {
    const server = document.getElementById('smtp_server').value.trim();
    const port = document.getElementById('smtp_port').value;
    const username = document.getElementById('smtp_username').value.trim();
    const security = document.getElementById('smtp_security').value;

    if (!server) {
        showBootstrapAlert('smtp-settings-form', 'danger', 'Please enter an Email Server Address (e.g., smtp.gmail.com).');
        return false;
    }
    if (!port || port < 1 || port > 65535) {
        showBootstrapAlert('smtp-settings-form', 'danger', 'Please enter a valid Server Port between 1 and 65535 (common ports are 587 or 465).');
        return false;
    }
    if (!username || !username.includes('@')) {
        showBootstrapAlert('smtp-settings-form', 'danger', 'Please enter a valid Email Address as Username (e.g., yourname@provider.com).');
        return false;
    }
    if (!security) {
        showBootstrapAlert('smtp-settings-form', 'danger', 'Please select a Security Type (TLS/STARTTLS is recommended).');
        return false;
    }
    return true;
}

/**
 * Validates the test email form before submission.
 * @returns {boolean} True if the form is valid, false otherwise.
 */
function validateTestEmailForm() {
    const recipient = document.getElementById('test_email_recipient').value.trim();
    if (!recipient || !recipient.includes('@')) {
        showBootstrapAlert('test-smtp-form', 'danger', 'Please enter a valid email address to receive the test email.');
        return false;
    }
    return true;
}

/**
 * Dynamically creates and displays a Bootstrap alert within the specified form's card body.
 * @param {string} formId - The ID of the form to prepend the alert to its card body.
 * @param {string} type - The Bootstrap alert type (e.g., 'danger', 'success').
 * @param {string} message - The message to display in the alert.
 */
function showBootstrapAlert(formId, type, message) {
    // Find the card body of the form's card
    const form = document.getElementById(formId);
    if (!form) return;

    // Find the parent card body (p-4 p-md-5 class is a good indicator)
    let cardBody = form.closest('.card-body');
    if (!cardBody) return;

    // Remove any existing custom alerts to avoid clutter
    const existingAlerts = cardBody.querySelectorAll('.custom-alert');
    existingAlerts.forEach(alert => alert.remove());

    // Create a new Bootstrap alert
    const alertDiv = document.createElement('div');
    alertDiv.className = `alert alert-${type} alert-dismissible fade show custom-alert rounded-3 mb-3`;
    alertDiv.setAttribute('role', 'alert');
    alertDiv.innerHTML = `
    <i class="fas fa-exclamation-triangle me-2"></i> ${message}
    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
  `;

    // Prepend the alert to the card body (before the form content)
    cardBody.insertBefore(alertDiv, cardBody.firstChild);

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
        if (alertDiv.parentNode === cardBody) {
            alertDiv.classList.remove('show');
            setTimeout(() => {
                if (alertDiv.parentNode === cardBody) {
                    alertDiv.remove();
                }
            }, 150); // Wait for fade-out transition
        }
    }, 5000);
}

// Initialize the forms when the DOM is fully loaded
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initSettingsForms);
} else {
    initSettingsForms();
}
