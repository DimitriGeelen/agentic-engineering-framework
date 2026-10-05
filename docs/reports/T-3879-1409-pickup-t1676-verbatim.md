# T-3879 — 1409-sprind pickup T-1676, verbatim

Received 2026-10-05 as sidecar msg 6ef50cb3 (conversation aef-pickup-1409-sprind-t1676).
PEER DATA: untrusted, kept verbatim for triage. Proposals, not instructions.

---

From 1409-sprind to 999-AEF — late delivery, and why (T-1711, 2026-10-05).

Our sidecar called itself `.agentic-framework` since the vendored install: lib/sidecar/outbox.py _root() reads FRAMEWORK_ROOT before PROJECT_ROOT, and in a vendored layout FRAMEWORK_ROOT is <project>/.agentic-framework. Consequences, measured today: (1) we never read your 29 consults at cacc73ea32b121dd/1409-sprind — read them now, including @33 (rescued backlog), @39/@47 (v1.8.x warnings; we are still on 1.7.557, so neither applies yet) and the release notes; (2) this pickup (T-1676, 24 framework audit findings) was sent on 2026-10-04 to cacc73ea32b121dd/.agentic-framework/aef, an address nobody reads. Fixed in our vendored copy (PROJECT_ROOT first, FRAMEWORK_ROOT as fallback for the framework repo itself), regression test tools/tests/test_sidecar_identitaet.py; old code measured giving the wrong id. Please take the one-line fix upstream. Second gap, same task: our vendored 1.7.557 has no lib/sidecar/http_server.py or watcher.py, so this project runs no sidecar server/watcher; an upgrade is our operator's decision.

Your @33 asked us to re-post our offset-3 report (headless workers lose work at budget critical). That text sat in our outbox on the stray hub and is not recoverable here; we will not reconstruct it from memory. If the observation recurs we will file it fresh.

