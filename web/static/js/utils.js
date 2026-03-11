/* ── Shared Utilities ─────────────────────────────────── */

function _getCsrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.getAttribute('content') : '';
}

function isQuestion(text) {
    if (/\?\s*$/.test(text)) return true;
    return /^(who|what|why|when|where|how|is|are|can|does|do|should|will|would|could|explain|describe|tell me|list)\b/i.test(text.trim());
}

function pathToLink(path) {
    if (!path) return '';
    if (path.indexOf('.tasks/') === 0 && path.indexOf('/T-') !== -1) { var m = path.match(/\/T-(\d+)/); return m ? '/tasks/T-' + m[1] : ''; }
    if (path.indexOf('.fabric/components/') === 0) return '/fabric/component/' + path.split('/').pop().replace('.yaml', '');
    if (path.indexOf('.context/episodic/') === 0 && path.endsWith('.yaml')) return '/tasks/' + path.split('/').pop().replace('.yaml', '');
    if (path === '.context/project/learnings.yaml') return '/learnings';
    if (path === '.context/project/patterns.yaml') return '/patterns';
    if (path === '.context/project/decisions.yaml') return '/decisions';
    if (path.endsWith('.md') && path.charAt(0) !== '.') return '/project/' + path.replace('.md', '').replace(/\//g, '--');
    return '';
}

function escHtml(s) {
    var d = document.createElement('div');
    d.appendChild(document.createTextNode(s));
    return d.innerHTML;
}

/* ── Fetch Error Handling (T-420) ─────────────────────── */

/**
 * Log and return a consistent error message for failed fetch calls.
 * @param {string} action  What was attempted (e.g., "save answer")
 * @returns {string} User-facing error message
 */
function handleFetchError(action) {
    var msg = 'Could not ' + action + '. Check connection and retry.';
    console.warn('[fetch]', msg);
    return msg;
}

/* ── Thinking Timer (T-426) ───────────────────────────── */

/**
 * Create a thinking timer that shows elapsed seconds in a status element.
 * Shared between chat and Q&A streaming.
 *
 * @param {HTMLElement} statusEl  Element to show thinking status
 * @returns {Object} {onModel, onThinking, onThinkingDone}
 */
function createThinkingTracker(statusEl) {
    var start = 0;
    return {
        onModel: function(data) {
            if (data.thinking) {
                start = Date.now();
                statusEl.innerHTML = '<span aria-busy="true">Thinking...</span>';
            }
        },
        onThinking: function() {
            var elapsed = ((Date.now() - start) / 1000).toFixed(0);
            statusEl.innerHTML = '<span aria-busy="true">Thinking... (' + elapsed + 's)</span>';
        },
        onThinkingDone: function() {
            statusEl.innerHTML = '<span aria-busy="true">Writing answer...</span>';
        }
    };
}

/* ── SSE Stream Fetcher (T-418) ──────────────────────── */

/**
 * Fetch an SSE endpoint and dispatch parsed events.
 *
 * @param {string} url       Endpoint URL
 * @param {Object} body      JSON body to POST
 * @param {Function} onEvent Called with parsed {type, ...} for each SSE event
 * @param {Function} onError Called with error message string on stream/fetch error
 * @returns {AbortController} Call .abort() to cancel the stream
 */
function streamSSE(url, body, onEvent, onError) {
    var abortCtrl = new AbortController();

    fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': _getCsrfToken() },
        body: JSON.stringify(body),
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
                try { onEvent(JSON.parse(match[1])); } catch(e) {}
            });
        }

        function read() {
            reader.read().then(function(result) {
                if (result.done) { processBuffer(); return; }
                buffer += decoder.decode(result.value, { stream: true });
                processBuffer();
                read();
            }).catch(function(err) {
                if (err.name !== 'AbortError' && onError) {
                    onError('Stream interrupted');
                }
            });
        }
        read();
    }).catch(function(err) {
        if (err.name !== 'AbortError' && onError) {
            onError('Cannot connect to LLM. Is the provider running?');
        }
    });

    return abortCtrl;
}
