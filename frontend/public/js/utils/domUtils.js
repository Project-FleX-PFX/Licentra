// /js/utils/domUtils.js

/**
 * Shows an element by removing the 'd-none' class
 * @param {HTMLElement|string} element - DOM element or element ID
 */
export function showElement(element) {
  const el = typeof element === 'string' ? document.getElementById(element) : element;
  if (el) el.classList.remove('d-none');
}

/**
 * Hides an element by adding the 'd-none' class
 * @param {HTMLElement|string} element - DOM element or element ID
 */
export function hideElement(element) {
  const el = typeof element === 'string' ? document.getElementById(element) : element;
  if (el) el.classList.add('d-none');
}

/**
 * Sets the hidden attribute of an element
 * @param {HTMLElement|string} element - DOM element or element ID
 * @param {boolean} isHidden - Whether the element should be hidden
 */
export function setHidden(element, isHidden) {
  const el = typeof element === 'string' ? document.getElementById(element) : element;
  if (el) el.hidden = isHidden;
}

/**
 * Sets the text content of an element
 * @param {HTMLElement|string} element - DOM element or element ID
 * @param {string} text - The text to set
 */
export function setText(element, text) {
  const el = typeof element === 'string' ? document.getElementById(element) : element;
  if (el) el.textContent = text;
}

/**
 * Updates the class list of an element
 * @param {HTMLElement|string} element - DOM element or element ID
 * @param {string} addClass - Class to add
 * @param {string} removeClass - Class to remove
 */
export function updateElementClass(element, addClass, removeClass) {
  const el = typeof element === 'string' ? document.getElementById(element) : element;
  if (el) {
    if (removeClass) el.classList.remove(removeClass);
    if (addClass) el.classList.add(addClass);
  }
}

