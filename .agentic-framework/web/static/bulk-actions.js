// Bulk multi-select + floating action bar — arc-007 S4e / S6c (T-2018).
//
// Ticking a task checkbox (any element carrying data-bulk-select="T-XXX") on /tasks
// adds it to a selection set and reveals a floating action bar (#wt-bulk-bar) with a
// horizon quick-set (Now/Next/Later) and Clear. Applying a horizon fans out one
// CSRF-protected POST per selected id to the EXISTING /api/task/<id>/horizon endpoint
// (no bulk server route), aggregates success/failure, reports via showToast, then
// refreshes #content so the board reflects the change.
//
// Like the panel / palette / overlay, the bar lives in base.html OUTSIDE #content, so
// this single delegated listener set survives every htmx #content swap with no
// re-binding. Selection resets on a #content swap (view/filter change) so the count can
// never refer to off-screen tasks.
(function () {
  "use strict";

  var selected = new Set();

  function bar() { return document.getElementById("wt-bulk-bar"); }

  function refreshBar() {
    var b = bar();
    if (!b) return;
    var n = selected.size;
    var c = document.getElementById("wt-bulk-count");
    if (c) c.textContent = n + " selected";
    if (n > 0) { b.removeAttribute("hidden"); b.setAttribute("aria-hidden", "false"); }
    else { b.setAttribute("hidden", ""); b.setAttribute("aria-hidden", "true"); }
  }

  function clearAll() {
    selected.clear();
    document.querySelectorAll("[data-bulk-select]").forEach(function (cb) {
      cb.checked = false;
    });
    refreshBar();
  }

  function onChange(e) {
    var cb = e.target.closest("[data-bulk-select]");
    if (!cb) return;
    var id = cb.getAttribute("data-bulk-select");
    if (!id) return;
    if (cb.checked) selected.add(id); else selected.delete(id);
    refreshBar();
  }

  function applyHorizon(horizon) {
    var ids = Array.from(selected);
    if (!ids.length || !window.fetchWithCsrf) return;
    var ok = 0, fail = 0, done = 0;
    ids.forEach(function (id) {
      window.fetchWithCsrf("/api/task/" + id + "/horizon", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: "horizon=" + encodeURIComponent(horizon),
      })
        .then(function (r) { if (r.ok) ok++; else fail++; })
        .catch(function () { fail++; })
        .finally(function () {
          done++;
          if (done === ids.length) finishApply(horizon, ok, fail);
        });
    });
  }

  function finishApply(horizon, ok, fail) {
    var msg = "Set horizon=" + horizon + " on " + ok + " task" + (ok === 1 ? "" : "s");
    if (fail) msg += " (" + fail + " failed)";
    if (window.showToast) window.showToast(msg, fail ? "error" : "info");
    clearAll();
    // Refresh the board so the new horizons render; the shell (bar + toast) survives
    // the #content swap.
    if (window.htmx) {
      window.htmx.ajax("GET", window.location.pathname + window.location.search, {
        target: "#content",
        swap: "innerHTML",
      });
    }
  }

  function onClick(e) {
    var hb = e.target.closest("[data-bulk-horizon]");
    if (hb) {
      e.preventDefault();
      applyHorizon(hb.getAttribute("data-bulk-horizon"));
      return;
    }
    if (e.target.closest("[data-bulk-clear]")) {
      e.preventDefault();
      clearAll();
    }
  }

  function onAfterSwap(e) {
    // A #content swap replaces the cards/rows — reset selection so the count can't
    // point at tasks no longer on screen. (Panel loads target #wt-task-panel-body,
    // not #content, so they don't trip this.)
    var tgt = e && e.detail && e.detail.target;
    if (tgt && tgt.id === "content" && selected.size) clearAll();
  }

  function init() {
    document.addEventListener("change", onChange);
    document.addEventListener("click", onClick);
    document.body.addEventListener("htmx:afterSwap", onAfterSwap);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
