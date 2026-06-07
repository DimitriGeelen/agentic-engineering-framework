/* ⌘K Command Palette — T-2012, arc-007 S6a.
 *
 * The keystone of the redesigned nav: the icon-rail layout (S2d) defers every
 * non-pinned destination to ⌘K. This palette does two things from one input:
 *   1. JUMP   — client-side fuzzy match over the nav whitelist (#wt-nav-items,
 *               = web.shared.NAV_ITEMS resolved to URLs), keyboard-driven.
 *   2. SEARCH — a fall-through row routing to the existing discovery.search
 *               backend (/search?q=). No second search implementation.
 *
 * Lives in the shell (base.html), so its document-level listener attaches once
 * and survives every htmx #content swap — no re-binding, no leaked handlers.
 */
(function () {
  "use strict";

  var MAX_JUMP = 8; // cap jump results so the list stays scannable

  var modal, input, results, destinations;
  var selected = 0;
  var rows = []; // current rendered rows: [{url, kind, label}]

  function load() {
    modal = document.getElementById("wt-command-palette");
    input = document.getElementById("wt-palette-input");
    results = document.getElementById("wt-palette-results");
    if (!modal || !input || !results) return false;
    var tag = document.getElementById("wt-nav-items");
    try {
      destinations = JSON.parse((tag && tag.textContent) || "[]");
    } catch (e) {
      destinations = [];
    }
    return true;
  }

  function isOpen() {
    return modal && !modal.hasAttribute("hidden");
  }

  function open() {
    if (!modal) return;
    // mutual exclusion (S6b overlay + S4a task panel) — one shell modal at a time
    var ov = document.getElementById("wt-shortcuts-overlay");
    if (ov && !ov.hasAttribute("hidden")) {
      ov.setAttribute("hidden", "");
      ov.setAttribute("aria-hidden", "true");
    }
    if (window.wtTaskPanelClose) window.wtTaskPanelClose();
    modal.removeAttribute("hidden");
    modal.setAttribute("aria-hidden", "false");
    input.value = "";
    render("");
    // focus after the element is shown so the caret lands in the input
    window.requestAnimationFrame(function () {
      input.focus();
    });
  }

  function close() {
    if (!modal) return;
    modal.setAttribute("hidden", "");
    modal.setAttribute("aria-hidden", "true");
  }

  /* Subsequence fuzzy score: -1 if `needle` is not a subsequence of `hay`,
   * else a score rewarding contiguous runs, prefix matches and exact substrings. */
  function fuzzyScore(needle, hay) {
    needle = needle.toLowerCase();
    hay = hay.toLowerCase();
    if (!needle) return 0;
    var hi = 0, score = 0, streak = 0, lastIdx = -1;
    for (var i = 0; i < needle.length; i++) {
      var idx = hay.indexOf(needle[i], hi);
      if (idx === -1) return -1;
      if (idx === lastIdx + 1) { streak++; score += 5 + streak; } else { streak = 0; score += 1; }
      if (idx === 0) score += 5;
      lastIdx = idx;
      hi = idx + 1;
    }
    score -= hay.length * 0.05;            // mild preference for shorter labels
    if (hay.indexOf(needle) !== -1) score += 10; // exact substring bonus
    return score;
  }

  function matches(query) {
    if (!query) {
      return destinations.slice(0, MAX_JUMP); // empty query: show top of the list
    }
    var scored = [];
    for (var i = 0; i < destinations.length; i++) {
      var s = fuzzyScore(query, destinations[i].label);
      if (s >= 0) scored.push({ d: destinations[i], s: s });
    }
    scored.sort(function (a, b) { return b.s - a.s; });
    return scored.slice(0, MAX_JUMP).map(function (x) { return x.d; });
  }

  function render(query) {
    rows = [];
    results.innerHTML = "";
    var hits = matches(query);
    hits.forEach(function (d) {
      rows.push({ url: d.url, kind: "jump", label: d.label, group: d.group });
    });
    if (query) {
      // search fall-through — always offered as the last row when there's a query
      rows.push({
        url: "/search?q=" + encodeURIComponent(query),
        kind: "search",
        label: "Search “" + query + "” in all content",
        group: "Search",
      });
    }
    if (rows.length === 0) {
      var empty = document.createElement("li");
      empty.className = "wt-palette-empty";
      empty.textContent = "No matches";
      results.appendChild(empty);
      selected = -1;
      return;
    }
    rows.forEach(function (r, i) {
      var li = document.createElement("li");
      li.setAttribute("role", "option");
      li.dataset.url = r.url;
      li.dataset.kind = r.kind;
      if (r.kind === "search") li.className = "wt-palette-search";
      var label = document.createElement("span");
      label.className = "wt-palette-label";
      label.textContent = r.label;
      li.appendChild(label);
      if (r.group) {
        var grp = document.createElement("span");
        grp.className = "wt-palette-group";
        grp.textContent = r.group;
        li.appendChild(grp);
      }
      li.addEventListener("click", function () { activate(i); });
      results.appendChild(li);
    });
    selected = 0;
    highlight();
  }

  function highlight() {
    var items = results.querySelectorAll("li[role='option']");
    items.forEach(function (li, i) {
      if (i === selected) {
        li.setAttribute("aria-selected", "true");
        li.scrollIntoView({ block: "nearest" });
      } else {
        li.removeAttribute("aria-selected");
      }
    });
  }

  function move(delta) {
    if (rows.length === 0) return;
    selected = (selected + delta + rows.length) % rows.length;
    highlight();
  }

  function navigate(url, kind) {
    close();
    // jump → SPA swap via htmx (matches the nav links); fall back to a full load.
    if (kind === "jump" && window.htmx) {
      window.htmx.ajax("GET", url, { target: "#content", swap: "innerHTML" });
      try { window.history.pushState({}, "", url); } catch (e) { /* ignore */ }
    } else {
      window.location.assign(url);
    }
  }

  function activate(i) {
    if (i == null) i = selected;
    if (i < 0 || i >= rows.length) return;
    navigate(rows[i].url, rows[i].kind);
  }

  function onKeydown(e) {
    // ⌘K / Ctrl-K toggles open from anywhere
    if ((e.metaKey || e.ctrlKey) && (e.key === "k" || e.key === "K")) {
      e.preventDefault();
      isOpen() ? close() : open();
      return;
    }
    if (!isOpen()) return;
    if (e.key === "Escape") { e.preventDefault(); close(); }
    else if (e.key === "ArrowDown") { e.preventDefault(); move(1); }
    else if (e.key === "ArrowUp") { e.preventDefault(); move(-1); }
    else if (e.key === "Enter") { e.preventDefault(); activate(); }
  }

  function init() {
    if (!load()) return;
    document.addEventListener("keydown", onKeydown);
    input.addEventListener("input", function () { render(input.value.trim()); });
    // the nav-search affordance opens the palette instead of navigating to /search
    document.addEventListener("click", function (e) {
      var opener = e.target.closest("[data-palette-open]");
      if (opener) { e.preventDefault(); open(); return; }
      var closer = e.target.closest("[data-palette-close]");
      if (closer && isOpen()) { e.preventDefault(); close(); }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
