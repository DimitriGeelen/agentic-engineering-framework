/* ── Search Q&A ───────────────────────────────────────── */

var qaState = {
    abort: null,
    lastQuestion: '',
    lastAnswer: '',
    lastInferredTitle: '',
    lastSources: [],
    lastModel: '',
    history: []
};

/* Extract <!-- Q: ... --> inferred title from LLM response (T-389) */
function _extractInferredTitle(text) {
    var match = text.match(/<!--\s*Q:\s*(.+?)\s*-->/);
    if (match) return { title: match[1].trim(), clean: text.replace(match[0], '').trimEnd() };
    return { title: '', clean: text };
}

/* ── Recent Searches (localStorage) ────────────────────── */
var _RECENT_KEY = 'wt-recent-searches';
var _MAX_RECENT = 8;

function _getRecentSearches() {
    try { return JSON.parse(localStorage.getItem(_RECENT_KEY)) || []; }
    catch(e) { return []; }
}

function _addRecentSearch(query) {
    if (!query || query.length < 2) return;
    var recent = _getRecentSearches().filter(function(q) { return q !== query; });
    recent.unshift(query);
    if (recent.length > _MAX_RECENT) recent = recent.slice(0, _MAX_RECENT);
    try { localStorage.setItem(_RECENT_KEY, JSON.stringify(recent)); } catch(e) {}
}

function _renderRecentSearches() {
    var container = document.getElementById('recent-searches');
    var list = document.getElementById('recent-searches-list');
    if (!container || !list) return;
    var recent = _getRecentSearches();
    if (recent.length === 0) { container.style.display = 'none'; return; }
    list.innerHTML = '';
    recent.forEach(function(q) {
        var chip = document.createElement('a');
        chip.className = 'recent-chip';
        chip.textContent = q.length > 40 ? q.substring(0, 37) + '...' : q;
        chip.title = q;
        chip.href = '?q=' + encodeURIComponent(q) + '&mode=hybrid';
        chip.setAttribute('hx-get', '/search?q=' + encodeURIComponent(q) + '&mode=hybrid');
        chip.setAttribute('hx-target', '#content');
        chip.setAttribute('hx-swap', 'innerHTML');
        chip.setAttribute('hx-push-url', 'true');
        list.appendChild(chip);
    });
    container.style.display = 'block';
    if (typeof htmx !== 'undefined') htmx.process(list);
}

function clearRecentSearches() {
    try { localStorage.removeItem(_RECENT_KEY); } catch(e) {}
    var container = document.getElementById('recent-searches');
    if (container) container.style.display = 'none';
}

/* ── Unified Submit ────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', function() {
    var form = document.getElementById('search-form');
    var input = document.getElementById('search-input');

    if (form) {
        form.addEventListener('submit', function(e) {
            var q = input.value.trim();
            if (q.length >= 2) _addRecentSearch(q);
            if (q.length >= 2 && isQuestion(q)) {
                e.preventDefault();
                if (window.htmx) htmx.trigger(form, 'htmx:abort');
                askQuestion(q);
            }
            /* else: normal form submission for search */
        });
    }

    /* Render recent searches */
    _renderRecentSearches();

    /* Auto-trigger Q&A if query in URL looks like a question */
    var urlQuery = document.getElementById('search-input').value.trim();
    if (urlQuery && isQuestion(urlQuery)) {
        askQuestion(urlQuery);
    }
});

/* ── Ask Q&A ───────────────────────────────────────────── */

function _qaPrepareAsk(query) {
    /* Archive previous turn */
    if (qaState.lastQuestion && qaState.lastAnswer) {
        _addTurnToThread(qaState.lastQuestion, renderAnswer(qaState.lastAnswer));
    }

    var refs = {
        card: document.getElementById('ask-answer-card'),
        textDiv: document.getElementById('ask-text'),
        statusDiv: document.getElementById('ask-status'),
        modelDiv: document.getElementById('ask-model'),
        sourcesEl: document.getElementById('ask-sources'),
        sourceList: document.getElementById('ask-source-list'),
        sourceCount: document.getElementById('ask-source-count'),
        errorDiv: document.getElementById('ask-error')
    };

    refs.card.style.display = 'block';
    refs.textDiv.innerHTML = '';
    refs.statusDiv.style.display = 'block';
    refs.statusDiv.innerHTML = '<span aria-busy="true">Retrieving context &amp; generating answer...</span>';
    refs.modelDiv.textContent = '';
    refs.sourcesEl.style.display = 'none';
    refs.sourceList.innerHTML = '';
    refs.errorDiv.style.display = 'none';
    document.getElementById('ask-actions-row').style.display = 'none';
    document.getElementById('followup-row').style.display = 'none';
    qaState.lastSources = [];

    if (qaState.abort) { qaState.abort.abort(); qaState.abort = null; }
    return refs;
}

