/* ── Ask AI Chat (T-409) ──────────────────────────────── */

var _chatHistory = [];
var _chatAbort = null;
var _chatScope = 'all';
var _chatLoadedConvId = null;  /* ID of loaded saved conversation */

/* ── Providers & Models ──────────────────────────────── */

function chatLoadProviders() {
    fetch('/api/v1/health')
        .then(function(r) { return r.json(); })
        .then(function(data) {
            var sel = document.getElementById('chat-provider');
            if (!sel) return;
            sel.innerHTML = '';
            (data.providers || []).forEach(function(p) {
                var opt = document.createElement('option');
                opt.value = p.name;
                opt.textContent = p.name.charAt(0).toUpperCase() + p.name.slice(1);
                if (!p.available) { opt.disabled = true; opt.textContent += ' (offline)'; }
                if (p.active) opt.selected = true;
                sel.appendChild(opt);
            });
            chatLoadModels();
        })
        .catch(function() {});
}

function chatLoadModels() {
    fetch('/settings/models?format=options')
        .then(function(r) { return r.text(); })
        .then(function(html) {
            var sel = document.getElementById('chat-model');
            if (sel) sel.innerHTML = html;
        })
        .catch(function() {});
}

function chatSwitchProvider(name) {
    fetch('/settings/save', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'X-CSRF-Token': _getCsrfToken() },
        body: 'provider=' + encodeURIComponent(name)
    }).then(function() { chatLoadModels(); })
      .catch(function() {});
}

/* ── Scope ───────────────────────────────────────────── */

function chatSetScope(scope) {
    _chatScope = scope;
    var label = document.getElementById('chat-scope-label');
    var labels = { all: 'All', tasks: 'Tasks', docs: 'Docs', episodic: 'Episodic' };
    if (label) label.textContent = labels[scope] || 'All';
    /* Close the details dropdown */
    var det = document.getElementById('chat-scope-details');
    if (det) det.removeAttribute('open');
}

/* ── Message Rendering ───────────────────────────────── */

function _chatAddMessage(role, content, isStreaming) {
    var thread = document.getElementById('chat-thread');
    var welcome = document.getElementById('chat-welcome');
    if (welcome) welcome.style.display = 'none';

    var msg = document.createElement('div');
    msg.className = 'chat-msg chat-msg-' + role;
    msg.style.cssText = 'margin-bottom: 0.75rem; padding: 0.6rem 0.8rem; border-radius: 0.5rem; line-height: 1.6; overflow-wrap: break-word;';

    if (role === 'user') {
        msg.style.background = 'var(--pico-primary-focus)';
        msg.style.marginLeft = '2rem';
        msg.innerHTML = '<div style="font-size:0.75rem;color:var(--pico-muted-color);margin-bottom:0.2rem;">You</div>' +
            '<div>' + escHtml(content) + '</div>';
    } else {
        msg.style.background = 'var(--pico-card-background-color)';
        msg.style.border = '1px solid var(--pico-muted-border-color)';
        msg.style.marginRight = '2rem';
        var modelSel = document.getElementById('chat-model');
        var modelName = modelSel ? modelSel.value : '';
        msg.innerHTML = '<div style="font-size:0.75rem;color:var(--pico-muted-color);margin-bottom:0.2rem;">AI' +
            (modelName ? ' <small>(' + escHtml(modelName) + ')</small>' : '') + '</div>' +
            '<div class="chat-ai-content">' + (isStreaming ? '' : renderAnswer(content)) + '</div>';
        if (!isStreaming) addCopyButtons(msg);
    }

    thread.appendChild(msg);
    thread.scrollTop = thread.scrollHeight;
    return msg;
}

/* ── Streaming ───────────────────────────────────────── */

