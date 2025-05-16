// frontend/public/js/features/admin/adminUtils.js

const modalInstances = {}; // Cache für initialisierte Bootstrap Modal Instanzen

/**
 * Initialisiert ein Bootstrap Modal, falls noch nicht geschehen, und gibt die Instanz zurück.
 * @param {string} modalId Die ID des Modal-Elements.
 * @returns {bootstrap.Modal|null} Die Bootstrap Modal Instanz oder null.
 */
export function initializeModal(modalId) {
  if (!modalInstances[modalId]) {
    const modalElement = document.getElementById(modalId);
    if (modalElement) {
      modalInstances[modalId] = new bootstrap.Modal(modalElement);
    } else {
      console.warn(`Modal element with ID '${modalId}' not found.`);
      return null;
    }
  }
  return modalInstances[modalId];
}

/**
 * Zeigt ein Modal an. Initialisiert es, falls nötig.
 * @param {string|bootstrap.Modal} modalIdOrInstance Die ID des Modals oder die bereits initialisierte Instanz.
 */
export function showModal(modalIdOrInstance) {
  let instance = modalIdOrInstance;
  if (typeof modalIdOrInstance === 'string') {
    instance = initializeModal(modalIdOrInstance);
  }
  if (instance && typeof instance.show === 'function') {
    instance.show();
  }
}

/**
 * Versteckt ein Modal.
 * @param {string|bootstrap.Modal} modalIdOrInstance Die ID des Modals oder die bereits initialisierte Instanz.
 */
export function hideModal(modalIdOrInstance) {
  let instance = modalIdOrInstance;
  if (typeof modalIdOrInstance === 'string') {
    instance = modalInstances[modalIdOrInstance]; // Hole aus Cache
  }
  if (instance && typeof instance.hide === 'function') {
    instance.hide();
  }
}

/**
 * Aktiviert oder deaktiviert Formularfelder.
 * @param {HTMLFormElement} formElement Das Formular-Element.
 * @param {boolean} disabled True, um Felder zu deaktivieren, false, um sie zu aktivieren.
 * @param {string[]} except Array von IDs oder Namen von Feldern, die ausgenommen werden sollen.
 */
export function setFormFieldsDisabled(formElement, disabled, except = []) {
  if (!formElement || !formElement.elements) return;
  [...formElement.elements].forEach((el) => {
    if (el.type === 'hidden' || except.includes(el.id) || except.includes(el.name) || el.tagName === 'BUTTON') {
      // Buttons im Formular werden typischerweise separat gehandhabt
      return;
    }
    el.disabled = disabled;
  });
}

/**
 * Befüllt Formularfelder mit Daten.
 * Konvertiert Kebab-Case data-* Attribute zu CamelCase für den Abgleich mit Feldnamen.
 * @param {HTMLFormElement} formElement Das Formular-Element.
 * @param {object} data Ein Objekt mit Daten (oft aus dataset).
 * @param {object} fieldMappings Ein optionales Mapping von Formularfeldnamen zu Daten-Keys.
 */
