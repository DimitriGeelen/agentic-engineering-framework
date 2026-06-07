// Slide-in task side panel — arc-007 S4a (T-2015).
//
// Clicking a task card/row on /tasks (any element carrying data-task-panel="T-XXX")
// opens a slide-in panel and loads the lean read fragment /tasks/<id>/panel into it
// via htmx, instead of a full-page nav. Dock controls (left/right/bottom/full) set a
// class on the panel and persist the choice per-browser (/settings/panel-dock/save).
//
// Like the ⌘K palette (command-palette.js) and ? overlay (shortcuts-overlay.js), the
// panel lives in base.html OUTSIDE #content, so this single delegated listener set
// survives every htmx #content swap with no re-binding. Mutual exclusion: opening the
// panel closes those modals, and they close the panel (see their open()).
(function () {
  "use strict";

  var DOCKS = ["left", "right", "bottom", "full"];

  function panel() { return document.getElementById("wt-task-panel"); }
  function body() { return document.getElementById("wt-task-panel-body"); }

  function isOpen() {
    var p = panel();
    return p && !p.hasAttribute("hidden");
  }

  function closeOthers() {
    ["wt-command-palette", "wt-shortcuts-overlay"].forEach(function (id) {
      var el = document.getElementById(id);
      if (el && !el.hasAttribute("hidden")) {
        el.setAttribute("hidden", "");
        el.setAttribute("aria-hidden", "true");
      }
    });
  }

  function openFor(taskId) {
    var p = panel();
    if (!p || !taskId) return;
    closeOthers();
    p.removeAttribute("hidden");
    p.setAttribute("aria-hidden", "false");
    var b = body();
    if (b) b.innerHTML = '<p class="muted" style="padding:1rem;">Loading…</p>';
    // htmx loads + processes the fragment (its "Open full page" link is hx-boosted).
    if (window.htmx) {
      window.htmx.ajax("GET", "/tasks/" + taskId + "/panel", {
        target: "#wt-task-panel-body",
        swap: "innerHTML",
      });
    }
  }

  function close() {
    var p = panel();
    if (!p) return;
    p.setAttribute("hidden", "");
    p.setAttribute("aria-hidden", "true");
  }

  function setDock(dock) {
    var p = panel();
    if (!p || DOCKS.indexOf(dock) === -1) return;
    DOCKS.forEach(function (d) { p.classList.remove("dock-" + d); });
    p.classList.add("dock-" + dock);
    persistDock(dock);
  }

  function persistDock(dock) {
    if (!window.fetchWithCsrf) return;
    var bodyData = "dock=" + encodeURIComponent(dock);
    window.fetchWithCsrf("/settings/panel-dock/save", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: bodyData,
    }).catch(function () { /* dock still applied client-side; persistence is best-effort */ });
  }

  function onClick(e) {
    // Dock / close controls (inside the panel).
    var dockBtn = e.target.closest("[data-dock]");
    if (dockBtn) {
      e.preventDefault();
      setDock(dockBtn.getAttribute("data-dock"));
      return;
    }
    if (e.target.closest("[data-task-panel-close]")) {
      e.preventDefault();
      close();
      return;
    }
    // Open trigger (a task card/row link anywhere in #content).
    var opener = e.target.closest("[data-task-panel]");
    if (opener) {
      e.preventDefault();
      openFor(opener.getAttribute("data-task-panel"));
    }
  }

  function onKeydown(e) {
    if (e.key === "Escape" && isOpen()) {
      e.preventDefault();
      close();
    }
  }

  function init() {
    // Delegated on document so it survives htmx #content swaps.
    document.addEventListener("click", onClick);
    document.addEventListener("keydown", onKeydown);
    // Expose for cross-modal mutual exclusion (palette/overlay call this on open).
    window.wtTaskPanelClose = close;
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
