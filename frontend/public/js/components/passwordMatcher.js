// /js/components/passwordMatcher.js
export function initPasswordMatcher(options = {}) {
  const config = {
    passwordInputId: 'password',
    confirmInputId: 'password_confirmation',
    matchCheckId: 'match',
    ...options
  };

  const passwordInput = document.getElementById(config.passwordInputId);
  const confirmInput = document.getElementById(config.confirmInputId);
  const matchCheck = document.getElementById(config.matchCheckId);

  if (!passwordInput || !confirmInput || !matchCheck) return;

  // Hide match check element initially
  matchCheck.hidden = true;

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
    } else {
      matchCheck.classList.remove('text-success');
      matchCheck.classList.add('text-danger');
      matchCheck.innerHTML = '<i class="fas fa-times-circle"></i> Passwords do not match';
      return false;
    }
  }

  // Attach event listeners
  confirmInput.addEventListener('keyup', checkPasswordMatch);
  confirmInput.addEventListener('focus', function() {
    if (confirmInput.value !== '') {
      checkPasswordMatch();
    }
  });

  passwordInput.addEventListener('keyup', function() {
    if (confirmInput.value !== '') {
      checkPasswordMatch();
    }
  });

  // Add form submission validation
  if (passwordInput.form) {
    passwordInput.form.addEventListener('submit', function(e) {
      if (confirmInput.value !== '' && !checkPasswordMatch()) {
        e.preventDefault();
        matchCheck.hidden = false;
      }
    });
  }

  // Return public methods
  return {
    check: checkPasswordMatch
  };
}