function chatAsk(query) {
    var input = document.getElementById('chat-input');
    if (input) input.value = '';

    /* Show user message */
    _chatAddMessage('user', query);

    /* Show status */
    var status = document.getElementById('chat-status');
    var error = document.getElementById('chat-error');
    status.style.display = 'block';
    status.innerHTML = '<span aria-busy="true">Retrieving context &amp; generating answer...</span>';
    error.style.display = 'none';

    /* Disable input during generation */
    var sendBtn = document.getElementById('chat-send-btn');
    if (sendBtn) { sendBtn.disabled = true; sendBtn.setAttribute('aria-busy', 'true'); }

    if (_chatAbort) { _chatAbort.abort(); _chatAbort = null; }
    var abortCtrl = new AbortController();
    _chatAbort = abortCtrl;

    var fullText = '';
    var aiMsg = null;
    var gotFirstToken = false;
    var thinkingStart = 0;

    /* Get selected model */
    var modelSel = document.getElementById('chat-model');
    var selectedModel = modelSel ? modelSel.value : '';

    fetch('/search/ask', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': _getCsrfToken() },
        body: JSON.stringify({
            query: query,
            history: _chatHistory,
            scope: _chatScope,
            model: selectedModel
        }),
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
            if (data.type === 'status') {
                /* T-409: Progress events during RAG retrieval phases */
                status.style.display = 'block';
                status.innerHTML = '<span aria-busy="true">' + escHtml(data.message) + '</span>';
            }
            else if (data.type === 'model') {
                if (data.thinking) {
                    thinkingStart = Date.now();
                    status.innerHTML = '<span aria-busy="true">Thinking...</span>';
                }
            }
            else if (data.type === 'thinking') {
                var elapsed = ((Date.now() - thinkingStart) / 1000).toFixed(0);
                status.innerHTML = '<span aria-busy="true">Thinking... (' + elapsed + 's)</span>';
            }
            else if (data.type === 'thinking_done') {
                status.innerHTML = '<span aria-busy="true">Writing answer...</span>';
            }
            else if (data.type === 'token') {
                if (!gotFirstToken) {
                    gotFirstToken = true;
                    status.style.display = 'none';
                    aiMsg = _chatAddMessage('assistant', '', true);
                }
                fullText += data.content;
                /* Debounced render */
                if (aiMsg) {
                    var contentDiv = aiMsg.querySelector('.chat-ai-content');
                    if (contentDiv) {
                        contentDiv.innerHTML = renderAnswer(fullText);
                        var thread = document.getElementById('chat-thread');
                        thread.scrollTop = thread.scrollHeight;
                    }
                }
            }
            else if (data.type === 'sources') {
                /* Add sources as collapsible under the AI message */
                if (aiMsg && data.sources && data.sources.length > 0) {
                    var sourcesHtml = '<details style="margin-top:0.5rem;font-size:0.82rem;"><summary style="cursor:pointer;color:var(--pico-muted-color);">Sources (' + data.sources.length + ')</summary><div style="margin-top:0.25rem;">';
                    data.sources.forEach(function(src) {
                        var link = pathToLink(src.path);
                        sourcesHtml += '<div style="padding:0.2rem 0;border-bottom:1px solid var(--pico-muted-border-color);">';
                        sourcesHtml += '<strong>[' + src.num + ']</strong> ';
                        if (link) sourcesHtml += '<a href="' + link + '">';
                        sourcesHtml += escHtml(src.title || src.path);
                        if (link) sourcesHtml += '</a>';
                        sourcesHtml += ' <small style="color:var(--pico-muted-color)">(' + escHtml(src.category) + ')</small></div>';
                    });
                    sourcesHtml += '</div></details>';
                    aiMsg.insertAdjacentHTML('beforeend', sourcesHtml);
                }
            }
            else if (data.type === 'done') {
                _chatAbort = null;
                /* Strip inferred title comment */
                var extracted = _extractInferredTitle(fullText);
                var displayText = extracted.clean;

                /* Final render */
                if (aiMsg) {
                    var contentDiv = aiMsg.querySelector('.chat-ai-content');
                    if (contentDiv) {
                        contentDiv.innerHTML = renderAnswer(displayText);
                        addCopyButtons(aiMsg);
                    }
                }

                /* Update history */
                _chatHistory.push({ role: 'user', content: query });
                _chatHistory.push({ role: 'assistant', content: displayText });

                /* Show actions */
                _chatUpdateActions();

                /* Re-enable input */
                if (sendBtn) { sendBtn.disabled = false; sendBtn.removeAttribute('aria-busy'); }
                var chatInput = document.getElementById('chat-input');
                if (chatInput) chatInput.focus();
            }
            else if (data.type === 'error') {
                _chatAbort = null;
                error.textContent = data.message;
                error.style.display = 'block';
                status.style.display = 'none';
                if (sendBtn) { sendBtn.disabled = false; sendBtn.removeAttribute('aria-busy'); }
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
                    error.textContent = 'Stream interrupted';
                    error.style.display = 'block';
                    status.style.display = 'none';
                    if (sendBtn) { sendBtn.disabled = false; sendBtn.removeAttribute('aria-busy'); }
                }
            });
        }
        read();
    }).catch(function(err) {
        if (err.name === 'AbortError') return;
        error.textContent = 'Cannot connect to LLM. Is the provider running?';
        error.style.display = 'block';
        status.style.display = 'none';
        if (sendBtn) { sendBtn.disabled = false; sendBtn.removeAttribute('aria-busy'); }
    });
}

