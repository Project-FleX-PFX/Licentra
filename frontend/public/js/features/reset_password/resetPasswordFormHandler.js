// public/js/features/reset_password/resetPasswordFormHandler.js
import { initPasswordMatcher } from '../../components/passwordMatcher.js';
import { initPasswordStrengthChecker } from '../../components/passwordStrengthChecker.js';

/**
 * Initializes the reset password form with password validation
 */
function initResetPasswordForm() {
    // Initialize password validation components
    // Die IDs der Elemente für Passwortstärke und Match sind in reset_password_form.erb vorhanden.
    const passwordMatcher = initPasswordMatcher({
        passwordInputId: 'password', // Standard-ID, aber explizit ist gut
        confirmInputId: 'password_confirmation', // Standard-ID
        matchCheckId: 'match' // Standard-ID
    });
    const passwordStrengthChecker = initPasswordStrengthChecker({
        passwordInputId: 'password', // Standard-ID
        strengthIndicatorId: 'password-strength', // Standard-ID
        // Andere IDs (length, letter etc.) sind auch Standard und sollten funktionieren,
        // solange das HTML in reset_password_form.erb dem in register.erb entspricht.
    });

    const resetForm = document.getElementById('reset-password-form');
    if (!resetForm) {
        console.error('Reset password form not found!');
        return;
    }

    resetForm.addEventListener('submit', (e) => {
        let isValid = true;

        // Check password requirements
        if (passwordStrengthChecker && !passwordStrengthChecker.validate()) {
            passwordStrengthChecker.showIndicator(); // Zeige Indikator bei Fehler
            isValid = false;
        }

        // Check password matching
        if (passwordMatcher && !passwordMatcher.check()) {
            // passwordMatcher.check() sollte bereits die UI aktualisieren (matchCheck.hidden = false)
            isValid = false;
        }

        if (!isValid) {
            e.preventDefault(); // Verhindere das Absenden des Formulars, wenn Validierung fehlschlägt
        }
    });
}

// Initialize form when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initResetPasswordForm);
} else {
    // DOMContentLoaded wurde bereits ausgelöst
    initResetPasswordForm();
}
