// frontend/public/js/features/admin/adminUtils.js

// Cache for initialized Bootstrap Modal instances
const modalInstances = {};

/**
 * Initializes a Bootstrap Modal if not already done and returns the instance
 * @param {string} modalId - The ID of the modal element
 * @returns {bootstrap.Modal|null} The Bootstrap Modal instance or null
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
 * Shows a modal, initializing it if necessary
 * @param {string|bootstrap.Modal} modalIdOrInstance - The modal ID or initialized instance
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
 * Hides a modal
 * @param {string|bootstrap.Modal} modalIdOrInstance - The modal ID or initialized instance
 */
export function hideModal(modalIdOrInstance) {
  let instance = modalIdOrInstance;
  if (typeof modalIdOrInstance === 'string') {
    instance = modalInstances[modalIdOrInstance]; // Get from cache
  }
  if (instance && typeof instance.hide === 'function') {
    instance.hide();
  }
}

/**
 * Enables or disables form fields
 * @param {HTMLFormElement} formElement - The form element
 * @param {boolean} disabled - True to disable fields, false to enable them
 * @param {string[]} except - Array of IDs or names of fields to exclude
 */
export function setFormFieldsDisabled(formElement, disabled, except = []) {
  if (!formElement || !formElement.elements) return;
  [...formElement.elements].forEach((el) => {
    if (el.type === 'hidden' || except.includes(el.id) || except.includes(el.name) || el.tagName === 'BUTTON') {
      // Buttons in the form are typically handled separately
      return;
    }
    el.disabled = disabled;
  });
}

/**
 * Populates form fields with data
 * Converts kebab-case data-* attributes to camelCase for matching with field names
 * @param {HTMLFormElement} formElement - The form element
 * @param {object} data - An object with data (often from dataset)
 * @param {object} fieldMappings - Optional mapping from form field names to data keys
 */
export function populateForm(formElement, data = {}, fieldMappings = {}) {
  if (!formElement) return;
  formElement.reset(); // Reset fields to their initial HTML value (important!)

  for (const key in formElement.elements) {
    if (formElement.elements.hasOwnProperty(key)) {
      const element = formElement.elements[key];
      const elementName = element.name || element.id;
      if (!elementName) continue;

      // Special logic for 'roles[]'
      if (elementName === 'roles[]' && element.type === 'checkbox') {
        const userRoleIdsString = data['role-ids'] || data['roleIds'] || data['data-role-ids'] || '';
        const userRoleIds = userRoleIdsString ? String(userRoleIdsString).split(',') : [];
        
        element.checked = userRoleIds.includes(element.value);
        continue; 
      }

      let valueToSet;
      const dataKeyFromMapping = fieldMappings[elementName];
      const keyVariationsToTry = [
        dataKeyFromMapping, 
        elementName,        
        elementName.replace(/-([a-z])/g, g => g[1].toUpperCase()), 
        elementName.replace(/_([a-z])/g, g => g[1].toUpperCase()),
      ].filter(k => k); 

      for (const dataKey of keyVariationsToTry) {
        if (data[dataKey] !== undefined) {
          valueToSet = data[dataKey];
          break;
        }
      }
      
      if (valueToSet === undefined) {
        const kebabKey = elementName.replace(/([A-Z])/g, (match, p1, offset) => (offset > 0 ? '-' : '') + p1.toLowerCase());
        if (data[kebabKey] !== undefined) {
          valueToSet = data[kebabKey];
        }
      }

      if (valueToSet !== undefined && valueToSet !== null) {
        if (element.type === 'checkbox' && !element.name.endsWith('[]')) { 
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
        } else if (element.type !== 'checkbox') { 
          element.value = String(valueToSet);
        }
      } else {
        // No valueToSet found (e.g., when resetting with empty 'data' object)
        // Explicitly clear fields, INCLUDING HIDDEN FIELDS like userIdField
        if (element.tagName === 'BUTTON' || (element.type === 'checkbox' && element.name.endsWith('[]'))) {
          // Buttons and checkbox groups (like roles[]) are not cleared here
        } else if (element.type === 'checkbox' || element.type === 'radio') {
          element.checked = false; // Uncheck individual checkboxes/radios
        } else {
          element.value = ''; // Clear all other input types (text, hidden, email, etc.)
        }
      }
    }
  }
}

/**
 * Resets a form and optionally disables fields
 * @param {HTMLFormElement} formElement - The form element
 * @param {function} [populateFn=populateForm] - Function for populating (used with empty data for reset)
 * @param {function} [setDisabledFn=setFormFieldsDisabled] - Function for disabling
 */
