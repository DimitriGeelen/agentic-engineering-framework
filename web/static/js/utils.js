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