/* ── Submit ──────────────────────────────────────────── */

function chatSubmit() {
    var input = document.getElementById('chat-input');
    var q = input.value.trim();
    if (q.length < 2) return;
    chatAsk(q);
}

/* ── New Conversation ────────────────────────────────── */

function chatNew() {
    _chatHistory = [];
    _chatLoadedConvId = null;
    var thread = document.getElementById('chat-thread');
    thread.innerHTML = '';
    var welcome = document.getElementById('chat-welcome');
    if (welcome) welcome.style.display = 'block';
    document.getElementById('chat-error').style.display = 'none';
    document.getElementById('chat-status').style.display = 'none';
    document.getElementById('chat-actions').style.display = 'none';
    document.getElementById('chat-input').focus();
}

/* ── Actions ─────────────────────────────────────────── */

function _chatUpdateActions() {
    var turns = _chatHistory.length / 2;
    var actions = document.getElementById('chat-actions');
    var turnCount = document.getElementById('chat-turn-count');
    var newBtn = document.getElementById('chat-new-btn');
    if (turns > 0) {
        actions.style.display = 'flex';
        turnCount.textContent = turns + ' turn' + (turns !== 1 ? 's' : '');
        newBtn.style.display = 'inline-block';
        document.getElementById('chat-save-btn').disabled = false;
        document.getElementById('chat-save-btn').textContent = 'Save Conversation';
        document.getElementById('chat-save-status').textContent = '';
    }
}

/* ── Save Conversation ───────────────────────────────── */

function chatSave() {
    var btn = document.getElementById('chat-save-btn');
    var status = document.getElementById('chat-save-status');
    btn.disabled = true;
    btn.textContent = 'Saving...';
    status.textContent = '';

    /* Get the last AI response as the "final artifact" */
    var lastAnswer = '';
    var lastQuestion = '';
    for (var i = _chatHistory.length - 1; i >= 0; i--) {
        if (_chatHistory[i].role === 'assistant' && !lastAnswer) {
            lastAnswer = _chatHistory[i].content;
        }
        if (_chatHistory[i].role === 'user' && !lastQuestion) {
            lastQuestion = _chatHistory[i].content;
        }
        if (lastAnswer && lastQuestion) break;
    }

    fetch('/search/save-conversation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': _getCsrfToken() },
        body: JSON.stringify({
            history: _chatHistory,
            final_answer: lastAnswer,
            final_question: lastQuestion,
            loaded_from: _chatLoadedConvId
        })
    }).then(function(r) { return r.json(); })
      .then(function(data) {
          if (data.saved) {
              btn.textContent = 'Saved';
              status.textContent = data.path;
              status.style.color = 'var(--pico-ins-color)';
              _chatLoadedConvId = data.id;
              chatLoadSaved();  /* Refresh sidebar */
          } else {
              btn.disabled = false;
              btn.textContent = 'Save Conversation';
              status.textContent = data.error || 'Failed';
              status.style.color = '#c62828';
          }
      })
      .catch(function() {
          btn.disabled = false;
          btn.textContent = 'Save Conversation';
          status.textContent = 'Network error';
          status.style.color = '#c62828';
      });
}

