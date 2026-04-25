// CSRF token injection for htmx + fetch.
// Loaded from web/templates/base.html and web/templates/review.html (T-1453).
// Required because csrf_protect (T-1343 / G-048) returns 403 on /api/* without X-CSRF-Token.
// Standalone templates (no base.html extension) MUST also load this script.

(function () {
    function getCsrfToken() {
        var meta = document.querySelector('meta[name="csrf-token"]');
        return meta ? meta.getAttribute('content') : null;
    }

    function attachListener() {
        document.body.addEventListener('htmx:configRequest', function (event) {
            var token = getCsrfToken();
            if (token) {
                event.detail.headers['X-CSRF-Token'] = token;
            }
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', attachListener);
    } else {
        attachListener();
    }

    window.fetchWithCsrf = function (url, options) {
        options = options || {};
        var method = (options.method || 'GET').toUpperCase();
        if (method !== 'GET' && method !== 'HEAD') {
            var token = getCsrfToken();
            if (token) {
                options.headers = options.headers || {};
                options.headers['X-CSRF-Token'] = token;
            }
        }
        return fetch(url, options);
    };
})();
