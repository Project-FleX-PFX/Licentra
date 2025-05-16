// /js/utils/domUtils.js
export function showElement(element) {
  if (element) element.classList.remove('d-none');
}

export function hideElement(element) {
  if (element) element.classList.add('d-none');
}

export function setHidden(element, isHidden) {
  if (element) element.hidden = isHidden;
}

export function setText(element, text) {
  if (element) element.textContent = text;
}

export function updateElementClass(element, addClass, removeClass) {
  if (element) {
    if (removeClass) element.classList.remove(removeClass);
    if (addClass) element.classList.add(addClass);
  }
}