/* ── Load Saved Conversations ────────────────────────── */

function chatLoadSaved() {
    fetch('/search/conversations')
        .then(function(r) { return r.json(); })
        .then(function(data) {
            var list = document.getElementById('chat-saved-list');
            var count = document.getElementById('chat-saved-count');
            if (!list) return;
            var items = data.conversations || [];
            count.textContent = items.length ? '(' + items.length + ')' : '';
            if (items.length === 0) {
                list.innerHTML = '<small style="color:var(--pico-muted-color);">No saved conversations yet. Start chatting and save the outcome.</small>';
                return;
            }
            list.innerHTML = '';
            items.forEach(function(item) {
                var el = document.createElement('div');
                el.style.cssText = 'display:flex;align-items:center;gap:0.5rem;padding:0.35rem 0;border-bottom:1px solid var(--pico-muted-border-color);cursor:pointer;';
                el.innerHTML = '<div style="flex:1;min-width:0;">' +
                    '<div style="font-size:0.82rem;font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">' + escHtml(item.title) + '</div>' +
                    '<small style="color:var(--pico-muted-color);">' + escHtml(item.date) + ' &middot; ' + item.turns + ' turns</small>' +
                    '</div>' +
                    '<button class="outline secondary" style="font-size:0.7rem;padding:0.15rem 0.4rem;margin:0;white-space:nowrap;" onclick="event.stopPropagation(); chatLoadConversation(\'' + escHtml(item.id) + '\')">Continue</button>';
                el.addEventListener('click', function() { chatLoadConversation(item.id); });
                list.appendChild(el);
            });
        })
        .catch(function() {
            var list = document.getElementById('chat-saved-list');
            if (list) list.innerHTML = '<small style="color:var(--pico-muted-color);">Could not load conversations.</small>';
        });
}

function chatLoadConversation(convId) {
    fetch('/search/load-conversation?id=' + encodeURIComponent(convId))
        .then(function(r) { return r.json(); })
        .then(function(data) {
            if (data.error) return;

            /* Reset */
            chatNew();
            _chatLoadedConvId = convId;

            /* Inject the saved artifact as context */
            var thread = document.getElementById('chat-thread');
            var welcome = document.getElementById('chat-welcome');
            if (welcome) welcome.style.display = 'none';

            /* Show the saved artifact as a "loaded context" banner */
            var banner = document.createElement('div');
            banner.style.cssText = 'padding:0.5rem 0.75rem;background:var(--pico-primary-focus);border-radius:0.5rem;margin-bottom:0.75rem;font-size:0.85rem;';
            banner.innerHTML = '<strong>Loaded:</strong> ' + escHtml(data.title) +
                ' <small style="color:var(--pico-muted-color);">(' + data.date + ')</small>';
            thread.appendChild(banner);

            /* Show the final answer from the saved conversation */
            if (data.final_answer) {
                _chatAddMessage('assistant', data.final_answer);
            }

            /* Set history so LLM has context for continuation */
            _chatHistory = data.history || [];
            if (_chatHistory.length === 0 && data.final_answer) {
                /* Reconstruct minimal history */
                _chatHistory = [
                    { role: 'user', content: data.final_question || data.title },
                    { role: 'assistant', content: data.final_answer }
                ];
            }

            _chatUpdateActions();
            document.getElementById('chat-input').focus();
        })
        .catch(function() {});
}

/* ── Tab Switching ───────────────────────────────────── */

function chatActivate() {
    document.getElementById('chat-container').style.display = 'block';
    chatLoadProviders();
    chatLoadSaved();
}

function chatDeactivate() {
    document.getElementById('chat-container').style.display = 'none';
    /* Don't clear state — user can switch back */
}

/* ── Init ────────────────────────────────────────────── */

function chatInit() {
    /* Hook into mode pill system */
    var askPill = document.querySelector('[data-mode="ask"]');
    if (askPill) {
        askPill.addEventListener('click', function() {
            chatActivate();
        });
    }
}