export function populateForm(formElement, data = {}, fieldMappings = {}) {
  if (!formElement) return;
  formElement.reset(); 

  console.log("Populating form with data:", data); // Behalte dieses Log
  console.log("Using field mappings:", fieldMappings); // Behalte dieses Log

  for (const key in formElement.elements) {
    if (formElement.elements.hasOwnProperty(key)) {
      const element = formElement.elements[key];
      const elementName = element.name || element.id;
      if (!elementName) continue;

      // --- SPEZIFISCHE LOGIK FÜR roles[] GANZ NACH OBEN ---
      if (elementName === 'roles[]' && element.type === 'checkbox') {
        const userRoleIdsString = data['role-ids'] || data['roleIds'] || data['data-role-ids'] /* explizit für rohes HTML-Attribut */ || '';
        console.log(`[roles[] handler] For checkbox group 'roles[]', found role IDs string: '${userRoleIdsString}' from data object:`, data);
        const userRoleIds = userRoleIdsString ? String(userRoleIdsString).split(',') : [];
        
        // Checkbox-spezifische Logik
        if (userRoleIds.includes(element.value)) {
            element.checked = true;
            console.log(`[roles[] handler] Checked role checkbox with value '${element.value}'.`);
        } else {
            element.checked = false;
             // console.log(`[roles[] handler] Unchecked role checkbox with value '${element.value}'.`);
        }
        continue; // WICHTIG: Gehe zur nächsten Iteration im äußeren Loop
      }
      // --- ENDE SPEZIFISCHE LOGIK FÜR roles[] ---


      let valueToSet;
      // Schlüsselvarianten ausprobieren (Mappings, direkter Name, CamelCase aus Kebab-Case)
      const dataKeyFromMapping = fieldMappings[elementName];
      const keyVariationsToTry = [
          dataKeyFromMapping, // Von Mapping
          elementName,        // Direkter Name
          elementName.replace(/-([a-z])/g, g => g[1].toUpperCase()), // kebab-case zu camelCase
          elementName.replace(/_([a-z])/g, g => g[1].toUpperCase())   // snake_case zu camelCase
      ].filter(k => k); // Entferne undefined/null Kandidaten

      for (const dataKey of keyVariationsToTry) {
          if (data[dataKey] !== undefined) {
              valueToSet = data[dataKey];
              // console.log(`[Generic handler] Found value for '${elementName}' using dataKey '${dataKey}':`, valueToSet);
              break;
          }
      }
      // Zusätzlicher Check für das direkte dataset-Attribut (kebab-case)
      if (valueToSet === undefined) {
          const kebabKey = elementName.replace(/([A-Z])/g, (match, p1, offset) => (offset > 0 ? '-' : '') + p1.toLowerCase());
          if (data[kebabKey] !== undefined) {
              valueToSet = data[kebabKey];
              // console.log(`[Generic handler] Found value for '${elementName}' using direct kebabKey '${kebabKey}':`, valueToSet);
          }
      }


      if (valueToSet !== undefined && valueToSet !== null) {
        if (element.type === 'checkbox' && !element.name.endsWith('[]')) { // Einzelne Checkbox
          element.checked = valueToSet === true || String(valueToSet).toLowerCase() === 'true' || String(valueToSet) === element.value;
        } else if (element.tagName === 'SELECT') {
          element.value = String(valueToSet);
        } else if (element.type === 'date' && valueToSet) {
          try {
            const dateObj = new Date(valueToSet);
            const offset = dateObj.getTimezoneOffset() * 60000;
            element.value = new Date(dateObj.getTime() + offset).toISOString().split('T')[0];
          } catch (e) { element.value = valueToSet; }
        } else if (element.type === 'number' && element.step === '0.01' && String(valueToSet).trim() !== '') {
          const numValue = parseFloat(valueToSet);
          element.value = isNaN(numValue) ? '' : numValue.toFixed(2);
        } else if (element.type !== 'checkbox') { // Stelle sicher, dass wir nicht erneut Checkboxen behandeln
          element.value = String(valueToSet);
        }
        // console.log(`[Generic handler] Set value for '${elementName}' to:`, element.value, `(checked: ${element.checked})`);
      } else if (element.type !== 'hidden' && element.tagName !== 'BUTTON' && element.type !== 'checkbox' && !element.name.endsWith('[]')) {
        element.value = ''; // Nur leeren, wenn kein Wert gefunden UND es keine Checkbox ist
        // console.log(`[Generic handler] No value found for '${elementName}', reset to empty.`);
      }
    }
  }
}
/**
 * Setzt ein Formular zurück und deaktiviert optional Felder.
 * @param {HTMLFormElement} formElement
 * @param {function} [populateFn=populateForm] Funktion zum Befüllen (wird hier mit leeren Daten für Reset genutzt)
 * @param {function} [setDisabledFn=setFormFieldsDisabled] Funktion zum Deaktivieren
 */
export function resetAndClearForm(formElement, populateFn = populateForm, setDisabledFn = setFormFieldsDisabled) {
    if (!formElement) return;
    if (typeof populateFn === 'function') {
        populateFn(formElement, {}); // Mit leeren Daten befüllen = reset
    } else {
        formElement.reset(); // Fallback
    }
    if (typeof setDisabledFn === 'function') {
        // Deaktiviere alle Felder, außer Buttons, die separat gehandhabt werden.
        setDisabledFn(formElement, true, ['editBtn', 'saveBtn', 'deleteBtn', 'editUserBtn', 'saveUserBtn', 'deleteUserBtn', 'editProductBtn', 'saveProductBtn', 'deleteProductBtn', 'editLicenseFormBtn', 'saveLicenseBtn', 'deleteLicenseBtn', 'createLicenseBtn']);
    }
}

/**
 * Generischer Handler für Formular-Submits (POST/PUT).
 * Löst immer einen Seiten-Reload aus, um Flash-Nachrichten anzuzeigen.
 */
