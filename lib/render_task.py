#!/usr/bin/env python3
"""The one task-file writer (T-5221, slice 2 of inception T-5212).

Before this module, agents/task-create/create-task.sh rendered task files with three inline
writers (two python3 -c programs and a heredoc). A batch path beside them would have been a
second writer of task files: the same class of problem as two id allocators (1409, T-5212).
So every new task file is rendered and written here, by `fw task create` (one entry) and by
`fw task create-batch` (many entries), and the two produce the same bytes for the same entry.

The rendering is create-task's code lifted verbatim (T-2778 indent_block, T-4863 set_key,
T-4787 json-quoted name). Its output is pinned against files the pre-T-5221 create-task wrote:
tests/fixtures/t5221/golden/, checked by tests/unit/t5221_create_batch.bats.

Writing: every file is rendered to a temp file under <tasks>/.writing/ and then hard-linked
to its final name. link(2) fails when the name exists (an exclusive open) and is atomic, so a
process killed mid-batch leaves only complete task files; the temp file it leaves behind is
not named T-*.md and is swept by the next write. Where the filesystem has no hard links
(EPERM/ENOTSUP/EXDEV/EMLINK/ENOSYS) the file is opened O_CREAT|O_EXCL on its final name
instead: still never overwrites, and a write error removes it, but a kill mid-write can
leave a partial file there (review finding 1). .writing/ is never removed (finding 3) and
holds its own `*` .gitignore (finding 7). Every rendered file's frontmatter is parsed
before anything is written; one that does not parse is refused (finding 2).

CLI (ids are allocated by the caller through lib/idalloc.sh, never here):
  render_task.py write-one --tasks-dir D --framework-root R --id T-N --name N
        --description D --type T --owner O --horizon H --status S [--tags a,b]
        [--related T-1,T-2] [--arc-id A] [--timestamp TS]
      writes one file, prints its path.
  render_task.py write-batch --tasks-dir D --framework-root R --spec F.jsonl --ids T-A,T-B,..
        [--timestamp TS]
      writes the spec's entries (status captured) under the reserved ids, in order, one path
      per line as each file lands. The caller has validated the spec (create-batch.sh).
  render_task.py slug NAME
      prints the filename slug create-task has always used.
  render_task.py parse-spec F.jsonl
      reads a create-batch spec, prints entries as NUL-separated fields for the shell
      validator: name, description, type, owner, horizon, tags, related, arc_id; refuses
      unknown keys and the keys a batch may not carry (start, origin, recommendation...).

Exit: 0 written, 1 a write failed (files before it stay complete), 2 usage / bad spec.
"""
from __future__ import annotations

import argparse
import datetime
import errno
import json
import os
import re
import sys
import time

# ── rendering (create-task.sh, pre-T-5221, verbatim apart from being functions) ──────────


def indent_block(s):
    # T-2778: 'description: >' is a folded scalar, so EVERY line of the value must be
    # indented, not just the first. Indenting only the first line ends the scalar at the
    # first newline; YAML then reads the next paragraph as frontmatter. Blank lines are
    # emitted bare: whitespace-only lines inside a block scalar are separators.
    return '\n'.join(('  ' + ln) if ln.strip() else '' for ln in s.split('\n'))


def set_key(fm, key, value):
    # T-4863: replace the key's own line, anchored at line start, once. A key the template
    # lacks is left alone.
    return re.sub('^' + re.escape(key) + ':.*$', lambda m: key + ': ' + value, fm, count=1, flags=re.M)


def _yaml():
    try:
        import yaml  # noqa: PLC0415 — optional: the writer must still run without PyYAML
        return yaml
    except ImportError:
        return None


_PLAIN_SAFE = re.compile(r'^[A-Za-z0-9_][A-Za-z0-9_./+=:-]*$')
_item_cache = {}


