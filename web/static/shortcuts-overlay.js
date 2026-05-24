/* ? Keyboard-shortcuts overlay — T-2013, arc-007 S6b.
 *
 * A read-only cheat-sheet listing the live keyboard shortcuts (⌘K, ?, Esc, …).
 * You can't use shortcuts you don't know exist; this makes the keyboard surface
 * (introduced by S6a, T-2012) discoverable.
 *
 * Lives in the shell (base.html), so its document-level listener attaches once
 * and survives htmx #content swaps. Static markup — no backend. Opening it closes
 * the ⌘K palette (one modal at a time); `?` is ignored while a text input is
 * focused so it types normally there.
 */
(function () {
  "use strict";

  var overlay;

  function load() {
    overlay = document.getElementById("wt-shortcuts-overlay");
    return !!overlay;
  }

  function isOpen() {
    return overlay && !overlay.hasAttribute("hidden");
  }

  function open() {
    if (!overlay) return;
    // mutual exclusion: never stack on top of the command palette or task panel
    var pal = document.getElementById("wt-command-palette");
    if (pal && !pal.hasAttribute("hidden")) {
      pal.setAttribute("hidden", "");
      pal.setAttribute("aria-hidden", "true");
    }
    if (window.wtTaskPanelClose) window.wtTaskPanelClose();
    overlay.removeAttribute("hidden");
    overlay.setAttribute("aria-hidden", "false");
  }

  function close() {
    if (!overlay) return;
    overlay.setAttribute("hidden", "");
    overlay.setAttribute("aria-hidden", "true");
  }

  function inTextInput(el) {
    if (!el) return false;
    var tag = (el.tagName || "").toLowerCase();
    return tag === "input" || tag === "textarea" || tag === "select" || el.isContentEditable;
  }

  function onKeydown(e) {
    // `?` (needs Shift, so allow it) opens/closes — but not while typing in a field
    if (e.key === "?" && !e.metaKey && !e.ctrlKey && !e.altKey) {
      if (inTextInput(e.target)) return; // let "?" type normally
      e.preventDefault();
      isOpen() ? close() : open();
      return;
    }
    if (isOpen() && e.key === "Escape") {
      e.preventDefault();
      close();
    }
  }

  function init() {
    if (!load()) return;
    document.addEventListener("keydown", onKeydown);
    document.addEventListener("click", function (e) {
      var closer = e.target.closest("[data-shortcuts-close]");
      if (closer && isOpen()) {
        e.preventDefault();
        close();
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
