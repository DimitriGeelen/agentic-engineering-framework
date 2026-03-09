/* ── Search Q&A ───────────────────────────────────────── */

var _askAbort = null;
var _lastQuestion = '';
var _lastAnswer = '';
var _lastSources = [];
var _lastModel = '';
var _conversationHistory = [];

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
function askQuestion(query) {
    var card = document.getElementById('ask-answer-card');
    var textDiv = document.getElementById('ask-text');
    var statusDiv = document.getElementById('ask-status');
    var modelDiv = document.getElementById('ask-model');
    var sourcesEl = document.getElementById('ask-sources');
    var sourceList = document.getElementById('ask-source-list');
    var sourceCount = document.getElementById('ask-source-count');
    var errorDiv = document.getElementById('ask-error');

    /* Archive previous turn */
    if (_lastQuestion && _lastAnswer) {
        _addTurnToThread(_lastQuestion, renderAnswer(_lastAnswer));
    }

    /* Show card */
    card.style.display = 'block';
    textDiv.innerHTML = '';
    statusDiv.style.display = 'block';
    statusDiv.innerHTML = '<span aria-busy="true">Retrieving context &amp; generating answer...</span>';
    modelDiv.textContent = '';
    sourcesEl.style.display = 'none';
    sourceList.innerHTML = '';
    errorDiv.style.display = 'none';
    document.getElementById('ask-actions-row').style.display = 'none';
    document.getElementById('followup-row').style.display = 'none';
    _lastSources = [];

    if (_askAbort) { _askAbort.abort(); _askAbort = null; }

    var abortCtrl = new AbortController();
    _askAbort = abortCtrl;

    var fullText = '';
    var gotFirstToken = false;
    var isThinking = false;
    var thinkingStart = 0;

    fetch('/search/ask', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': _getCsrfToken() },
        body: JSON.stringify({ query: query, history: _conversationHistory }),
        signal: abortCtrl.signal
    }).then(function(response) {
        if (!response.ok) throw new Error('Server error: ' + response.status);
        var reader = response.body.getReader();
        var decoder = new TextDecoder();
        var buffer = '';

        function processBuffer() {
            var parts = buffer.split('\n\n');
            buffer = parts.pop();
            parts.forEach(function(part) {
                var match = part.match(/^data:\s*(.+)$/m);
                if (!match) return;
                try { handleEvent(JSON.parse(match[1])); } catch(e) {}
            });
        }

        function handleEvent(data) {
            if (data.type === 'model') {
                _lastModel = data.model;
                var label = data.model;
                if (data.provider && data.provider !== 'ollama') label = data.provider + '/' + data.model;
                if (data.thinking) label += ' (thinking)';
                modelDiv.textContent = label;
                if (data.thinking) { isThinking = true; thinkingStart = Date.now(); statusDiv.innerHTML = '<span aria-busy="true">Thinking...</span>'; }
            }
            else if (data.type === 'thinking') {
                var elapsed = ((Date.now() - thinkingStart) / 1000).toFixed(0);
                statusDiv.innerHTML = '<span aria-busy="true">Thinking... (' + elapsed + 's)</span>';
            }
            else if (data.type === 'thinking_done') { isThinking = false; statusDiv.style.display = 'none'; }
            else if (data.type === 'token') {
                if (!gotFirstToken) { gotFirstToken = true; statusDiv.style.display = 'none'; }
                fullText += data.content;
                renderAnswerDebounced(fullText, textDiv);
            }
            else if (data.type === 'sources') {
                var sources = data.sources || [];
                _lastSources = sources;
                sourceCount.textContent = sources.length;
                sourceList.innerHTML = '';
                sources.forEach(function(src) {
                    var link = pathToLink(src.path);
                    var el = document.createElement('div');
                    el.style.cssText = 'padding: 0.4rem 0; border-bottom: 1px solid var(--pico-muted-border-color);';
                    el.innerHTML = '<strong>[' + src.num + ']</strong> ' +
                        (link ? '<a href="' + link + '" hx-target="#content" hx-swap="innerHTML" hx-push-url="true">' : '') +
                        escHtml(src.title) + (link ? '</a>' : '') +
                        ' <small style="color:var(--pico-muted-color)">(' + escHtml(src.category) + ')</small>' +
                        '<br><code style="font-size:0.75rem">' + escHtml(src.path) + '</code>';
                    sourceList.appendChild(el);
                });
                sourcesEl.style.display = 'block';
                sourcesEl.setAttribute('open', '');
                if (typeof htmx !== 'undefined') htmx.process(sourceList);
            }
            else if (data.type === 'done') {
                _askAbort = null;
                if (_renderTimer) clearTimeout(_renderTimer);
                textDiv.innerHTML = renderAnswer(fullText);
                addCopyButtons(textDiv);
                _lastAnswer = fullText;
                _lastQuestion = query;
                _conversationHistory.push({role: 'user', content: query});
                _conversationHistory.push({role: 'assistant', content: fullText});
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
                /* Show follow-up input */
                document.getElementById('followup-row').style.display = 'block';
                document.getElementById('followup-input').focus();
            }
            else if (data.type === 'error') {
                _askAbort = null;
                errorDiv.textContent = data.message;
                errorDiv.style.display = 'block';
                statusDiv.style.display = 'none';
            }
        }

        function read() {
            reader.read().then(function(result) {
                if (result.done) { processBuffer(); return; }
                buffer += decoder.decode(result.value, { stream: true });
                processBuffer();
                read();
            }).catch(function(err) {
                if (err.name !== 'AbortError') {
                    errorDiv.textContent = 'Stream interrupted';
                    errorDiv.style.display = 'block';
                    statusDiv.style.display = 'none';
                }
            });
        }
        read();
    }).catch(function(err) {
        if (err.name === 'AbortError') return;
        errorDiv.textContent = 'Cannot connect to LLM. Is the provider running?';
        errorDiv.style.display = 'block';
        statusDiv.style.display = 'none';
    });
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
    _conversationHistory = [];
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
    _lastQuestion = '';
    _lastAnswer = '';
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
    var turns = _conversationHistory.length / 2;
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
        body: JSON.stringify({ question: _lastQuestion, answer: _lastAnswer, sources: _lastSources })
    }).then(function(r) { return r.json(); }).then(function(data) {
        if (data.saved) { btn.textContent = 'Saved'; status.textContent = data.path; status.style.color = 'var(--pico-ins-color)'; }
        else { btn.disabled = false; btn.textContent = 'Save'; status.textContent = data.error || 'Failed'; status.style.color = '#c62828'; }
    }).catch(function() { btn.disabled = false; btn.textContent = 'Save'; status.textContent = 'Network error'; status.style.color = '#c62828'; });
}

