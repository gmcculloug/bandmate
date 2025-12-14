/**
 * Band Huddle Shared JavaScript Utilities
 * Common functionality used across multiple views
 */

// Global search timeout for debounced input
let searchTimeout;

/**
 * URL parameter manipulation utilities
 */
const URLUtils = {
    /**
     * Get current URL as URL object for manipulation
     */
    getCurrentURL() {
        return new URL(window.location);
    },

    /**
     * Navigate to URL
     */
    navigateTo(url) {
        window.location.href = url.toString();
    },

    /**
     * Set URL parameter and navigate
     */
    setParam(key, value) {
        const url = this.getCurrentURL();
        url.searchParams.set(key, value);
        this.navigateTo(url);
    },

    /**
     * Remove URL parameter and navigate
     */
    removeParam(key) {
        const url = this.getCurrentURL();
        url.searchParams.delete(key);
        this.navigateTo(url);
    },

    /**
     * Toggle URL parameter (remove if present, add if not)
     */
    toggleParam(key, value) {
        const url = this.getCurrentURL();
        if (url.searchParams.get(key) === value) {
            url.searchParams.delete(key);
        } else {
            url.searchParams.set(key, value);
        }
        this.navigateTo(url);
    }
};

/**
 * Search functionality utilities
 */
const SearchUtils = {
    /**
     * Initialize search input with debounced input handling
     * @param {string} inputId - ID of the search input element
     * @param {number} debounceMs - Debounce delay in milliseconds (default: 300)
     * @param {Function} callback - Optional callback function for search
     */
    initializeSearch(inputId = 'search-input', debounceMs = 300, callback = null) {
        const searchInput = document.getElementById(inputId);
        if (!searchInput) return;

        searchInput.addEventListener('input', function() {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => {
                if (callback) {
                    callback(this.value);
                } else {
                    // Default behavior: update URL with search parameter
                    if (this.value.trim()) {
                        URLUtils.setParam('search', this.value.trim());
                    } else {
                        URLUtils.removeParam('search');
                    }
                }
            }, debounceMs);
        });

        // Handle Enter key
        searchInput.addEventListener('keypress', function(e) {
            if (e.key === 'Enter') {
                e.preventDefault();
                clearTimeout(searchTimeout);
                if (callback) {
                    callback(this.value);
                } else {
                    if (this.value.trim()) {
                        URLUtils.setParam('search', this.value.trim());
                    } else {
                        URLUtils.removeParam('search');
                    }
                }
            }
        });

        return searchInput;
    },

    /**
     * Clear search input and URL parameter
     * @param {string} inputId - ID of the search input element
     */
    clearSearch(inputId = 'search-input') {
        const searchInput = document.getElementById(inputId);
        if (searchInput) {
            searchInput.value = '';
            URLUtils.removeParam('search');
        }
    },

    /**
     * Setup global keyboard handling for search focus
     * @param {string} inputId - ID of the search input element
     */
    setupGlobalKeyboardSearch(inputId = 'search-input') {
        document.addEventListener('keydown', function(e) {
            const activeElement = document.activeElement;
            const isTypingInInput = activeElement && (
                activeElement.tagName === 'INPUT' ||
                activeElement.tagName === 'TEXTAREA' ||
                activeElement.tagName === 'SELECT' ||
                activeElement.isContentEditable
            );

            // Don't handle shortcuts when typing in inputs or with modifier keys
            if (isTypingInInput || e.ctrlKey || e.metaKey || e.altKey) {
                return;
            }

            const searchInput = document.getElementById(inputId);
            if (!searchInput) return;

            // Handle character input - focus search and add character
            if (e.key.length === 1 && /[a-zA-Z0-9\s]/.test(e.key)) {
                e.preventDefault();
                searchInput.focus();
                searchInput.value += e.key;
                searchInput.setSelectionRange(searchInput.value.length, searchInput.value.length);

                // Trigger search
                searchInput.dispatchEvent(new Event('input'));
            }
            // Handle backspace - remove last character from search
            else if (e.key === 'Backspace' && searchInput.value) {
                e.preventDefault();
                searchInput.value = searchInput.value.slice(0, -1);
                searchInput.focus();
                searchInput.setSelectionRange(searchInput.value.length, searchInput.value.length);

                // Trigger search
                searchInput.dispatchEvent(new Event('input'));
            }
            // Handle Escape - clear search if it has content
            else if (e.key === 'Escape' && searchInput.value.trim() !== '') {
                e.preventDefault();
                this.clearSearch(inputId);
            }
        }.bind(this));
    }
};

/**
 * Form utilities
 */
const FormUtils = {
    /**
     * Auto-populate field when another field changes (common for key/original_key)
     * @param {string} sourceId - ID of source input
     * @param {string} targetId - ID of target input to populate
     * @param {boolean} onlyWhenEmpty - Only populate if target is empty (default: true)
     */
    autoPopulateField(sourceId, targetId, onlyWhenEmpty = true) {
        const sourceInput = document.getElementById(sourceId);
        const targetInput = document.getElementById(targetId);

        if (!sourceInput || !targetInput) return;

        const populateTarget = () => {
            if (!onlyWhenEmpty || targetInput.value === '') {
                targetInput.value = sourceInput.value;
            }
        };

        sourceInput.addEventListener('input', populateTarget);
        sourceInput.addEventListener('change', populateTarget);
    }
};

/**
 * DOM ready utilities
 */
const DOMUtils = {
    /**
     * Execute function when DOM is ready
     * @param {Function} callback - Function to execute
     */
    ready(callback) {
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', callback);
        } else {
            callback();
        }
    },

    /**
     * Focus element and place cursor at end
     * @param {string|Element} elementOrId - Element or element ID
     */
    focusWithCursorAtEnd(elementOrId) {
        const element = typeof elementOrId === 'string'
            ? document.getElementById(elementOrId)
            : elementOrId;

        if (element && element.focus) {
            element.focus();
            if (element.setSelectionRange && element.value) {
                element.setSelectionRange(element.value.length, element.value.length);
            }
        }
    }
};

// Export utilities to global scope for backward compatibility
window.URLUtils = URLUtils;
window.SearchUtils = SearchUtils;
window.FormUtils = FormUtils;
window.DOMUtils = DOMUtils;

// Legacy function compatibility
window.clearSearch = function(inputId) {
    SearchUtils.clearSearch(inputId);
};