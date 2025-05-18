// frontend/public/js/features/licenses/licenseHistoryHandler.js
import { convertUTCTimesToLocal } from '../../utils/index.js';

/**
 * Initializes the license history page
 * Converts UTC timestamps to local time format
 */
export function initLicenseHistoryPage() {
  convertUTCTimesToLocal('time.local-timestamp');
}