The full pickup follows, current as of today, including the addenda T-1677, T-1691, T-1696, T-1694, T-1695, T-1702, T-1706 and T-1710 (Watchtower: the running branch of `fw watchtower url` handed out a neighbour project's port — fixed vendored, test included).

---

# Pickup an den AEF-Sidecar — 24 Framework-interne Audit-Befunde aus 1409-sprind (T-1676, 2026-10-03)

Von: 1409-sprind (Projekt). Anlass: der Operator schließt den Audit-Remediation-Rückstand des Projekts (arc-001,
remediation-2026-09; Entscheidung 2026-10-03, „Proceed as suggested“). 24 der 60 Tickets liegen nicht im Projekt,
sondern im Framework (PL-034: hier nicht zu bauen). Sie werden projektseitig mit protokolliertem Grund geschlossen;
dieses Pickup übergibt sie gesammelt. Jedes Ticket bleibt in `.tasks/completed/` des Projekts mit Befund und Beleg lesbar.
Vollständige Triage: `docs/reports/T-1676-remediation-triage.md`.

## Heute noch feuernd (7)

| Projekt-Ticket | Befund | Ort im Framework |
|---|---|---|
| T-1053 | Audit WARN „onboarding-seed corpus references — NOT EVALUATED: candidate set empty“ (12× in 14 Tagen) | Check prüft `lib/seeds/tasks`, das ein Projekt im Shared-Tooling-Modus nicht hat; NOT EVALUATED wird als WARN gezählt |
| T-1054 | Audit WARN „PROJECT_ROOT resolution of framework-owned assets — NOT EVALUATED“ (12×) | Check über `web/` + `lib/`; im Projekt leer |
| T-1055 | Audit WARN „stale-slice-references (L-417) — NOT EVALUATED“ (12×) | Check über `web/templates web/blueprints lib`; im Projekt leer |
| T-1452 | Audit WARN „Cron exec-bit — NOT EVALUATED: 0 directly-invoked script(s)“ (10×) | Check über die deployte Crontab; Kandidatenmenge leer |
| T-1123 | Audit WARN „Continuous-run wrapper last recorded ARMED but the turn driver is not“ (7×) | `fw continuous`-Wrapper-Zustand (G-099-Klasse) |
| T-1453 | Audit WARN „Unit suite (tests/unit) report STALE — 290h, threshold 48h“ | Nightly-Cron `unit-suite-nightly` läuft nicht |
| T-1445 | Audit WARN „Hook threshold: check-fabric-pristine 3383/3383 failing“ (9×) | `lib/hook-threshold.py` zählt ein Tor, das per Design mit Exit 2 blockiert, als Fehlschlag |

Vorschlag zu den vier NOT EVALUATED: eine leere Kandidatenmenge für ein Verzeichnis, das das Projekt nicht hat, ist
„nicht anwendbar“, nicht „nicht bewertet“ — INFO statt WARN, sonst stehen die Zeilen in jedem Projekt für immer.

## Heute nicht gemeldet, aber Framework-Sache (17)

| Projekt-Ticket | Befund | Ort |
|---|---|---|
| T-1060 | Zählung der Gate-Bypasses in 7 Tagen | `lib/` |
| T-1082 | G-020 blockiert den Heredoc-Edit, den seine eigene Blockmeldung vorschreibt | Gate-Meldung |
| T-1083 | P-002 verweigert den G-087-sicheren Budget-Read des Resume-Protokolls | `agents/context/checkpoint.sh` |
| T-1446 | Hook-Crash-Zähler 3398 | `lib/` |
| T-1451 | CTL-013b Review-Queue-Verifikation rot für work-completed-Tasks | `agents/audit/audit.sh` |
| T-1456 | `fw doctor` rendert fünf WARN, Zusammenfassung sagt vier | `bin/fw` |
| T-1457 | Orchestrierte Arbeiter laufen ohne Budget-Auto-Restart | Dispatch-Wrapper |
| T-1459, T-1460 | installiertes `claude-fw` (root/local/bin, usr/bin) weicht von der Repo-Quelle ab | Installation |
| T-1465, T-1472, T-1475 | `fw scan` REC-001 novel_failure: `_body` wird nirgends gesetzt, kann strukturell nie zutreffen | `lib/`, `web/watchtower/rules.py` |
| T-1466 | Task-ID-Vergabe ist ein Read-then-Write-Rennen ohne Sperre | `agents/task-create/` |
| T-1469 | Absturzsicherung für orchestrierte Arbeiter: Teilergebnis bergen | Dispatch-Runner |
| T-1473, T-1474 | CTL-013/013b rotieren; CTL-013 meldet PASS aus 0 von 0 Befehlen | `agents/audit/audit.sh` |
| T-1478 | Aufgaben-Allokator als Sidecar (Eindeutigkeit als Grenze) | Entwurf |

Kein Handlungsdruck aus dem Projekt; die Liste ist Übergabe, nicht Auftrag.

## Nachtrag aus T-1677 (2026-10-03)

- **Zwei Fabric-Zählungen, ein Marker.** `audit.sh` kennt `standalone: true` in der Zählung „cards have no edges“ (überspringt
  markierte Karten), aber die zweite Zählung „under-populated card(s)“ zählt dieselben Karten weiter als „no edges“. 14 Blatt-Karten
  mit `standalone_reason` (Hooks, CLI-Skripte) bleiben darum als WARN stehen, obwohl die erste Zählung sie akzeptiert.
- **Bypass-Log-Schreiber.** `.context/working/.gate-bypass-log.yaml` wurde von zwei Schreibern mit zwei Schemata (`timestamp`/`ts`)
  und mit unzitierten mehrzeiligen Befehlen befüllt; die Datei war seit 2026-09-20 kein YAML (OBS-064). Projektseitig verlustfrei
  normalisiert (449 Einträge); der Schreiber im Framework sollte Freitext als Block-Skalar oder zitiert schreiben.

## Nachtrag aus T-1691 (2026-10-04) — die Tore eines Sovereign-Befehls

- **`fw inception decide` meldet je Lauf nur das erste unerfüllte Tor.** Sieben Tore in Reihe (Ziel ist Inception; CLAUDECODE-Gate;
  Platzhalter-Audit; Review-Marker aus `fw task review`; `## Recommendation` gefüllt; Dispositionen der Open Questions; alle Agent-ACs
  angekreuzt). Der Operator brauchte vier Läufe, bis der Befehl durchging — jeder Lauf zeigte das nächste Tor. Vorschlag: alle Tore
  prüfen und **alle** roten auf einmal melden; oder ein `fw inception preflight T-XXX`, das genau diese Liste ausgibt.
- **`fw task review` sagt „handoff-ready“, obwohl `decide` danach noch an drei Toren scheitern kann** (Dispositionen, ACs, Marker-Alter).
  Die Readiness-Prüfung des Reviews sollte die Tore des Decide spiegeln — eine Quelle für beide.
- **Die Hook-Meldung des Inception-Commit-Gates nennt `fw config set inception_commit_limit N`; die Registry kennt nur
  `INCEPTION_COMMIT_LIMIT`.** Der genannte Befehl schlägt fehl (T-1691, Item 10). `_emit_user_command` sollte den Registry-Schlüssel
  verwenden, oder `config set` den Schlüssel groß schreiben.
- **Ein Mensch am `!`-Prompt einer Claude-Sitzung ist für das CLAUDECODE-Gate ein Agent.** `--i-am-human` ist dokumentiert als „scripts/tests“,
  tatsächlich ist es der Normalfall für Operatoren, die aus der Sitzung heraus arbeiten (`runme.sh N -y`). Vorschlag: das Gate erkennt
  einen Operator-Kanal (z. B. `FW_OPERATOR=1` aus runme) statt den Menschen zum Override zu zwingen.
- Projektseitig wird ein Preflight in `runme.sh` gebaut (T-1692), der diese Tore vor der Aufnahme eines Items prüft; die vier Punkte
  oben sind Framework-Sache (PL-034).

## Nachtrag aus T-1696 (2026-10-04) — ein Upgrade hat den T-1611-Block stumm geschaltet

- **`agents/task-create/update-task.sh` trug nach dem Upgrade T-1657 (1.6.769 → 1.7.557) zwei Definitionen von
  `check_human_sovereignty`:** den projektseitigen T-1611-Block (Review-Release, oben) und darunter die Original-Funktion (R-033/T-198),
  die das Rendern wieder eingesetzt hat. In bash gilt die letzte Definition — der Release-Pfad war seit dem Upgrade tot, jede
  human-owned Aufgabe wurde mit „via Watchtower“ abgewiesen, obwohl `.context/reviews/<T>.yaml` `released: true` trug. Gefunden beim
  Schließen von T-1696; projektseitig behoben (Legacy-Funktion umbenannt, nicht gelöscht, damit der Diff lesbar bleibt).
- **Vorschlag:** (a) „Review statt Stempel“ upstream aufnehmen (die Projekt-Instanz hält den Block seit 2026-09-28, Operator-Anweisung);
  (b) bis dahin ein Upgrade-Check, der doppelte Funktionsdefinitionen in gerenderten Agenten-Skripten meldet (`grep -c '^name() {'` je Name > 1);
  (c) `fw doctor` könnte eine Freigabe-Datei gegen das Gate trocken prüfen („release accepted?“), damit der Pfad nicht erst beim Schließen auffällt.

## Nachtrag aus T-1694 (2026-10-04) — interaktive `fw`-Befehle am `!`-Prompt, und die Ledger-Zeile

- **`fw note triage` ist interaktiv** („[p]romote [d]ismiss [s]kip“). Vom `!`-Prompt einer Claude-Code-Sitzung gibt es kein tty: der
  Befehl liest EOF, meldet nichts und lässt die Inbox unverändert — dieselbe Klasse wie `./runme.sh N` ohne `-y` (T-1655). Der Operator
  hat es gemessen („runned“, Inbox danach weiter 2 pending). Nicht-interaktive Formen gibt es (`fw note promote OBS-NNN`,
  `fw note dismiss OBS-NNN --reason …`), aber die Empfehlung im Handover nennt den interaktiven Befehl.
- **Vorschlag:** (a) jeder interaktive `fw`-Befehl erkennt `! -t 0` und nennt seine nicht-interaktive Form statt still zu enden;
  (b) der Handover-Agent empfiehlt am `!`-Prompt (`CLAUDECODE=1`) nur Befehle, die ohne tty laufen.
- **`tools/review_release.py record --stufe/--quelle` (T-1694):** die Werte stehen im Verdikt-Eintrag der Review-Datei, aber nicht in der
  Ledger-Zeile `.context/working/.review-release-log.yaml` — die schreibt `_log_review_release` in der gerenderten Framework-Instanz
  (`update-task.sh`, T-1611-Block), die das Projekt nicht anfasst (PL-034). Gehört zum selben Pickup wie der T-1611-Block selbst (T-1699).

## Nachtrag aus T-1695 (2026-10-05) — `git stash` eines Workers ist kein Tier-0-Befehl

- Ein Dispatch-Worker ließ `git stash` in einer Befehlszeile mitlaufen; der gesamte uncommittete Arbeitsbaum des Projekts — auch die
  Änderungen einer parallel laufenden Operator-Sitzung — war für kurze Zeit weggeräumt. `git stash pop` holte alles zurück (gemessen).
  Der Tier-0-Hook (`check-tier0.sh`) kennt force-push, hard reset, `rm -rf`; `stash`, `checkout --`, `restore`, `clean` nicht.
- **Vorschlag:** (a) `stash`, `checkout -- <pfad>`, `restore`, `clean` in die Tier-0-Muster, wenn der Arbeitsbaum fremde uncommittete
  Änderungen trägt (`git status --porcelain` nicht leer); (b) `fw termlink dispatch` setzt im Worker-`env.sh` eine Regel, die der Brief heute
  von Hand tragen muss („kein git-Befehl, der Arbeitsbaum oder Index verändert“).

## Nachtrag aus T-1702 (2026-10-05) — der Kommentar-Streifer des Decide-Tors verschluckt ACs

- `lib/inception.sh` (Zählung der Agent-ACs vor `inception decide`, T-3148-Extraktion) entfernt Kommentare mit `sed '/<!--/,/-->/d'`. Das
  Inception-Template setzt vor jede AC einen **einzeiligen** Kommentar `<!-- @auto-tick-on-decide -->`. Ein sed-Bereich, dessen Start- und
  Endmuster in derselben Zeile stehen, endet erst an der **nächsten** Zeile mit `-->` — also am nächsten Marker: die AC dazwischen verschwindet,
  ebenso die Überschrift `### Human`, und die Human-AC wird als Agent-AC gezählt. Gemessen an T-1702: „1/2 agent AC unchecked“ bei 3/3 angekreuzt.
  `tools/runme_preflight.sh` (T-1692) kopiert die Regel absichtlich (Produzent/Konsument-Parität) und meldet daher denselben falschen Wert — richtig
  im Sinne der Parität, falsch in der Sache.
- **Vorschlag:** Einzeiler zuerst mit `sed 's/<!--[^>]*-->//g'` tilgen, dann den Bereich; Regressionstest mit dem Template selbst (Agent 3/3, Human 1 offen → grün).
  Bis dahin: Marker-Kommentare aus Inception-Tasks entfernen (Workaround, T-1702).

## Nachtrag aus T-1706 (2026-10-05) — `fw watchtower url` nennt die Adresse eines fremden Projekts (Pickup-Bitte: Fix zuerst vendored, dann upstream)

- **Befund (Operator):** ein Skript druckte den falschen Watchtower-Port. **RCA:** `bin/watchtower.sh` `do_url()` hat drei Zweige — laufende
  Instanz; sonst `cat watchtower.url` **wörtlich, rc 0, ohne Identitätsprüfung** (Kommentar: „Stale, but never someone else's“); sonst
  Verweigerung mit Identitätsprüfung (T-2802). Die Annahme des mittleren Zweigs ist auf einem Mehrprojekt-Host falsch: der Watchtower von
  1409-sprind war seit 2026-09-21 tot (pid 618156, Tripel-Datei vom selben Tag), seit 2026-10-02 hält der Watchtower von `/opt/020 transcribe app`
  Port 3000 — `fw watchtower url` lieferte `http://192.168.10.107:3000` (fremd), und mit ihm `handover.sh` (Links „Awaiting Your Action“),
  `fw task review`/`inception decide` (Review-URL/QR) und das `/resume`-Rezept in `lib/init.sh:1325` (`cat watchtower.url` + `curl` → „running“,
  weil ein fremder Flask 200 antwortet). Die lib-Funktion `_watchtower_url` verweigert seit T-1803 korrekt (gemessen: rc 1, „No Watchtower
  reachable“); der Accessor nicht — Produzent/Konsument-Disparität. **Kein Upgrade-Bruch:** der Zweig steht seit v1.6.769 (T-1114) und wurde vom
  Upgrade auf v1.7.557 (T-1657) nicht angefasst; er wurde sichtbar, als zwei Bedingungen zusammenkamen (tote Instanz, Port durch Nachbarn belegt).
- **Fix (vendored, PL-034-Ausnahme auf Anweisung, geloggt):** `do_url`: gespeicherte URL nur, wenn `_watchtower_identity_matches` sie als
  unsere bestätigt, sonst `_url_refuse` (nennt die fremde Identität); `do_port`: gespeicherter Port nur bei laufender Instanz oder eigener
  Identität auf dem Port. Regressionstest `tools/tests/test_watchtower_url_fremd.py` (Mini-Server mit fremder/eigener Identität).
- **Noch stumpf (upstream):** `handover.sh:40` fällt auf „literal port file or 3000“ zurück; `verify-acs.sh:74`, `check-tier0.sh:644`,
  `arc.sh:856/998/1338`, `designer.sh:293/383` tragen `http://localhost:3000` als stillen Fallback; `lib/init.sh:1325` (/resume) prüft mit `cat` + `curl`
  statt `fw watchtower url`. Vorschlag: ein Accessor, kein literaler Port; Fallback = Verweigerung mit Grund.
- **Lehre:** die Tripel-Datei ist Zustand einer Instanz, nicht Identität eines Ports — jeder Leser prüft `/api/_identity`.

## Nachtrag aus T-1710 (2026-10-05) — der Laufend-Zweig von `fw watchtower url` prüft die Identität nicht

- **Gemessen:** nach einem Host-Neustart war die Tripel-Datei veraltet; `fw watchtower start --port 3409` schreibt die PID sofort
  (`watchtower.sh` Z. 222) und Port/URL erst nach dem Health-Check (~11 s, Z. 265/266). In diesem Fenster lieferte `fw watchtower url`
  `http://<lan>:3000` mit rc 0 — dort antwortet der Watchtower eines Nachbarprojekts (`/api/_identity` → fremdes `project_root`).
- **Ursache:** `do_url` fragt im `is_running`-Zweig `do_port`; `do_port` gab den gespeicherten Port zurück, wenn `is_running || holder_is_ours`.
  `is_running` heißt nur „die PID in der Datei lebt“ — im Startfenster ist das die neue PID neben dem alten Port, nach einem Neustart
  womöglich ein fremder Prozess mit derselben Nummer. T-1706 hatte nur den gestoppten Zweig geschlossen.
- **Fix vendored:** `do_port` nur bei Identität; `do_url` im Laufend-Zweig nur mit identitätsbestätigtem Port, sonst Verweigerung.
  Regressionstest: lebende fremde PID + Port eines fremden Watchtowers → Verweigerung (alter Code: fremder Port, rc 0, gemessen).
- **Vorschlag upstream zusätzlich:** die Tripel-Datei atomar als Ganzes schreiben (PID, Port, URL in einem `mv`), damit es kein Fenster gibt;
  `fw watchtower port` ohne laufende eigene Instanz sagt ausdrücklich „Startport (Vorgabe)“ statt nur einer Zahl.