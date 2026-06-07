/* htmx-toast.js — T-2074 (T-2063 GO scope)
 *
 * Self-contained toast handler for htmx error events. Extracted from base.html
 * (lines ~957-978) so standalone templates that don't extend base.html — notably
 * review.html — get the same red-toast-on-4xx UX as base-extending pages.
 *
 * Origin: T-2063 found that /review/T-XXX Complete button silently failed
 * because review.html doesn't extend base.html and the inline htmx error
 * listeners (base.html:970-978) never load → 403 toast never rendered.
 * Parallel to csrf-htmx.js (T-1453) which did the same extraction for the
 * CSRF + fetchWithCsrf helpers.
 *
 * Behaviour:
 *   1. Injects a #toast-container <div> on DOMContentLoaded if base.html
 *      hasn't already (covers standalone pages).
 *   2. Declares its own showToast(msg, type) but only assigns to window if
 *      base.html hasn't defined one — avoids double-definition collision.
 *   3. Wires htmx:responseError + htmx:sendError listeners on document.body
 *      using whichever showToast is currently on window (so base.html's
 *      richer/styled version wins when both load).
 *
 * Load order: this file MUST load AFTER htmx.min.js. On base-extending pages
 * the inline showToast remains for non-htmx callers; only the listeners move
 * here (base.html removes its inline addEventListener calls).
 */
(function() {
    'use strict';

    function ensureContainer() {
        if (document.getElementById('toast-container')) return;
        var c = document.createElement('div');
        c.id = 'toast-container';
        /* Minimal positioning so the container works even without base.html's CSS.
           base.html .toast-container styling will take precedence when present. */
        c.style.cssText = 'position:fixed; bottom:1rem; right:1rem; z-index:9999; '
            + 'display:flex; flex-direction:column; gap:0.5rem; pointer-events:none;';
        document.body.appendChild(c);
    }

    function fallbackShowToast(msg, type) {
        type = type || 'info';
        ensureContainer();
        var container = document.getElementById('toast-container');
        var toast = document.createElement('div');
        toast.className = 'wt-toast ' + type;
        toast.textContent = msg;
        /* Inline minimal style for standalone pages that lack base.html's .wt-toast CSS.
           When base.html's stylesheet is present, the .wt-toast class rule takes precedence. */
        var accent = (type === 'error') ? 'var(--wt-danger, #c62828)' : 'var(--pico-primary, #5d75ff)';
        toast.style.cssText = 'padding: 0.6rem 1rem; border-radius: 4px; '
            + 'background: var(--pico-card-background-color, #ffffff); '
            + 'color: var(--pico-color, #1d1d1f); border-left: 3px solid ' + accent + '; '
            + 'box-shadow: 0 2px 8px rgba(0,0,0,0.15); pointer-events:auto; '
            + 'max-width: 22rem; font-size: 0.9rem; line-height: 1.4;';
        container.appendChild(toast);
        setTimeout(function() {
            toast.style.transition = 'opacity 0.3s';
            toast.style.opacity = '0';
            setTimeout(function() { toast.remove(); }, 300);
        }, 3000);
    }

    /* Avoid double-definition: base.html already declares showToast. Only
       publish ours on standalone pages where window.showToast is undefined. */
    if (typeof window.showToast !== 'function') {
        window.showToast = fallbackShowToast;
    }

    function getShowToast() {
        return (typeof window.showToast === 'function') ? window.showToast : fallbackShowToast;
    }

    function init() {
        ensureContainer();

        document.body.addEventListener('htmx:responseError', function(evt) {
            var msg = 'Save failed';
            try {
                msg = (evt.detail.xhr.responseText || '')
                    .replace(/<[^>]*>/g, '')
                    .trim()
                    .substring(0, 100) || msg;
            } catch (e) { /* fall through with default msg */ }
            getShowToast()(msg, 'error');
        });

        document.body.addEventListener('htmx:sendError', function() {
            getShowToast()('Network error — check server', 'error');
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
