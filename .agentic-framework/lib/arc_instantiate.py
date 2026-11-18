#!/usr/bin/env python3
"""Expand a template arc into an arc plus a create-batch spec (T-5221, slice 2 of T-5212).

`fw arc instantiate <template> --param k=v ...` (lib/arc.sh arc_instantiate) calls this to
turn a template and its parameters into (a) the new arc's fields and (b) a create-batch spec
whose entries all carry `arc_id: <the new arc's slug>`. Creating the files is not done here:
the arc goes through arc_create, the tasks through `fw task create-batch`, so there is still
one arc writer and one task writer.

TEMPLATE FORMAT (YAML; `fw arc instantiate NAME` reads .context/arcs/templates/NAME.yaml, or
a path). The templates/ subdirectory is never read as an arc: arc readers glob arcs/*.yaml.

    template: municipality-scan        # optional, informational
    params:                            # every parameter the template uses
      - municipality                   #   a list: all required
    # or a mapping, value = default (null = required):
    #   params: {municipality: null, region: west}
    arc:
      id: "scan-{municipality}"        # the arc slug; a fixed name from a parameter is fine
      name: "Municipality scan: {municipality}"
      description: "..."
      headline_mechanic: "<who> <does what> <observes what result>"
      start: false                     # true: the arc is created in-progress (arc create --start)
      anchor: 1                        # optional: 1-based index of the task that anchors the arc
    tasks:                             # create-batch entries (same keys, same rules)
      - name: "Collect sources for {municipality}"
        description: "..."
        type: build
        owner: agent
        horizon: next
        tags: [scan, "{region}"]
        related: []

Placeholders are `{name}` in any string (also inside tag/related lists). `{{` and `}}` are
literal braces. A placeholder that is not a declared parameter, a declared parameter that
is neither given nor defaulted, and a given parameter the template does not declare are all
errors — a typo never silently produces a task named "Collect sources for {municipalty}".

Usage: arc_instantiate.py --template FILE [--param k=v ...] --out-dir DIR
  writes DIR/spec.jsonl, prints the arc fields NUL-separated on stdout:
  slug, name, description, headline_mechanic, start (0|1), anchor (index or empty), count.
Exit: 0 ok, 2 bad template or parameters (every problem listed on stderr).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

import yaml

_PH = re.compile(r'\{\{|\}\}|\{([A-Za-z_][A-Za-z0-9_-]*)\}')
TASK_KEYS = {'name', 'description', 'type', 'owner', 'horizon', 'tags', 'related'}
ARC_KEYS = {'id', 'name', 'description', 'headline_mechanic', 'start', 'anchor'}


def _subst(value, params, where, errors, used, declared=()):
    if isinstance(value, str):
        def one(m):
            tok = m.group(0)
            if tok == '{{':
                return '{'
            if tok == '}}':
                return '}'
            key = m.group(1)
            if key not in params:
                if key not in declared:
                    errors.append(f'{where}: placeholder {{{key}}} is not a declared parameter')
                return tok
            used.add(key)
            return params[key]
        return _PH.sub(one, value)
    if isinstance(value, list):
        return [_subst(v, params, f'{where}[{i}]', errors, used, declared) for i, v in enumerate(value)]
    return value


def expand(template, given):
    """Return (arc, tasks, errors)."""
    errors = []
    if not isinstance(template, dict):
        return None, None, ['template is not a YAML mapping']
    declared = template.get('params') or []
    if isinstance(declared, list):
        defaults = {str(k): None for k in declared}
    elif isinstance(declared, dict):
        defaults = {str(k): (None if v is None else str(v)) for k, v in declared.items()}
    else:
        return None, None, ['params: must be a list or a mapping']
    for k in sorted(set(given) - set(defaults)):
        errors.append(f'--param {k}: the template declares no parameter "{k}" '
                      f'(declared: {", ".join(sorted(defaults)) or "none"})')
    params = {}
    for k, default in defaults.items():
        if k in given:
            params[k] = given[k]
        elif default is not None:
            params[k] = default
        else:
            errors.append(f'parameter "{k}" is required: --param {k}=<value>')
    unknown_top = sorted(set(template) - {'template', 'params', 'arc', 'tasks'})
    if unknown_top:
        errors.append(f'unknown top-level key(s): {", ".join(unknown_top)}')
    arc_t = template.get('arc')
    tasks_t = template.get('tasks')
    if not isinstance(arc_t, dict):
        errors.append('arc: must be a mapping with id, name, headline_mechanic')
        arc_t = {}
    if not isinstance(tasks_t, list) or not tasks_t:
        errors.append('tasks: must be a non-empty list')
        tasks_t = []
    used = set()
    for k in sorted(set(arc_t) - ARC_KEYS):
        errors.append(f'arc.{k}: unknown key (allowed: {", ".join(sorted(ARC_KEYS))})')
    arc = {}
    for k in ('id', 'name', 'description', 'headline_mechanic'):
        v = arc_t.get(k, '')
        if v is None:
            v = ''
        if not isinstance(v, str):
            errors.append(f'arc.{k}: must be a string')
            v = ''
        arc[k] = _subst(v, params, f'arc.{k}', errors, used, defaults)
    for k in ('id', 'name', 'headline_mechanic'):
        if not arc[k]:
            errors.append(f'arc.{k}: required')
    start = arc_t.get('start', False)
    if not isinstance(start, bool):
        errors.append('arc.start: must be true or false')
    arc['start'] = bool(start)
    anchor = arc_t.get('anchor')
    if anchor is not None and (not isinstance(anchor, int) or isinstance(anchor, bool)
                               or not 1 <= anchor <= len(tasks_t)):
        errors.append(f'arc.anchor: must be a task index from 1 to {len(tasks_t)}')
        anchor = None
    arc['anchor'] = anchor
    tasks = []
    for i, t in enumerate(tasks_t, 1):
        if not isinstance(t, dict):
            errors.append(f'tasks[{i}]: not a mapping')
            continue
        bad = sorted(set(t) - TASK_KEYS)
        if bad:
            errors.append(f'tasks[{i}]: key(s) {", ".join(bad)} not allowed '
                          f'(allowed: {", ".join(sorted(TASK_KEYS))}; arc membership is set by instantiate)')
        out = {}
        for k in sorted(TASK_KEYS & set(t)):
            v = t[k]
            if k in ('tags', 'related'):
                if v is None:
                    v = []
                if isinstance(v, str):
                    v = [v]
                if not isinstance(v, list) or not all(isinstance(x, (str, int)) for x in v):
                    errors.append(f'tasks[{i}].{k}: must be a list of strings')
                    continue
                v = [str(x) for x in v]
            elif v is None:
                v = ''
            elif not isinstance(v, str):
                errors.append(f'tasks[{i}].{k}: must be a string')
                continue
            out[k] = _subst(v, params, f'tasks[{i}].{k}', errors, used, defaults)
        out['arc_id'] = arc['id']
        tasks.append(out)
    for k in sorted(set(params) - used):
        if k in given:
            print(f'arc instantiate: note — parameter "{k}" is declared but not used by the template',
                  file=sys.stderr)
    return arc, tasks, errors


def load_template(path):
    with open(path, encoding='utf-8') as fh:
        return yaml.safe_load(fh)


def main(argv=None):
    ap = argparse.ArgumentParser(prog='arc_instantiate.py')
    ap.add_argument('--template', required=True)
    ap.add_argument('--param', action='append', default=[])
    ap.add_argument('--out-dir', required=True)
    a = ap.parse_args(argv)
    given, errors = {}, []
    for p in a.param:
        k, sep, v = p.partition('=')
        if not sep or not k:
            errors.append(f'--param {p!r}: expected k=v')
        elif k in given:
            errors.append(f'--param {k}: given twice')
        else:
            given[k] = v
    try:
        template = load_template(a.template)
    except (OSError, yaml.YAMLError) as exc:
        print(f'arc instantiate: cannot read template {a.template}: {exc}', file=sys.stderr)
        return 2
    arc, tasks, more = expand(template, given)
    errors += more
    if errors:
        print(f'arc instantiate: refused — {len(errors)} problem(s) in {a.template}:', file=sys.stderr)
        for e in errors:
            print(f'  {e}', file=sys.stderr)
        return 2
    with open(os.path.join(a.out_dir, 'spec.jsonl'), 'w', encoding='utf-8') as fh:
        for t in tasks:
            fh.write(json.dumps(t, ensure_ascii=False) + '\n')
    fields = [arc['id'], arc['name'], arc['description'], arc['headline_mechanic'],
              '1' if arc['start'] else '0', str(arc['anchor'] or ''), str(len(tasks))]
    sys.stdout.write('\0'.join(fields) + '\0')
    return 0


if __name__ == '__main__':
    sys.exit(main())