function _qaHandleModel(data, refs) {
    qaState.lastModel = data.model;
    var label = data.model;
    if (data.provider && data.provider !== 'ollama') label = data.provider + '/' + data.model;
    if (data.thinking) label += ' (thinking)';
    refs.modelDiv.textContent = label;
}

function _qaRenderSources(data, refs) {
    var sources = data.sources || [];
    qaState.lastSources = sources;
    refs.sourceCount.textContent = sources.length;
    refs.sourceList.innerHTML = '';
    sources.forEach(function(src) {
        var link = pathToLink(src.path);
        var el = document.createElement('div');
        el.style.cssText = 'padding: 0.4rem 0; border-bottom: 1px solid var(--pico-muted-border-color);';
        el.innerHTML = '<strong>[' + src.num + ']</strong> ' +
            (link ? '<a href="' + link + '" hx-target="#content" hx-swap="innerHTML" hx-push-url="true">' : '') +
            escHtml(src.title) + (link ? '</a>' : '') +
            ' <small style="color:var(--pico-muted-color)">(' + escHtml(src.category) + ')</small>' +
            '<br><code style="font-size:0.75rem">' + escHtml(src.path) + '</code>';
        refs.sourceList.appendChild(el);
    });
    refs.sourcesEl.style.display = 'block';
    refs.sourcesEl.setAttribute('open', '');
    if (typeof htmx !== 'undefined') htmx.process(refs.sourceList);
}

function _qaFinishAsk(query, ctx) {
    qaState.abort = null;
    if (_renderTimer) clearTimeout(_renderTimer);
    var extracted = _extractInferredTitle(ctx.fullText);
    qaState.lastInferredTitle = extracted.title;
    var displayText = extracted.clean;
    ctx.refs.textDiv.innerHTML = renderAnswer(displayText);
    addCopyButtons(ctx.refs.textDiv);
    qaState.lastAnswer = displayText;
    qaState.lastQuestion = query;
    qaState.history.push({ role: 'user', content: query });
    qaState.history.push({ role: 'assistant', content: ctx.fullText });
    _updateConvHeader();
    document.getElementById('ask-actions-row').style.display = 'flex';
    document.getElementById('ask-save-btn').disabled = false;
    document.getElementById('ask-save-btn').textContent = 'Save';
    document.getElementById('ask-save-status').textContent = '';
    document.getElementById('fb-up').disabled = false;
    document.getElementById('fb-down').disabled = false;
    document.getElementById('fb-up').style.opacity = '1';
    document.getElementById('fb-down').style.opacity = '1';
    document.getElementById('fb-status').textContent = '';
    document.getElementById('followup-row').style.display = 'block';
    document.getElementById('followup-input').focus();
}

function _qaShowError(msg, refs) {
    qaState.abort = null;
    refs.errorDiv.textContent = msg;
    refs.errorDiv.style.display = 'block';
    refs.statusDiv.style.display = 'none';
}

function askQuestion(query) {
    var refs = _qaPrepareAsk(query);
    var thinking = createThinkingTracker(refs.statusDiv);
    var ctx = { fullText: '', gotFirstToken: false, refs: refs };

    qaState.abort = streamSSE('/search/ask',
        { query: query, history: qaState.history },
        function(data) {
            if (data.type === 'model') { _qaHandleModel(data, refs); thinking.onModel(data); }
            else if (data.type === 'thinking') { thinking.onThinking(); }
            else if (data.type === 'thinking_done') { refs.statusDiv.style.display = 'none'; }
            else if (data.type === 'token') {
                if (!ctx.gotFirstToken) { ctx.gotFirstToken = true; refs.statusDiv.style.display = 'none'; }
                ctx.fullText += data.content;
                renderAnswerDebounced(ctx.fullText, refs.textDiv);
            }
            else if (data.type === 'sources') { _qaRenderSources(data, refs); }
            else if (data.type === 'done') { _qaFinishAsk(query, ctx); }
            else if (data.type === 'error') { _qaShowError(data.message, refs); }
        },
        function(msg) { _qaShowError(msg, refs); }
    );
}

/* ── Follow-up ─────────────────────────────────────────── */
function askFollowup() {
    var input = document.getElementById('followup-input');
    var q = input.value.trim();
    if (q.length < 2) return;
    input.value = '';
    askQuestion(q);
}

