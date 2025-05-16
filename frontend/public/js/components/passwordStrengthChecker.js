// /js/components/passwordStrengthChecker.js
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
    ...options
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

  function updateValidationStatus(element, isValid, validMsg, invalidMsg) {
    if (!element) return;
    if (isValid) {
      element.classList.remove('text-danger');
      element.classList.add('text-success');
      element.innerHTML = '<i class="fas fa-check-circle"></i> ' + validMsg;
    } else {
      element.classList.remove('text-success');
      element.classList.add('text-danger');
      element.innerHTML = '<i class="fas fa-times-circle"></i> ' + invalidMsg;
    }
  }

  function validatePasswordRequirements() {
    if (!passwordInput) return false;
    const password = passwordInput.value;
    let isValid = true;

    // Minimum length check
    const lengthValid = password.length >= config.minLength;
    updateValidationStatus(lengthCheck, lengthValid, `At least ${config.minLength} characters`, `At least ${config.minLength} characters`);
    if (!lengthValid) isValid = false;

    // Lowercase letter check
    const lowerCaseValid = /[a-z]/.test(password);
    updateValidationStatus(letterCheck, lowerCaseValid, "At least one lowercase letter", "At least one lowercase letter");
    if (!lowerCaseValid) isValid = false;

    // Uppercase letter check
    const upperCaseValid = /[A-Z]/.test(password);
    updateValidationStatus(capitalCheck, upperCaseValid, "At least one uppercase letter", "At least one uppercase letter");
    if (!upperCaseValid) isValid = false;

    // Number check
    const numberValid = /[0-9]/.test(password);
    updateValidationStatus(numberCheck, numberValid, "At least one number", "At least one number");
    if (!numberValid) isValid = false;

    // Special character check
    const specialValid = /[~`!@#$%^&*()_\-+={}[\]|\\:;"'<>,.?/]/.test(password);
    updateValidationStatus(specialCheck, specialValid, "At least one special character", "At least one special character");
    if (!specialValid) isValid = false;

    // Forbidden words check
    const forbiddenPattern = new RegExp(config.forbiddenWords.join('|'), 'i');
    const forbiddenValid = !forbiddenPattern.test(password);
    updateValidationStatus(forbiddenCheck, forbiddenValid, 
      `Must not contain "${config.forbiddenWords.join('" or "')}"`, 
      `Must not contain "${config.forbiddenWords.join('" or "')}"` 
    );
    if (!forbiddenValid) isValid = false;

    return isValid;
  }

  // Attach event listeners
  passwordInput.addEventListener('keyup', function() {
    if (passwordStrength) passwordStrength.hidden = false;
    validatePasswordRequirements();
  });
  
  passwordInput.addEventListener('focus', function() {
    if (passwordStrength) passwordStrength.hidden = false;
    validatePasswordRequirements();
  });

  // Add form submission validation
  if (passwordInput.form) {
    passwordInput.form.addEventListener('submit', function(e) {
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
    hideIndicator: () => { if (passwordStrength) passwordStrength.hidden = true; }
  };
}