def yaml_flow_item(item):
    """One item of a YAML flow sequence. Emitted bare when YAML reads it back as that one
    scalar (every ordinary tag, so create-task's bytes do not move); otherwise double-quoted
    (json escaping is valid YAML), so ']' '#' ',' ': ' quotes and the like cannot break the
    frontmatter, turn a tag into a mapping or split it in two (T-5221 review finding 2).
    A bare scalar that YAML types as a number or boolean (`2026`, `yes`) stays bare, as it
    always was."""
    if item in _item_cache:
        return _item_cache[item]
    yaml = _yaml()
    if yaml is not None:
        try:
            got = yaml.safe_load('[' + item + ']')
            bare = (isinstance(got, list) and len(got) == 1 and got[0] is not None
                    and not isinstance(got[0], (list, dict))
                    and (not isinstance(got[0], str) or got[0] == item))
        except yaml.YAMLError:
            bare = False
    else:
        bare = bool(_PLAIN_SAFE.match(item))
    out = item if bare else json.dumps(item, ensure_ascii=False)
    _item_cache[item] = out
    return out


def format_yaml_array(raw):
    """create-task's format_yaml_array: comma list -> "[a, b]". Items are trimmed and inner
    whitespace collapsed (what `xargs` did to each item); empty items are dropped. A list
    keeps its items whole: a comma inside a list item does not split it. Items that are not
    plain YAML are quoted (yaml_flow_item)."""
    if raw is None:
        return '[]'
    if isinstance(raw, (list, tuple)):
        items = [str(x) for x in raw]
    else:
        items = str(raw).split(',')
    items = [' '.join(i.split()) for i in items]
    items = [yaml_flow_item(i) for i in items if i]
    return '[' + ', '.join(items) + ']'


def slug(name):
    """create-task's generate_slug: ASCII-lowercase, space -> '-', keep [a-z0-9-], 40 bytes."""
    out = bytearray()
    for b in name.encode('utf-8', 'surrogateescape'):
        if 65 <= b <= 90:
            b += 32
        elif b == 32:
            b = 45
        if (97 <= b <= 122) or (48 <= b <= 57) or b == 45:
            out.append(b)
    return out[:40].decode('ascii')


def template_path(tasks_dir, framework_root, name):
    # T-4597: a project without .tasks/templates/ uses the framework's own copy.
    for cand in (os.path.join(tasks_dir, 'templates', name),
                 os.path.join(framework_root, '.tasks', 'templates', name)):
        if os.path.isfile(cand):
            return cand
    return None


def _split(t):
    m = re.match(r'(---\n)(.*?\n)(---\n.*)', t, re.S)
    return m.groups() if m else ('', '', t)


def render_inception(t, e):
    pre, fm, body = _split(t)
    fm = set_key(fm, 'id', e['id'])
    fm = set_key(fm, 'status', e['status'])
    fm = set_key(fm, 'horizon', e['horizon'])
    fm = set_key(fm, 'owner', e['owner'])
    fm = set_key(fm, 'tags', e['tags_yaml'])
    fm = set_key(fm, 'related_tasks', e['related_yaml'])
    fm = set_key(fm, 'created', e['timestamp'])
    fm = set_key(fm, 'last_update', e['timestamp'])
    fm = set_key(fm, 'name', json.dumps(e['name'], ensure_ascii=False))
    fm = set_key(fm, 'description', '>\n' + indent_block(e['description']))
    body = body.replace('# T-XXX: [Inception Name]', '# ' + e['id'] + ': ' + e['name'])
    body = body.replace('[Chronological log', '### ' + e['timestamp'] + ' — task-created [task-create-agent]\n- **Action:** Created inception task\n- **Output:** ' + e['filepath'] + '\n- **Context:** Initial task creation\n\n[Chronological log')
    return pre + fm + body


def render_default(t, e):
    pre, fm, body = _split(t)
    fm = set_key(fm, 'id', e['id'])
    fm = set_key(fm, 'status', e['status'])
    fm = set_key(fm, 'workflow_type', e['type'])
    fm = set_key(fm, 'owner', e['owner'])
    fm = set_key(fm, 'horizon', e['horizon'])
    fm = set_key(fm, 'tags', e['tags_yaml'])
    fm = set_key(fm, 'related_tasks', e['related_yaml'])
    fm = set_key(fm, 'created', e['timestamp'])
    fm = set_key(fm, 'last_update', e['timestamp'])
    fm = set_key(fm, 'name', json.dumps(e['name'], ensure_ascii=False))
    fm = set_key(fm, 'description', '>\n' + indent_block(e['description']))
    body = body.replace('# T-XXX: [Task Name]', '# ' + e['id'] + ': ' + e['name'])
    body = body.replace('<!-- Auto-populated by git mining at task completion.\n     Manual entries optional during execution. -->', '### ' + e['timestamp'] + ' — task-created [task-create-agent]\n- **Action:** Created task via task-create agent\n- **Output:** ' + e['filepath'] + '\n- **Context:** Initial task creation')
    return pre + fm + body


