// /js/core/profileService.js

/**
 * Updates a specific field in the user profile
 * @param {string} field - The profile field to update
 * @param {string} newValue - The new value for the field
 * @returns {Promise<Object>} Response object with success status and optional message
 */
export async function updateProfileData(field, newValue) {
  try {
    const response = await fetch('/update_profile', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: `field=${encodeURIComponent(field)}&value=${encodeURIComponent(newValue)}`,
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || 'Network response was not ok');
    }
    return data;
  } catch (error) {
    console.error('Error updating profile:', error);
    return { 
      success: false, 
      message: error.message || 'Failed to update profile. Please try again.',
    };
  }
}

