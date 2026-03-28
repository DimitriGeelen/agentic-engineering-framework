/**
 * fw-util — Multi-subcommand utility replacing inline Python blocks.
 *
 * Usage: node fw-util.js <subcommand> [args...]
 *
 * Subcommands:
 *   yaml-get <file> <key>           Read YAML key (dot-path: a.b.c)
 *   yaml-set <file> <key> <value>   Write YAML key
 *   json-get <file> <key>           Read JSON key (dot-path: a.b.c)
 *   json-set <file> <key> <value>   Write JSON key
 *   path-rel <from> <to>            Compute relative path
 *   path-resolve <base> <path>      Resolve absolute path
 *   date-fmt [--iso|--epoch|--human] Format current time
 *   frontmatter <file>              Extract YAML frontmatter as JSON
 */

import * as fs from "fs";
import * as path from "path";
import * as yaml from "js-yaml";

// --- Helpers ---

function die(msg: string): never {
  process.stderr.write(`fw-util: ${msg}\n`);
  process.exit(1);
}

function readFile(filePath: string): string {
  try {
    return fs.readFileSync(filePath, "utf-8");
  } catch {
    die(`cannot read file: ${filePath}`);
  }
}

function writeFile(filePath: string, content: string): void {
  try {
    fs.writeFileSync(filePath, content, "utf-8");
  } catch {
    die(`cannot write file: ${filePath}`);
  }
}

function getByDotPath(obj: unknown, dotPath: string): unknown {
  const keys = dotPath.split(".");
  let current: unknown = obj;
  for (const key of keys) {
    if (current === null || current === undefined || typeof current !== "object") {
      return undefined;
    }
    current = (current as Record<string, unknown>)[key];
  }
  return current;
}

function setByDotPath(obj: Record<string, unknown>, dotPath: string, value: unknown): void {
  const keys = dotPath.split(".");
  let current: Record<string, unknown> = obj;
  for (let i = 0; i < keys.length - 1; i++) {
    const key = keys[i];
    if (current[key] === undefined || current[key] === null || typeof current[key] !== "object") {
      current[key] = {};
    }
    current = current[key] as Record<string, unknown>;
  }
  current[keys[keys.length - 1]] = value;
}

function formatValue(val: unknown): string {
  if (val === undefined || val === null) return "";
  if (typeof val === "string") return val;
  if (typeof val === "number" || typeof val === "boolean") return String(val);
  return JSON.stringify(val);
}

function parseYamlFile(filePath: string): unknown {
  const content = readFile(filePath);
  try {
    return yaml.load(content);
  } catch {
    die(`invalid YAML in ${filePath}`);
  }
}

function parseJsonFile(filePath: string): unknown {
  const content = readFile(filePath);
  try {
    return JSON.parse(content);
  } catch {
    die(`invalid JSON in ${filePath}`);
  }
}

// --- Subcommands ---

function yamlGet(args: string[]): void {
  if (args.length < 2) die("usage: yaml-get <file> <key>");
  const [file, key] = args;
  const data = parseYamlFile(file);
  const val = getByDotPath(data, key);
  process.stdout.write(formatValue(val) + "\n");
}

function yamlSet(args: string[]): void {
  if (args.length < 3) die("usage: yaml-set <file> <key> <value>");
  const [file, key, value] = args;
  const data = (parseYamlFile(file) as Record<string, unknown>) || {};
  setByDotPath(data, key, value);
  writeFile(file, yaml.dump(data, { lineWidth: -1, noRefs: true }));
}

function jsonGet(args: string[]): void {
  if (args.length < 2) die("usage: json-get <file> <key>");
  const [file, key] = args;
  const data = parseJsonFile(file);
  const val = getByDotPath(data, key);
  process.stdout.write(formatValue(val) + "\n");
}