document.addEventListener('DOMContentLoaded', function() {
    var el = document.getElementById('followup-input');
    if (el) el.addEventListener('keydown', function(e) { if (e.key === 'Enter') { e.preventDefault(); askFollowup(); } });
});

/* ── Conversation Thread ───────────────────────────────── */
function newConversation() {
    qaState.history = [];
    document.getElementById('conv-thread').innerHTML = '';
    document.getElementById('conv-thread').style.display = 'none';
    document.getElementById('conv-turn-count').style.display = 'none';
    document.getElementById('conv-new-btn').style.display = 'none';
    document.getElementById('ask-answer-card').style.display = 'none';
    document.getElementById('ask-sources').style.display = 'none';
    document.getElementById('ask-actions-row').style.display = 'none';
    document.getElementById('followup-row').style.display = 'none';
    document.getElementById('ask-error').style.display = 'none';
    document.getElementById('search-input').focus();
    qaState.lastQuestion = '';
    qaState.lastAnswer = '';
}

function _addTurnToThread(question, answerHtml) {
    var thread = document.getElementById('conv-thread');
    var turn = document.createElement('div');
    turn.style.cssText = 'margin-bottom: 0.75rem; padding-bottom: 0.75rem; border-bottom: 1px solid var(--pico-muted-border-color);';
    turn.innerHTML = '<div style="font-weight:600;font-size:0.85rem;color:var(--pico-primary);margin-bottom:0.25rem;">' + escHtml(question) + '</div>' +
        '<div style="font-size:0.85rem;line-height:1.5;max-height:150px;overflow-y:auto;">' + answerHtml + '</div>';
    thread.appendChild(turn);
    thread.style.display = 'block';
    thread.scrollTop = thread.scrollHeight;
}

function _updateConvHeader() {
    var turns = qaState.history.length / 2;
    if (turns > 0) {
        document.getElementById('conv-turn-count').textContent = turns + ' turn' + (turns !== 1 ? 's' : '');
        document.getElementById('conv-turn-count').style.display = 'inline';
        document.getElementById('conv-new-btn').style.display = 'inline-block';
    }
}

/* ── Save / Feedback ───────────────────────────────────── */
function saveAnswer() {
    var btn = document.getElementById('ask-save-btn');
    var status = document.getElementById('ask-save-status');
    btn.disabled = true; btn.textContent = 'Saving...'; status.textContent = '';
    fetch('/search/save', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': _getCsrfToken() },
        body: JSON.stringify({ question: qaState.lastQuestion, answer: qaState.lastAnswer, sources: qaState.lastSources, inferred_title: qaState.lastInferredTitle })
    }).then(function(r) { return r.json(); }).then(function(data) {
        if (data.saved) { btn.textContent = 'Saved'; status.textContent = data.path; status.style.color = 'var(--pico-ins-color)'; }
        else { btn.disabled = false; btn.textContent = 'Save'; status.textContent = data.error || 'Failed'; status.classList.add('text-danger'); }
    }).catch(function() { btn.disabled = false; btn.textContent = 'Save'; status.textContent = handleFetchError('save answer'); status.classList.add('text-danger'); });
}

function sendFeedback(rating) {
    var upBtn = document.getElementById('fb-up');
    var downBtn = document.getElementById('fb-down');
    var fbStatus = document.getElementById('fb-status');
    upBtn.disabled = true; downBtn.disabled = true;
    fetch('/search/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': _getCsrfToken() },
        body: JSON.stringify({ query: qaState.lastQuestion, answer_preview: qaState.lastAnswer.substring(0, 500), model: qaState.lastModel, rating: rating })
    }).then(function(r) { return r.json(); }).then(function(data) {
        if (data.saved) {
            fbStatus.textContent = rating === 1 ? 'Thanks!' : 'Noted!';
            if (rating === 1) { upBtn.style.opacity = '1'; downBtn.style.opacity = '0.3'; }
            else { downBtn.style.opacity = '1'; upBtn.style.opacity = '0.3'; }
        } else { fbStatus.textContent = data.error || 'Failed'; upBtn.disabled = false; downBtn.disabled = false; }
    }).catch(function() { fbStatus.textContent = handleFetchError('send feedback'); upBtn.disabled = false; downBtn.disabled = false; });
}

/* ── Category Filtering ────────────────────────────────── */
function filterCategory(btn, category) {
    document.querySelectorAll('#category-pills button').forEach(function(b) { b.classList.remove('pill-active'); });
    btn.classList.add('pill-active');
    document.querySelectorAll('.search-result').forEach(function(el) {
        el.style.display = (!category || el.dataset.category === category) ? '' : 'none';
    });
}
