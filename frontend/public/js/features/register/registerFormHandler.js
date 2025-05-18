// /js/features/register/registerFormHandler.js
import { initPasswordMatcher } from '../../components/passwordMatcher.js';
import { initPasswordStrengthChecker } from '../../components/passwordStrengthChecker.js';

/**
 * Initializes the registration form with password validation
 */
function initRegisterForm() {
  // Initialize password validation components
  const passwordMatcher = initPasswordMatcher();
  const passwordStrengthChecker = initPasswordStrengthChecker();
  
  // Form validation on submit
  const registerForm = document.getElementById('register-form');
  if (!registerForm) return;
  
  registerForm.addEventListener('submit', (e) => {
    // Check password requirements
    if (!passwordStrengthChecker.validate()) {
      e.preventDefault();
      passwordStrengthChecker.showIndicator();
    }
    
    // Check password matching (if not already checked by passwordMatcher)
    if (!passwordMatcher.check()) {
      e.preventDefault();
    }
  });
}

// Initialize form when DOM is ready
document.addEventListener('DOMContentLoaded', initRegisterForm);