function jsonSet(args: string[]): void {
  if (args.length < 3) die("usage: json-set <file> <key> <value>");
  const [file, key, value] = args;
  const data = (parseJsonFile(file) as Record<string, unknown>) || {};

  // Try to preserve type: number, boolean, null
  let typedValue: unknown = value;
  if (value === "true") typedValue = true;
  else if (value === "false") typedValue = false;
  else if (value === "null") typedValue = null;
  else if (/^-?\d+(\.\d+)?$/.test(value)) typedValue = Number(value);

  setByDotPath(data, key, typedValue);
  writeFile(file, JSON.stringify(data, null, 2) + "\n");
}

function pathRel(args: string[]): void {
  if (args.length < 2) die("usage: path-rel <from> <to>");
  const [from, to] = args;
  process.stdout.write(path.relative(from, to) + "\n");
}

function pathResolve(args: string[]): void {
  if (args.length < 2) die("usage: path-resolve <base> <path>");
  const [base, rel] = args;
  process.stdout.write(path.resolve(base, rel) + "\n");
}

function dateFmt(args: string[]): void {
  const now = new Date();
  const flag = args[0] || "--iso";

  switch (flag) {
    case "--iso":
      process.stdout.write(now.toISOString() + "\n");
      break;
    case "--epoch":
      process.stdout.write(Math.floor(now.getTime() / 1000) + "\n");
      break;
    case "--human":
      process.stdout.write(now.toISOString().replace("T", " ").replace(/\.\d+Z$/, "Z") + "\n");
      break;
    default:
      die(`unknown format: ${flag} (use --iso, --epoch, or --human)`);
  }
}

function frontmatter(args: string[]): void {
  if (args.length < 1) die("usage: frontmatter <file>");
  const content = readFile(args[0]);

  const match = content.match(/^---\n([\s\S]*?)\n---/);
  if (!match) {
    die(`no frontmatter found in ${args[0]}`);
  }

  try {
    const data = yaml.load(match[1]);
    process.stdout.write(JSON.stringify(data) + "\n");
  } catch {
    die(`invalid YAML frontmatter in ${args[0]}`);
  }
}

function showHelp(): void {
  const help = `fw-util — TypeScript utility for the Agentic Engineering Framework

Usage: node fw-util.js <subcommand> [args...]

Subcommands:
  yaml-get <file> <key>              Read YAML value by dot-path key
  yaml-set <file> <key> <value>      Write YAML value by dot-path key
  json-get <file> <key>              Read JSON value by dot-path key
  json-set <file> <key> <value>      Write JSON value by dot-path key
  path-rel <from> <to>               Compute relative path
  path-resolve <base> <path>         Resolve to absolute path
  date-fmt [--iso|--epoch|--human]   Format current time (default: --iso)
  frontmatter <file>                 Extract YAML frontmatter as JSON

Examples:
  node fw-util.js yaml-get .tasks/active/T-001.md status
  node fw-util.js json-get package.json version
  node fw-util.js path-rel /opt/framework /opt/framework/lib/ts
  node fw-util.js frontmatter .tasks/active/T-001.md
`;
  process.stdout.write(help);
}

// --- Main ---

const subcommand = process.argv[2];
const subArgs = process.argv.slice(3);

switch (subcommand) {
  case "yaml-get":    yamlGet(subArgs);    break;
  case "yaml-set":    yamlSet(subArgs);    break;
  case "json-get":    jsonGet(subArgs);    break;
  case "json-set":    jsonSet(subArgs);    break;
  case "path-rel":    pathRel(subArgs);    break;
  case "path-resolve": pathResolve(subArgs); break;
  case "date-fmt":    dateFmt(subArgs);    break;
  case "frontmatter": frontmatter(subArgs); break;
  case "--help":
  case "-h":
  case "help":        showHelp();          break;
  default:
    if (!subcommand) die("no subcommand specified (use --help)");
    die(`unknown subcommand: ${subcommand} (use --help)`);
}
