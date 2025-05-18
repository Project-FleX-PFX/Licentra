// /js/features/navigation/navbarHandler.js
import { initSidebar } from '../../ui/sidebarController.js';

/**
 * Initializes navigation components when DOM is ready
 */
function initNavigation() {
  // Initialize sidebar with default configuration
  const sidebarController = initSidebar();
  
  // Additional navigation-specific functionality could be added here
  // e.g., highlighting active menu items, managing submenus, etc.
}

// Initialize navigation when DOM is ready
document.addEventListener('DOMContentLoaded', initNavigation);

