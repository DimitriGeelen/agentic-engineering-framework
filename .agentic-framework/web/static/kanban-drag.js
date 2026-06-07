// Drag-to-reorder kanban (cross-column status change) — arc-007 S4d (T-2019).
//
// Dragging a kanban card (article.kanban-card, draggable, data-task-id="T-XXX") onto a
// DIFFERENT .kanban-column[data-status] POSTs that column's status to the EXISTING
// /api/task/<id>/status endpoint (no new server route — it runs `fw task update --status`,
// inheriting every gate: T-1068 horizon invariant, enum validation, R-033). On success a
// toast confirms and #content refreshes; on a rejected move the server's error text is
// surfaced via showToast — no silent failure. A drop on the card's own column is a no-op.
//
// Native HTML5 drag-and-drop, zero library. Like the panel / bulk bar / palette, these are
// document-delegated listeners attached once in base.html (OUTSIDE #content), so they
// survive every htmx #content swap with no re-binding.
//
// Keyboard-accessible fallback: the per-card inline status <select> changes a card's column
// via the same endpoint — the documented equivalent of cross-column drag (HTML5 DnD is not
// keyboard operable). Within-column reorder is intentionally out of scope (see T-2019).
(function () {
  "use strict";

  var draggingId = null;     // data-task-id of the card being dragged
  var originStatus = null;   // data-status of the column it started in
  var dropCol = null;        // the .kanban-column currently highlighted as a drop target

  function clearDropTarget() {
    if (dropCol) { dropCol.classList.remove("kanban-drop-target"); dropCol = null; }
  }

  function onDragStart(e) {
    var card = e.target.closest("article.kanban-card");
    if (!card || !card.getAttribute("data-task-id")) return;
    draggingId = card.getAttribute("data-task-id");
    var col = card.closest(".kanban-column");
    originStatus = col ? col.getAttribute("data-status") : null;
    card.classList.add("kanban-dragging");
    // Some browsers require data to be set for a drag to be valid.
    if (e.dataTransfer) {
      e.dataTransfer.effectAllowed = "move";
      try { e.dataTransfer.setData("text/plain", draggingId); } catch (_) { /* ignore */ }
    }
  }

  function onDragOver(e) {
    if (!draggingId) return;
    var col = e.target.closest(".kanban-column");
    if (!col) return;
    e.preventDefault(); // allow drop
    if (e.dataTransfer) e.dataTransfer.dropEffect = "move";
    if (col !== dropCol) {
      clearDropTarget();
      dropCol = col;
      col.classList.add("kanban-drop-target");
    }
  }

  function onDrop(e) {
    if (!draggingId) return;
    var col = e.target.closest(".kanban-column");
    if (!col) { return; }
    e.preventDefault();
    var target = col.getAttribute("data-status");
    var id = draggingId;
    var same = target === originStatus;
    clearDropTarget();
    if (same || !target || !window.fetchWithCsrf) return; // same-column drop = no-op
    moveCard(id, target);
  }

  function onDragEnd() {
    var c = document.querySelector("article.kanban-card.kanban-dragging");
    if (c) c.classList.remove("kanban-dragging");
    clearDropTarget();
    draggingId = null;
    originStatus = null;
  }

  function moveCard(id, status) {
    window.fetchWithCsrf("/api/task/" + id + "/status", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: "status=" + encodeURIComponent(status),
    })
      .then(function (r) {
        if (r.ok) {
          if (window.showToast) window.showToast("Moved " + id + " to " + status, "info");
          refreshBoard();
        } else {
          // Surface the server's reason (governance reject, invalid enum, etc.) — no silent failure.
          return r.text().then(function (t) {
            if (window.showToast) window.showToast(stripTags(t) || ("Could not move " + id), "error");
          });
        }
      })
      .catch(function () {
        if (window.showToast) window.showToast("Could not move " + id, "error");
      });
  }

  function stripTags(s) {
    return (s || "").replace(/<[^>]*>/g, "").trim();
  }

  function refreshBoard() {
    if (window.htmx) {
      window.htmx.ajax("GET", window.location.pathname + window.location.search, {
        target: "#content",
        swap: "innerHTML",
      });
    }
  }

  function init() {
    document.addEventListener("dragstart", onDragStart);
    document.addEventListener("dragover", onDragOver);
    document.addEventListener("drop", onDrop);
    document.addEventListener("dragend", onDragEnd);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