def render_fallback(e):
    # Minimal inline template, only when no default.md exists anywhere (the old heredoc).
    # awk '{ if (length($0)) print "  " $0; else print "" }' inside $(...), which drops
    # trailing newlines.
    desc = '\n'.join(('  ' + ln) if ln else '' for ln in e['description'].split('\n')).rstrip('\n')
    ts, tid = e['timestamp'], e['id']
    return (
        '---\n'
        f"id: {tid}\n"
        f"name: {json.dumps(e['name'], ensure_ascii=False)}\n"
        'description: >\n'
        f"{desc}\n"
        f"status: {e['status']}\n"
        f"workflow_type: {e['type']}\n"
        f"horizon: {e['horizon']}\n"
        f"owner: {e['owner']}\n"
        f"tags: {e['tags_yaml']}\n"
        f"related_tasks: {e['related_yaml']}\n"
        f"created: {ts}\n"
        f"last_update: {ts}\n"
        'date_finished: null\n'
        '---\n'
        '\n'
        f"# {tid}: {e['name']}\n"
        '\n'
        '## Context\n'
        '\n'
        '**Background / trigger:** <what happened, who reported it, evidence>\n'
        '\n'
        '**Problem / hypothesis:** <what we think is wrong and why>\n'
        '\n'
        '**Goal:** <what we are trying to achieve>\n'
        '\n'
        '**Expected outcome:** <what will be different when this is done>\n'
        '\n'
        '## Acceptance Criteria\n'
        '\n'
        '- [ ] [Criterion]\n'
        '\n'
        '## Verification\n'
        '\n'
        '## Updates\n'
        '\n'
        f"### {ts} — task-created [task-create-agent]\n"
        '- **Action:** Created task via task-create agent\n'
        f"- **Output:** {e['filepath']}\n"
        '- **Context:** Initial task creation\n'
    )


def set_arc_id(text, arc_id):
    """Record arc membership (T-1849 arc_id:) after related_tasks:, or before the frontmatter
    close when the template has no related_tasks: line. Used by create-batch entries that
    name an arc (fw arc instantiate); create-task never sets it, so its bytes are unchanged."""
    line = 'arc_id: ' + arc_id
    text, n = re.subn(r'(?m)^(related_tasks:.*)$', lambda m: m.group(1) + '\n' + line, text, count=1)
    if not n:
        text, n = re.subn(r'\A(---\n.*?\n)(---\n)', lambda m: m.group(1) + line + '\n' + m.group(2),
                          text, count=1, flags=re.S)
    return text


class Templates:
    """Template text read once per process (a batch reads each template once)."""

    def __init__(self, tasks_dir, framework_root):
        self.tasks_dir, self.framework_root, self._cache = tasks_dir, framework_root, {}

    def get(self, name):
        if name not in self._cache:
            p = template_path(self.tasks_dir, self.framework_root, name)
            if p is None:
                self._cache[name] = None
            else:
                with open(p) as fh:
                    self._cache[name] = fh.read()
        return self._cache[name]


def render(entry, templates, tasks_dir, timestamp):
    """Return (filepath, text) for one entry. entry: id, name, description, type, owner,
    horizon, status, tags, related, arc_id (optional)."""
    e = dict(entry)
    e['timestamp'] = timestamp
    e['tags_yaml'] = format_yaml_array(e.get('tags'))
    e['related_yaml'] = format_yaml_array(e.get('related'))
    e['filepath'] = os.path.join(tasks_dir, 'active', e['id'] + '-' + slug(e['name']) + '.md')
    inception = templates.get('inception.md') if e['type'] == 'inception' else None
    if inception is not None:
        text = render_inception(inception, e)
    else:
        default = templates.get('default.md')
        text = render_default(default, e) if default is not None else render_fallback(e)
    if e.get('arc_id'):
        text = set_arc_id(text, e['arc_id'])
    if e['type'] == 'inception':
        text = set_inception_wait(text, e.get('waiting_on'), e.get('revisit_at'), timestamp)
    return e['filepath'], text


