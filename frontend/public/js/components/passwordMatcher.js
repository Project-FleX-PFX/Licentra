// /js/components/passwordMatcher.js

/**
 * Initializes password matching functionality between two password fields
 * @param {Object} options - Configuration options
 * @param {string} [options.passwordInputId='password'] - ID of the password input field
 * @param {string} [options.confirmInputId='password_confirmation'] - ID of the confirmation input field
 * @param {string} [options.matchCheckId='match'] - ID of the element to display match status
 * @returns {Object|undefined} Object with check method or undefined if elements not found
 */
export function initPasswordMatcher(options = {}) {
  const config = {
    passwordInputId: 'password',
    confirmInputId: 'password_confirmation',
    matchCheckId: 'match',
    ...options,
  };

  const passwordInput = document.getElementById(config.passwordInputId);
  const confirmInput = document.getElementById(config.confirmInputId);
  const matchCheck = document.getElementById(config.matchCheckId);

  if (!passwordInput || !confirmInput || !matchCheck) return;

  // Hide match check element initially
  matchCheck.hidden = true;

  /**
   * Validates if passwords match and updates UI accordingly
   * @returns {boolean} True if passwords match, false otherwise
   */
  function checkPasswordMatch() {
    const password = passwordInput.value;
    const confirmPassword = confirmInput.value;

    if (confirmPassword === '') {
      matchCheck.hidden = true;
      return false;
    }

    matchCheck.hidden = false;

    if (password === confirmPassword) {
      matchCheck.classList.remove('text-danger');
      matchCheck.classList.add('text-success');
      matchCheck.innerHTML = '<i class="fas fa-check-circle"></i> Passwords match';
      return true;
    } 
    
    matchCheck.classList.remove('text-success');
    matchCheck.classList.add('text-danger');
    matchCheck.innerHTML = '<i class="fas fa-times-circle"></i> Passwords do not match';
    return false;
  }

  // Attach event listeners
  confirmInput.addEventListener('keyup', checkPasswordMatch);
  confirmInput.addEventListener('focus', () => {
    if (confirmInput.value !== '') {
      checkPasswordMatch();
    }
  });

  passwordInput.addEventListener('keyup', () => {
    if (confirmInput.value !== '') {
      checkPasswordMatch();
    }
  });

  // Add form submission validation
  if (passwordInput.form) {
    passwordInput.form.addEventListener('submit', (e) => {
      if (confirmInput.value !== '' && !checkPasswordMatch()) {
        e.preventDefault();
        matchCheck.hidden = false;
      }
    });
  }

  // Return public methods
  return {
    check: checkPasswordMatch,
  };
}