export async function handleFormSubmit({ event, formElement, itemId, baseUrl, methodOverride = null }) {
    event.preventDefault();
    if (!formElement || !formElement.checkValidity()) {
        if (formElement) formElement.reportValidity();
        return;
    }

    const formDataObj = new FormData(formElement);
    const finalSearchParams = new URLSearchParams();
    const roles = [];
    formDataObj.forEach((value, key) => {
        if (key === 'roles[]') {
            roles.push(value);
        } else if (key === 'password' && value.trim() === '' && methodOverride === 'PUT') {
            // Leeres Passwort bei PUT nicht senden
        } else if (value.trim() === '' && (key === 'expire_date' || key === 'vendor' || key === 'notes')) {
            // Optionale Felder nicht senden, wenn leer
        } else {
            finalSearchParams.set(key, value);
        }
    });
    roles.forEach(roleId => finalSearchParams.append('roles[]', roleId));

    let effectiveMethod = formElement.method ? formElement.method.toUpperCase() : 'POST';
    if (itemId) {
        effectiveMethod = methodOverride || 'PUT';
    }

    // Sicherstellen, dass effectiveMethod niemals GET oder HEAD ist, wenn ein Body gesendet wird
    if (effectiveMethod === 'GET' || effectiveMethod === 'HEAD') {
        console.warn(`Method ${effectiveMethod} cannot have a body. Forcing to POST.`);
        effectiveMethod = 'POST';
    }

    let url = baseUrl;
    if (itemId) {
        url = `${baseUrl}/${itemId}`;
    }

    try {
        const response = await fetch(url, {
            method: effectiveMethod,
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: finalSearchParams.toString()
        });
        // Logge den Status für Debugging-Zwecke, aber kein Abbruch bei Fehler
        if (!response.ok) {
            console.error(`Form submission failed with status ${response.status}: ${response.statusText}`);
            // Optional: Fehlermeldung loggen, aber kein alert mehr, da Reload immer erfolgt
            try {
                const errorText = await response.text();
                if (errorText) console.error(`Error details: ${errorText}`);
            } catch (e) {
                console.error('Could not read error response text:', e);
            }
        }
    } catch (error) {
        console.error('Form submission error:', error);
        // Kein alert mehr, da Reload immer erfolgt
    } finally {
        window.location.reload(); // Immer reload für Flash-Nachrichten
    }
}

/**
 * Generischer Handler für Delete-Operationen.
 * Löst immer einen Seiten-Reload aus, um Flash-Nachrichten anzuzeigen.
 */
export async function handleDelete({ itemId, baseUrl, modalToDeleteInstance = null }) {
    if (!itemId) {
        console.error('No item ID provided for deletion.');
        alert('Cannot delete: Item ID is missing.');
        return;
    }
    const url = `${baseUrl}/${itemId}`;
    try {
        const response = await fetch(url, { method: 'DELETE' });
        if (!response.ok) {
            console.error(`Delete failed with status ${response.status}: ${response.statusText}`);
            try {
                const errorText = await response.text();
                if (errorText) console.error(`Error details: ${errorText}`);
            } catch (e) {
                console.error('Could not read error response text:', e);
            }
        }
    } catch (error) {
        console.error('Deletion error:', error);
    } finally {
        if (modalToDeleteInstance) hideModal(modalToDeleteInstance);
        window.location.reload(); // Immer reload für Flash-Nachrichten
    }
}

/**
 * Generischer Fetch-Wrapper für Aktionen, die keinen vollständigen Form-Submit erfordern.
 * Löst immer einen Seiten-Reload aus, um Flash-Nachrichten anzuzeigen.
 */
export async function fetchAndReload(url, options = {}, modalToHideOnError = null) {
    try {
        const response = await fetch(url, options);
        if (!response.ok) {
            console.error(`Fetch failed with status ${response.status}: ${response.statusText}`);
            try {
                const errorText = await response.text();
                if (errorText) console.error(`Error details: ${errorText}`);
            } catch (e) {
                console.error('Could not read error response text:', e);
            }
        }
    } catch (error) {
        console.error('Fetch error:', url, error);
    } finally {
        if (modalToHideOnError) hideModal(modalToHideOnError);
        window.location.reload(); // Immer reload für Flash-Nachrichten
    }
}
// DOM Utilities
export function showElement(elementOrId) {
    const element = typeof elementOrId === 'string' ? document.getElementById(elementOrId) : elementOrId;
    if (element) element.style.display = ''; // Revert to default display (block, inline, etc.)
}

export function hideElement(elementOrId) {
    const element = typeof elementOrId === 'string' ? document.getElementById(elementOrId) : elementOrId;
    if (element) element.style.display = 'none';
}

export function setText(elementOrId, text) {
    const element = typeof elementOrId === 'string' ? document.getElementById(elementOrId) : elementOrId;
    if (element) element.textContent = text;
}

export function setHtml(elementOrId, html) {
    const element = typeof elementOrId === 'string' ? document.getElementById(elementOrId) : elementOrId;
    if (element) element.innerHTML = html;
}

