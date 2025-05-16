// frontend/public/js/features/licenses/licenseHistoryHandler.js

function convertUtcToLocalAndDisplay() {
  document.querySelectorAll('.local-timestamp').forEach(element => {
    const utcTimestampStr = element.dataset.utcTimestamp;
    if (utcTimestampStr) {
      try {
        const utcDate = new Date(utcTimestampStr);
        
        const options = {
          year: 'numeric', month: '2-digit', day: '2-digit',
          hour: '2-digit', minute: '2-digit', second: '2-digit',
          hour12: false 
        };
        
        element.textContent = utcDate.toLocaleString(undefined, options);
        element.title = `UTC: ${utcTimestampStr.replace('T', ' ').replace('Z', '')}`;
      } catch (e) {
        console.error("Error converting UTC timestamp to local:", utcTimestampStr, e);
        element.textContent = element.textContent || "Invalid date"; 
      }
    }
  });
}

// Diese Funktion wird exportiert und von der ERB-Datei aufgerufen
export function initLicenseHistoryPage() {
  convertUtcToLocalAndDisplay();
  // Hier könnten weitere JS-Funktionen für die History-Seite initialisiert werden,
  // z.B. wenn die Admin-Filter clientseitig interaktiver wären (aktuell sind sie Form-Submits).
}