export function resetAndClearForm(formElement, populateFn = populateForm, setDisabledFn = setFormFieldsDisabled) {
  if (!formElement) return;
  if (typeof populateFn === 'function') {
    populateFn(formElement, {}); // Populate with empty data = reset
  } else {
    formElement.reset(); // Fallback
  }
  if (typeof setDisabledFn === 'function') {
    // Disable all fields except buttons, which are handled separately
    setDisabledFn(formElement, true, [
      'editBtn', 'saveBtn', 'deleteBtn', 
      'editUserBtn', 'saveUserBtn', 'deleteUserBtn', 
      'editProductBtn', 'saveProductBtn', 'deleteProductBtn', 
      'editLicenseFormBtn', 'saveLicenseBtn', 'deleteLicenseBtn', 'createLicenseBtn',
    ]);
  }
}

/**
 * Generic handler for form submissions (POST/PUT)
 * Always triggers a page reload to show flash messages
 * @param {Object} options - Options object
 * @param {Event} options.event - The submit event
 * @param {HTMLFormElement} options.formElement - The form element
 * @param {string} options.itemId - ID of the item being edited (if any)
 * @param {string} options.baseUrl - Base URL for the request
 * @param {string} [options.methodOverride=null] - HTTP method override
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
      // Don't send empty password on PUT
    } else if (value.trim() === '' && (key === 'expire_date' || key === 'vendor' || key === 'notes')) {
      // Don't send optional fields if empty
    } else {
      finalSearchParams.set(key, value);
    }
  });
  roles.forEach(roleId => finalSearchParams.append('roles[]', roleId));

  let effectiveMethod = formElement.method ? formElement.method.toUpperCase() : 'POST';
  if (itemId) {
    effectiveMethod = methodOverride || 'PUT';
  }

  // Ensure effectiveMethod is never GET or HEAD when sending a body
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
      body: finalSearchParams.toString(),
    });
    // Log status for debugging purposes, but don't abort on error
    if (!response.ok) {
      console.error(`Form submission failed with status ${response.status}: ${response.statusText}`);
      // Optional: Log error message, but no more alerts since reload always happens
      try {
        const errorText = await response.text();
        if (errorText) console.error(`Error details: ${errorText}`);
      } catch (e) {
        console.error('Could not read error response text:', e);
      }
    }
  } catch (error) {
    console.error('Form submission error:', error);
  } finally {
    window.location.reload(); // Always reload for flash messages
  }
}

/**
 * Generic handler for delete operations
 * Always triggers a page reload to show flash messages
 * @param {Object} options - Options object
 * @param {string} options.itemId - ID of the item to delete
 * @param {string} options.baseUrl - Base URL for the request
 * @param {bootstrap.Modal} [options.modalToDeleteInstance=null] - Modal to hide after deletion
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
    window.location.reload(); // Always reload for flash messages
  }
}

/**
 * Generic fetch wrapper for actions that don't require a full form submit
 * Always triggers a page reload to show flash messages
 * @param {string} url - URL to fetch
 * @param {Object} [options={}] - Fetch options
 * @param {bootstrap.Modal} [modalToHideOnError=null] - Modal to hide on error
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
    window.location.reload(); // Always reload for flash messages
  }
}

/**
 * Shows an element by resetting its display property
 * @param {HTMLElement|string} elementOrId - Element or element ID
 */
export function showElement(elementOrId) {
  const element = typeof elementOrId === 'string' ? document.getElementById(elementOrId) : elementOrId;
  if (element) element.style.display = ''; // Revert to default display (block, inline, etc.)
}

/**
 * Hides an element by setting display to none
 * @param {HTMLElement|string} elementOrId - Element or element ID
 */
export function hideElement(elementOrId) {
  const element = typeof elementOrId === 'string' ? document.getElementById(elementOrId) : elementOrId;
  if (element) element.style.display = 'none';
}

/**
 * Sets the text content of an element
 * @param {HTMLElement|string} elementOrId - Element or element ID
 * @param {string} text - Text to set
 */
export function setText(elementOrId, text) {
  const element = typeof elementOrId === 'string' ? document.getElementById(elementOrId) : elementOrId;
  if (element) element.textContent = text;
}

/**
 * Sets the HTML content of an element
 * @param {HTMLElement|string} elementOrId - Element or element ID
 * @param {string} html - HTML content to set
 */
export function setHtml(elementOrId, html) {
  const element = typeof elementOrId === 'string' ? document.getElementById(elementOrId) : elementOrId;
  if (element) element.innerHTML = html;
}

