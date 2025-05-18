/**
 * Converts UTC timestamps to local time format
 * @param {string} selector - CSS selector for time elements with datetime attribute
 */
export function convertUTCTimesToLocal(selector = 'time[datetime]') {
  document.querySelectorAll(selector).forEach(timeElement => {
    const utcDateString = timeElement.getAttribute('datetime');
    if (utcDateString) {
      const date = new Date(utcDateString);
      const localDateString = date.toLocaleString(undefined, {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: false
      });
      timeElement.textContent = localDateString;
    }
  });
}