def set_inception_wait(text, waiting_on, revisit_at, timestamp):
    """T-5227: an inception names who holds its next step (waiting_on, default agent) and
    when it comes back (revisit_at, default filing date + 7). Written after related_tasks:,
    or before the frontmatter close when the template has none. Values are validated by the
    caller (create-task.sh, lib/inception_lifecycle.py validate_fields)."""
    if not revisit_at:
        try:
            filed = datetime.datetime.strptime((timestamp or '')[:10], '%Y-%m-%d').date()
        except ValueError:
            filed = datetime.datetime.now(datetime.timezone.utc).date()
        revisit_at = (filed + datetime.timedelta(days=7)).isoformat()
    lines = 'waiting_on: ' + (waiting_on or 'agent') + '\nrevisit_at: ' + revisit_at
    text, n = re.subn(r'(?m)^(related_tasks:.*)$', lambda m: m.group(1) + '\n' + lines, text, count=1)
    if not n:
        text = re.sub(r'\A(---\n.*?\n)(---\n)', lambda m: m.group(1) + lines + '\n' + m.group(2),
                      text, count=1, flags=re.S)
    return text


class FrontmatterError(Exception):
    pass


def check_frontmatter(path, text):
    """Refuse a rendered file whose frontmatter does not read back as a mapping holding this
    task's id (T-5221 review finding 2): the writer never reports success for a task file
    the framework cannot parse. Skipped only when PyYAML is not installed."""
    yaml = _yaml()
    if yaml is None:
        return
    m = re.match(r'---\n(.*?\n)---\n', text, re.S)
    if not m:
        raise FrontmatterError(f'{path}: no frontmatter block')
    try:
        fm = yaml.safe_load(m.group(1))
    except yaml.YAMLError as exc:
        raise FrontmatterError(f'{path}: frontmatter does not parse: {exc}') from None
    want = re.match(r'(T-\d+)', os.path.basename(path))
    if not isinstance(fm, dict) or (want and fm.get('id') != want.group(1)):
        got = fm.get('id') if isinstance(fm, dict) else fm
        raise FrontmatterError(f'{path}: frontmatter does not read back as this task (id {got!r})')


# ── writing ─────────────────────────────────────────────────────────────────────────────


def _sweep(tmpdir):
    """Remove temp files whose writer is gone (a killed batch)."""
    try:
        names = os.listdir(tmpdir)
    except OSError:
        return
    for n in names:
        m = re.match(r'^(\d+)-', n)
        if not m:
            continue
        pid = int(m.group(1))
        try:
            os.kill(pid, 0)
            continue
        except ProcessLookupError:
            pass
        except PermissionError:
            continue
        try:
            os.unlink(os.path.join(tmpdir, n))
        except OSError:
            pass


# link(2) errors that mean "no hard link here" (vboxsf, FAT/exFAT, some CIFS/FUSE mounts,
# or the active directory on another filesystem than .writing/). T-5221 review finding 1.
_NO_LINK = {errno.EPERM, errno.EOPNOTSUPP, errno.ENOTSUP, errno.EXDEV, errno.EMLINK, errno.ENOSYS}


def _ensure_tmpdir(tmpdir):
    """The temp directory stays once made: removing it would race a concurrent writer's
    makedirs+open (review finding 3). It ignores itself in git, so a killed writer's
    leftover is never committed, in consumer projects too (review finding 7)."""
    os.makedirs(tmpdir, exist_ok=True)
    gi = os.path.join(tmpdir, '.gitignore')
    if not os.path.exists(gi):
        try:
            with open(gi, 'x') as fh:
                fh.write('*\n')
        except FileExistsError:
            pass


def _write_excl_direct(path, text):
    """Fallback without link(2): O_CREAT|O_EXCL on the final name (still never overwrites),
    write, fsync; a write error removes the file. Loses only atomicity against a kill."""
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o666)
    try:
        with os.fdopen(fd, 'w') as fh:
            fh.write(text)
            fh.flush()
            os.fsync(fh.fileno())
    except BaseException:
        try:
            os.unlink(path)
        except OSError:
            pass
        raise


