// /js/core/profileService.js
export async function updateProfileData(field, newValue) {
  try {
    const response = await fetch('/update_profile', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        // Ggf. CSRF-Token hier einfügen, falls benötigt
        // 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: `field=${encodeURIComponent(field)}&value=${encodeURIComponent(newValue)}`
    });

    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.message || 'Network response was not ok');
    }
    return data; // Enthält { success: true, ... } oder { success: false, message: '...' }
  } catch (error) {
    console.error('Error updating profile:', error);
    return { 
      success: false, 
      message: error.message || 'Failed to update profile. Please try again.' 
    };
  }
}

