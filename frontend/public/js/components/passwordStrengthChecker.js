// /js/components/passwordStrengthChecker.js

/**
 * Initializes password strength checking functionality
 * @param {Object} options - Configuration options
 * @param {string} [options.passwordInputId='password'] - ID of the password input field
 * @param {string} [options.strengthIndicatorId='password-strength'] - ID of the strength indicator container
 * @param {string} [options.lengthCheckId='length'] - ID of the length check element
 * @param {string} [options.letterCheckId='letter'] - ID of the lowercase letter check element
 * @param {string} [options.capitalCheckId='capital'] - ID of the uppercase letter check element
 * @param {string} [options.numberCheckId='number'] - ID of the number check element
 * @param {string} [options.specialCheckId='special'] - ID of the special character check element
 * @param {string} [options.forbiddenCheckId='forbidden'] - ID of the forbidden words check element
 * @param {number} [options.minLength=10] - Minimum password length
 * @param {string[]} [options.forbiddenWords=['licentra', 'password']] - Words that shouldn't be in the password
 * @returns {Object} Object with validate, showIndicator, and hideIndicator methods
 */
export function initPasswordStrengthChecker(options = {}) {
  const config = {
    passwordInputId: 'password',
    strengthIndicatorId: 'password-strength',
    lengthCheckId: 'length',
    letterCheckId: 'letter',
    capitalCheckId: 'capital',
    numberCheckId: 'number',
    specialCheckId: 'special',
    forbiddenCheckId: 'forbidden',
    minLength: 10,
    forbiddenWords: ['licentra', 'password'],
    ...options,
  };

  const passwordInput = document.getElementById(config.passwordInputId);
  const passwordStrength = document.getElementById(config.strengthIndicatorId);
  const lengthCheck = document.getElementById(config.lengthCheckId);
  const letterCheck = document.getElementById(config.letterCheckId);
  const capitalCheck = document.getElementById(config.capitalCheckId);
  const numberCheck = document.getElementById(config.numberCheckId);
  const specialCheck = document.getElementById(config.specialCheckId);
  const forbiddenCheck = document.getElementById(config.forbiddenCheckId);

  if (!passwordInput) return { validate: () => false };
  
  // Hide validation feedback initially
  if (passwordStrength) passwordStrength.hidden = true;

  /**
   * Updates the visual state of a validation check element
   * @param {HTMLElement} element - The element to update
   * @param {boolean} isValid - Whether the validation passed
   * @param {string} validMsg - Message to show when valid
   * @param {string} invalidMsg - Message to show when invalid
   */
  function updateValidationStatus(element, isValid, validMsg, invalidMsg) {
    if (!element) return;
    
    element.classList.remove(isValid ? 'text-danger' : 'text-success');
    element.classList.add(isValid ? 'text-success' : 'text-danger');
    element.innerHTML = `<i class="fas fa-${isValid ? 'check' : 'times'}-circle"></i> ${isValid ? validMsg : invalidMsg}`;
  }

  /**
   * Validates the password against all requirements
   * @returns {boolean} True if all requirements are met, false otherwise
   */
  function validatePasswordRequirements() {
    if (!passwordInput) return false;
    
    const password = passwordInput.value;
    let isValid = true;

    // Minimum length check
    const lengthValid = password.length >= config.minLength;
    updateValidationStatus(
      lengthCheck, 
      lengthValid, 
      `At least ${config.minLength} characters`, 
      `At least ${config.minLength} characters`,
    );
    if (!lengthValid) isValid = false;

    // Lowercase letter check
    const lowerCaseValid = /[a-z]/.test(password);
    updateValidationStatus(
      letterCheck, 
      lowerCaseValid, 
      'At least one lowercase letter', 
      'At least one lowercase letter',
    );
    if (!lowerCaseValid) isValid = false;

    // Uppercase letter check
    const upperCaseValid = /[A-Z]/.test(password);
    updateValidationStatus(
      capitalCheck, 
      upperCaseValid, 
      'At least one uppercase letter', 
      'At least one uppercase letter',
    );
    if (!upperCaseValid) isValid = false;

    // Number check
    const numberValid = /[0-9]/.test(password);
    updateValidationStatus(
      numberCheck, 
      numberValid, 
      'At least one number', 
      'At least one number',
    );
    if (!numberValid) isValid = false;

    // Special character check
    const specialValid = /[~`!@#$%^&*()_\-+={}[\]|\\:;"'<>,.?/]/.test(password);
    updateValidationStatus(
      specialCheck, 
      specialValid, 
      'At least one special character', 
      'At least one special character',
    );
    if (!specialValid) isValid = false;

    // Forbidden words check
    const forbiddenPattern = new RegExp(config.forbiddenWords.join('|'), 'i');
    const forbiddenValid = !forbiddenPattern.test(password);
    updateValidationStatus(
      forbiddenCheck, 
      forbiddenValid, 
      `Must not contain "${config.forbiddenWords.join('" or "')}"`, 
      `Must not contain "${config.forbiddenWords.join('" or "')}"`,
    );
    if (!forbiddenValid) isValid = false;

    return isValid;
  }

  // Attach event listeners
  passwordInput.addEventListener('keyup', () => {
    if (passwordStrength) passwordStrength.hidden = false;
    validatePasswordRequirements();
  });
  
  passwordInput.addEventListener('focus', () => {
    if (passwordStrength) passwordStrength.hidden = false;
    validatePasswordRequirements();
  });

  // Add form submission validation
  if (passwordInput.form) {
    passwordInput.form.addEventListener('submit', (e) => {
      if (!validatePasswordRequirements()) {
        e.preventDefault();
        if (passwordStrength) passwordStrength.hidden = false;
      }
    });
  }

  // Return public methods
  return {
    validate: validatePasswordRequirements,
    showIndicator: () => { if (passwordStrength) passwordStrength.hidden = false; },
    hideIndicator: () => { if (passwordStrength) passwordStrength.hidden = true; },
  };
}