def write_exclusive(path, text, tmpdir):
    """Write text to path atomically, refusing when path exists."""
    _ensure_tmpdir(tmpdir)
    # Leading pid lets _sweep find a dead writer's leftovers; the random part keeps the name
    # unique when pids are reused (T-5067).
    tmp = os.path.join(tmpdir, f'{os.getpid()}-{os.urandom(4).hex()}.{os.path.basename(path)}')
    with open(tmp, 'x') as fh:
        fh.write(text)
    try:
        os.link(tmp, path)  # exclusive + atomic: EEXIST when the name is taken
    except OSError as exc:
        if exc.errno not in _NO_LINK:
            raise
        os.unlink(tmp)
        tmp = None
        _write_excl_direct(path, text)
    finally:
        if tmp is not None:
            os.unlink(tmp)


def write_entries(entries, tasks_dir, framework_root, timestamp=None):
    timestamp = timestamp or time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    templates = Templates(tasks_dir, framework_root)
    tmpdir = os.path.join(tasks_dir, '.writing')
    _sweep(tmpdir)
    os.makedirs(os.path.join(tasks_dir, 'active'), exist_ok=True)
    rendered = [render(e, templates, tasks_dir, timestamp) for e in entries]
    # Every file's frontmatter is parsed before the first is written. These are the exact
    # bytes that land, so a file that would not parse is never written nor reported.
    for path, text in rendered:
        check_frontmatter(path, text)
    written = []
    delay = float(os.environ.get('FW_RENDER_TEST_DELAY', '0') or 0)  # test hook: kill mid-batch
    for path, text in rendered:
        write_exclusive(path, text, tmpdir)
        written.append(path)
        print(path, flush=True)
        if delay:
            time.sleep(delay)
    return written


# ── create-batch spec parsing ───────────────────────────────────────────────────────────

SPEC_KEYS = {'name', 'description', 'type', 'owner', 'horizon', 'tags', 'related', 'arc_id'}
# Keys a batch refuses outright (T-5212: no inceptions, no --start/focus, no --origin).
REFUSED_KEYS = {'start', 'status', 'focus', 'origin', 'recommendation', 'rationale', 'i_am_human', 'id'}


def _as_list_text(v, key, n):
    if v is None:
        return ''
    if isinstance(v, str):
        return v
    if isinstance(v, list) and all(isinstance(x, str) for x in v):
        return list(v)  # kept a list: a comma inside an item must not split it (review 2)
    raise ValueError(f'entry {n}: "{key}" must be a string or a list of strings')


def parse_spec(path):
    """Return a list of normalised entries; raise ValueError naming every bad entry."""
    entries, errors = [], []
    with open(path, encoding='utf-8') as fh:
        lines = fh.read().split('\n')
    n = 0
    for lineno, line in enumerate(lines, 1):
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        n += 1
        try:
            obj = json.loads(line)
        except ValueError as exc:
            errors.append(f'entry {n} (line {lineno}): not JSON ({exc})')
            continue
        if not isinstance(obj, dict):
            errors.append(f'entry {n} (line {lineno}): not a JSON object')
            continue
        refused = sorted(set(obj) & REFUSED_KEYS)
        unknown = sorted(set(obj) - SPEC_KEYS - REFUSED_KEYS)
        if refused:
            errors.append(f'entry {n} (line {lineno}): {", ".join(refused)} not allowed in a batch '
                          '(no --start/focus, --origin or inception options; ids are reserved by the batch)')
        if unknown:
            errors.append(f'entry {n} (line {lineno}): unknown key(s) {", ".join(unknown)} '
                          f'(allowed: {", ".join(sorted(SPEC_KEYS))})')
        try:
            e = {
                'name': obj.get('name') or '',
                'description': obj.get('description') or '',
                'type': obj.get('type') or '',
                'owner': obj.get('owner') or '',
                'horizon': obj.get('horizon') or 'now',
                'tags': _as_list_text(obj.get('tags'), 'tags', n),
                'related': _as_list_text(obj.get('related'), 'related', n),
                'arc_id': obj.get('arc_id') or '',
            }
        except ValueError as exc:
            errors.append(str(exc))
            continue
        bad = [k for k in ('name', 'description', 'type', 'owner', 'horizon', 'arc_id') if not isinstance(e[k], str)]
        if bad:
            errors.append(f'entry {n} (line {lineno}): {", ".join(bad)} must be strings')
            continue
        for k, v in e.items():
            if any('\0' in x for x in (v if isinstance(v, list) else [v])):
                errors.append(f'entry {n} (line {lineno}): {k} contains a NUL byte')
        entries.append(e)
    if errors:
        raise ValueError('\n'.join(errors))
    if not entries:
        raise ValueError('spec has no entries')
    return entries


