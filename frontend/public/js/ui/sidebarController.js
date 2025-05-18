// /js/ui/sidebarController.js

/**
 * Initializes a responsive sidebar that toggles on mobile and stays open on desktop
 * @param {Object} options - Configuration options
 * @param {string} [options.sidebarId='sidebar'] - ID of the sidebar element
 * @param {string} [options.toggleButtonId='sidebarToggleBtn'] - ID of the toggle button
 * @param {string} [options.openClass='open'] - Class name for the open state
 * @param {number} [options.mobileBreakpoint=768] - Breakpoint for mobile view in pixels
 * @returns {Object} Controller with toggle, open, close, and isOpen methods
 */
export function initSidebar(options = {}) {
  const config = {
    sidebarId: 'sidebar',
    toggleButtonId: 'sidebarToggleBtn',
    openClass: 'open',
    mobileBreakpoint: 768,
    ...options,
  };

  const sidebar = document.getElementById(config.sidebarId);
  const toggleButton = document.getElementById(config.toggleButtonId);

  if (!sidebar || !toggleButton) {
    console.warn('Sidebar or Toggle Button not found. Sidebar functionality may be impaired.');
    return {
      toggle: () => {},
      open: () => {},
      close: () => {},
      isOpen: () => false,
    };
  }

  /**
   * Toggles sidebar visibility only on mobile devices
   */
  function toggleSidebarOnMobile() {
    if (window.innerWidth < config.mobileBreakpoint) {
      sidebar.classList.toggle(config.openClass);
    }
  }

  /**
   * Ensures correct sidebar state on window resize and initial load
   */
  function handleResizeAndInitialLoad() {
    const isMobile = window.innerWidth < config.mobileBreakpoint;

    if (!isMobile) {
      // On desktop: sidebar is always open via CSS and openClass is removed
      // to prevent unintended behavior with global CSS rules
      sidebar.classList.remove(config.openClass);
    }
    // On mobile: sidebar state is controlled by user interaction
  }

  // Event listeners
  toggleButton.addEventListener('click', toggleSidebarOnMobile);

  document.addEventListener('click', (event) => {
    const target = event.target;
    // Close sidebar when clicking outside on mobile
    if (
      window.innerWidth < config.mobileBreakpoint &&
      sidebar.classList.contains(config.openClass) &&
      !sidebar.contains(target) &&
      target !== toggleButton &&
      !toggleButton.contains(target)
    ) {
      sidebar.classList.remove(config.openClass);
    }
  });

  window.addEventListener('resize', handleResizeAndInitialLoad);

  // Set initial state on page load
  handleResizeAndInitialLoad();

  // Public API
  return {
    toggle: () => {
      if (window.innerWidth < config.mobileBreakpoint) {
        sidebar.classList.toggle(config.openClass);
      }
    },
    open: () => {
      if (window.innerWidth < config.mobileBreakpoint) {
        sidebar.classList.add(config.openClass);
      }
    },
    close: () => {
      if (window.innerWidth < config.mobileBreakpoint) {
        sidebar.classList.remove(config.openClass);
      }
    },
    isOpen: () => 
      sidebar.classList.contains(config.openClass) && 
      window.innerWidth < config.mobileBreakpoint,
  };
}

