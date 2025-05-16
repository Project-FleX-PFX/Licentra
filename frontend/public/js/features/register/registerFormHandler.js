// /js/features/register/registerFormHandler.js
import { initPasswordMatcher } from '../../components/passwordMatcher.js';
import { initPasswordStrengthChecker } from '../../components/passwordStrengthChecker.js';

document.addEventListener('DOMContentLoaded', () => {
  // Initialisiere die Passwort-Komponenten
  const passwordMatcher = initPasswordMatcher();
  const passwordStrengthChecker = initPasswordStrengthChecker();
  
  // Formular-Validierung beim Absenden
  const registerForm = document.getElementById('register-form');
  if (registerForm) {
    registerForm.addEventListener('submit', function(e) {
      // Prüfe Passwort-Anforderungen
      if (!passwordStrengthChecker.validate()) {
        e.preventDefault();
        passwordStrengthChecker.showIndicator();
      }
      
      // Prüfe Passwort-Übereinstimmung (falls nicht bereits durch passwordMatcher geprüft)
      if (!passwordMatcher.check()) {
        e.preventDefault();
      }
    });
  }
});