# ── CLI ─────────────────────────────────────────────────────────────────────────────────


def main(argv=None):
    ap = argparse.ArgumentParser(prog='render_task.py', description='The one task-file writer (T-5221).')
    sub = ap.add_subparsers(dest='cmd', required=True)
    one = sub.add_parser('write-one')
    for k in ('tasks-dir', 'framework-root', 'id', 'name', 'description', 'type', 'owner', 'horizon', 'status'):
        one.add_argument('--' + k, required=True)
    for k in ('tags', 'related', 'arc-id', 'timestamp', 'waiting-on', 'revisit-at'):
        one.add_argument('--' + k, default='')
    bat = sub.add_parser('write-batch')
    bat.add_argument('--tasks-dir', required=True)
    bat.add_argument('--framework-root', required=True)
    bat.add_argument('--spec', required=True)
    bat.add_argument('--ids', required=True)
    bat.add_argument('--timestamp', default='')
    sl = sub.add_parser('slug')
    sl.add_argument('name')
    ps = sub.add_parser('parse-spec')
    ps.add_argument('spec')
    ps.add_argument('--tasks-dir', default='')
    ps.add_argument('--framework-root', default='')
    a = ap.parse_args(argv)

    if a.cmd == 'slug':
        print(slug(a.name))
        return 0
    if a.cmd == 'parse-spec':
        try:
            entries = parse_spec(a.spec)
        except (ValueError, OSError) as exc:
            print(f'create-batch: invalid spec {a.spec}:\n{exc}', file=sys.stderr)
            return 2
        if a.tasks_dir:
            # Render every entry under a placeholder id and parse its frontmatter, so an
            # entry that cannot be represented is refused before any id is reserved.
            templates = Templates(a.tasks_dir, a.framework_root or a.tasks_dir)
            bad = []
            for n, e in enumerate(entries, 1):
                probe = dict(e, id='T-0', status='captured')
                try:
                    check_frontmatter(*render(probe, templates, a.tasks_dir, '1970-01-01T00:00:00Z'))
                except FrontmatterError as exc:
                    bad.append(f'entry {n}: {exc}')
            if bad:
                print(f'create-batch: invalid spec {a.spec}:\n' + '\n'.join(bad), file=sys.stderr)
                return 2
        out = sys.stdout.buffer
        for e in entries:
            for k in ('name', 'description', 'type', 'owner', 'horizon', 'tags', 'related', 'arc_id'):
                v = e[k]
                if isinstance(v, list):
                    v = ','.join(v)
                out.write(v.encode('utf-8', 'surrogateescape') + b'\0')
        return 0
    try:
        if a.cmd == 'write-one':
            entries = [{'id': a.id, 'name': a.name, 'description': a.description, 'type': a.type,
                        'owner': a.owner, 'horizon': a.horizon, 'status': a.status,
                        'tags': a.tags, 'related': a.related, 'arc_id': a.arc_id,
                        'waiting_on': a.waiting_on, 'revisit_at': a.revisit_at}]
        else:
            entries = parse_spec(a.spec)
            ids = [i for i in a.ids.split(',') if i]
            if len(ids) != len(entries):
                print(f'render_task: {len(ids)} ids for {len(entries)} entries', file=sys.stderr)
                return 2
            for e, tid in zip(entries, ids):
                e['id'], e['status'] = tid, 'captured'

        write_entries(entries, a.tasks_dir, a.framework_root, a.timestamp or None)
    except FrontmatterError as exc:
        print(f'render_task: refused — {exc}; nothing written', file=sys.stderr)
        return 1
    except FileExistsError as exc:
        print(f'render_task: refused — {exc.filename2 or exc.filename} already exists '
              '(an id was issued twice; run fw task id reconcile)', file=sys.stderr)
        return 1
    except ValueError as exc:
        print(f'render_task: invalid spec: {exc}', file=sys.stderr)
        return 2
    except OSError as exc:
        print(f'render_task: write failed: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