function sendFeedback(rating) {
    var upBtn = document.getElementById('fb-up');
    var downBtn = document.getElementById('fb-down');
    var fbStatus = document.getElementById('fb-status');
    upBtn.disabled = true; downBtn.disabled = true;
    fetch('/search/feedback', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': _getCsrfToken() },
        body: JSON.stringify({ query: _lastQuestion, answer_preview: _lastAnswer.substring(0, 500), model: _lastModel, rating: rating })
    }).then(function(r) { return r.json(); }).then(function(data) {
        if (data.saved) {
            fbStatus.textContent = rating === 1 ? 'Thanks!' : 'Noted!';
            if (rating === 1) { upBtn.style.opacity = '1'; downBtn.style.opacity = '0.3'; }
            else { downBtn.style.opacity = '1'; upBtn.style.opacity = '0.3'; }
        } else { fbStatus.textContent = data.error || 'Failed'; upBtn.disabled = false; downBtn.disabled = false; }
    }).catch(function() { fbStatus.textContent = 'Error'; upBtn.disabled = false; downBtn.disabled = false; });
}

/* ── Category Filtering ────────────────────────────────── */
function filterCategory(btn, category) {
    document.querySelectorAll('#category-pills button').forEach(function(b) { b.classList.remove('pill-active'); });
    btn.classList.add('pill-active');
    document.querySelectorAll('.search-result').forEach(function(el) {
        el.style.display = (!category || el.dataset.category === category) ? '' : 'none';
    });
}
