/* ── Markdown Rendering ────────────────────────────────── */

var _renderTimer = null;
var _markedReady = false;

(function initMarked() {
    if (typeof marked === 'undefined') return;
    marked.setOptions({
        highlight: function(code, lang) {
            if (lang && typeof hljs !== 'undefined' && hljs.getLanguage(lang)) return hljs.highlight(code, { language: lang }).value;
            return typeof hljs !== 'undefined' ? hljs.highlightAuto(code).value : code;
        },
        breaks: true, gfm: true
    });
    _markedReady = true;
})();

function renderAnswer(text) {
    if (!_markedReady) return '<p>' + escHtml(text) + '</p>';
    var raw = marked.parse(text);
    var html = typeof DOMPurify !== 'undefined' ? DOMPurify.sanitize(raw) : raw;
    return html.replace(/\[(\d+)\]/g, '<sup class="citation">[$1]</sup>');
}

function renderAnswerDebounced(text, target) {
    if (_renderTimer) clearTimeout(_renderTimer);
    _renderTimer = setTimeout(function() { target.innerHTML = renderAnswer(text); addCopyButtons(target); }, 100);
}

function addCopyButtons(container) {
    container.querySelectorAll('pre code').forEach(function(block) {
        if (block.parentNode.querySelector('.copy-btn')) return;
        var btn = document.createElement('button');
        btn.className = 'copy-btn'; btn.textContent = 'Copy';
        btn.onclick = function() { navigator.clipboard.writeText(block.textContent).then(function() { btn.textContent = 'Copied!'; setTimeout(function() { btn.textContent = 'Copy'; }, 1500); }); };
        block.parentNode.style.position = 'relative';
        block.parentNode.appendChild(btn);
    });
}
