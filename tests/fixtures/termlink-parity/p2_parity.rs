//! T-3761: the P-2 parity fixture (`tests/fixtures/b25-parity/p2-report-ordering.json`)
//! published for AEF request P-44 (B-29), run against TermLink's own meter so the
//! fixture cannot drift from the code (04 17.2.a, 06 AL-1 CR-6.24, E-156, T-3693).
//!
//! Three checks:
//! 1. every case's payloads, fed verbatim to the meter, give each step's `expect`,
//!    `ord` and `turn_stopped` and the case's `after`;
//! 2. a reference oracle written from the fixture's `about` (not from meter.rs)
//!    agrees with every expectation, and the same oracle keyed on `at_ms`
//!    disagrees with exactly the cases the first negative control names
//!    (the control: the fixture cannot be satisfied by wall-clock ordering);
//! 3. the `hook_requests` section matches `hook::request` and the old-sidecar retry.

use serde_json::{Value, json};
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};
use termlink_sidecar::meter::*;

const FIXTURE: &str = include_str!("../../../tests/fixtures/b25-parity/p2-report-ordering.json");

fn doc() -> Value {
    serde_json::from_str(FIXTURE).expect("fixture parses")
}

fn cases(d: &Value) -> &Vec<Value> {
    d["cases"].as_array().expect("cases")
}

const SESSION: &str = "sess-p2";

// ---- 1. the meter --------------------------------------------------------------------------

#[test]
fn p2_parity_fixture_matches_the_meter() {
    let d = doc();
    assert_eq!(d["schema"], "termlink.parity/1");
    assert!(d["negative_controls"].as_array().is_some_and(|n| !n.is_empty()));
    let agent = d["agent_id"].as_str().expect("agent_id");
    assert!(cases(&d).len() >= 9);
    for c in cases(&d) {
        let name = c["name"].as_str().unwrap();
        let now = Arc::new(AtomicU64::new(1_000_000));
        let (n1, n2) = (now.clone(), now.clone());
        let m = Meter::new(agent, Box::new(Unbound), Box::new(NoLedger))
            .with_clocks(Arc::new(move || n1.load(Ordering::SeqCst)), Arc::new(move || n2.load(Ordering::SeqCst)));
        for (i, st) in c["steps"].as_array().unwrap().iter().enumerate() {
            let at = format!("{name} step {i}");
            now.fetch_add(st["rx_advance_ms"].as_u64().unwrap_or(0), Ordering::SeqCst);
            let p = &st["payload"];
            let got = match m.intake(p.to_string().as_bytes()) {
                Intake::Applied => "applied".to_string(),
                Intake::Dropped(why) => format!("dropped:{why}"),
                Intake::Ignored(why) => format!("ignored:{why}"),
            };
            assert_eq!(got, st["expect"].as_str().unwrap(), "{at}");
            if let Some(want) = st.get("ord") {
                let ord = match p["event"].as_str().unwrap() {
                    "ready" => m.ready(SESSION).expect("ready").ord,
                    "prompt_submit" => m.last_prompt(SESSION).expect("prompt").ord,
                    e => panic!("{at}: ord on {e}"),
                };
                let want = if want == "receive-stamp" {
                    ReportOrd::rx(now.load(Ordering::SeqCst))
                } else {
                    ReportOrd { boot: want["boot"].as_str().unwrap().into(), ns: want["ns"].as_str().unwrap().parse().unwrap() }
                };
                assert_eq!(ord, want, "{at}");
            }
            if let Some(ts) = st.get("turn_stopped").and_then(Value::as_bool) {
                m.tick();
                assert_eq!(m.status_view()["sessions"][SESSION]["turn_stopped"].is_u64(), ts, "{at}");
            }
        }
        let a = &c["after"];
        if let Some(s) = a["ready_state"].as_str() {
            assert_eq!(m.ready(SESSION).expect("ready").state, s, "{name}");
        }
        if let Some(n) = a["ready_reordered"].as_u64() {
            assert_eq!(m.counters().ready_reordered, n, "{name}");
        }
        if let Some(n) = a["prompt_reordered"].as_u64() {
            assert_eq!(m.counters().prompt_reordered, n, "{name}");
        }
        if let Some(o) = a["last_prompt_origin"].as_str() {
            assert_eq!(m.last_prompt(SESSION).expect("prompt").origin.name(), o, "{name}");
        }
        if let Some(ts) = a["turn_stopped"].as_bool() {
            m.tick();
            assert_eq!(m.status_view()["sessions"][SESSION]["turn_stopped"].is_u64(), ts, "{name}");
        }
        assert_eq!(m.counters().unparseable, 0, "{name}: a fixture payload was refused: {:?}", m.counters().reasons);
    }
}

// ---- 2. reference oracle and the negative control -------------------------------------------

/// An order key: (domain, value). Same domain: higher value is later; another
/// domain is later than everything before it.
type Key = (String, u128);

/// The rule as the fixture's `about` states it: a valid (boot_id, mono_ns)
/// pair, else the receive stamp.
fn spec_key(p: &Value, rx_ms: u64) -> Key {
    let boot = p["boot_id"].as_str().filter(|b| !b.is_empty() && b.len() <= 64 && b.chars().all(|c| c.is_ascii_alphanumeric() || c == '-'));
    let ns: Option<u128> = match &p["mono_ns"] {
        Value::Number(n) => n.as_u64().map(u128::from),
        Value::String(s) if !s.is_empty() && s.chars().all(|c| c.is_ascii_digit()) => s.parse::<u128>().ok().filter(|v| *v <= u128::from(u64::MAX)),
        _ => None,
    };
    match (boot, ns) {
        (Some(b), Some(n)) => (format!("adapter:{b}"), n),
        _ => ("rx".into(), u128::from(rx_ms)),
    }
}

/// The wrong rule the first negative control names: order by `at_ms`.
fn at_ms_key(p: &Value, _rx_ms: u64) -> Key {
    ("wall".into(), u128::from(p["at_ms"].as_u64().unwrap()))
}

fn before(a: &Key, b: &Key) -> bool {
    a.0 == b.0 && a.1 < b.1
}

/// Replays one case under `key`; true when every step's `expect`/`turn_stopped`
/// and the case's `after` (state, counters, turn) come out as the fixture says.
fn oracle_agrees(c: &Value, key: fn(&Value, u64) -> Key) -> bool {
    let mut rx = 1_000_000u64;
    let mut ready: Option<(String, Key)> = None;
    let mut prompt: Option<(String, Key)> = None;
    let mut stopped = false;
    let (mut ready_re, mut prompt_re) = (0u64, 0u64);
    let mut ok = true;
    let stop = |prompt: &Option<(String, Key)>, stopped: &mut bool, k: &Key| {
        if let Some((_, pk)) = prompt
            && !*stopped
            && !before(k, pk)
            && k != pk
        {
            *stopped = true;
        }
    };
    for st in c["steps"].as_array().unwrap() {
        rx += st["rx_advance_ms"].as_u64().unwrap_or(0);
        let p = &st["payload"];
        let k = key(p, rx);
        let got = match p["event"].as_str().unwrap() {
            "ready" => {
                let state = p["state"].as_str().unwrap().to_string();
                match &ready {
                    Some((_, rk)) if before(&k, rk) => {
                        ready_re += 1;
                        "dropped:ready-reordered"
                    }
                    Some((rs, rk)) if *rk == k && rs == "BUSY" && state != "BUSY" => "dropped:tie keeps BUSY",
                    _ => {
                        if state == "READY" {
                            stop(&prompt, &mut stopped, &k);
                        }
                        ready = Some((state, k));
                        "applied"
                    }
                }
            }
            "prompt_submit" => match &prompt {
                Some((_, pk)) if before(&k, pk) => {
                    prompt_re += 1;
                    "dropped:prompt-reordered"
                }
                _ => {
                    prompt = Some((p["origin"].as_str().unwrap().to_string(), k));
                    stopped = false;
                    "applied"
                }
            },
            "turn_stop" => {
                stop(&prompt, &mut stopped, &k);
                "applied"
            }
            e => panic!("oracle: event {e}"),
        };
        ok &= got == st["expect"].as_str().unwrap();
        if let Some(ts) = st["turn_stopped"].as_bool() {
            ok &= ts == stopped;
        }
    }
    let a = &c["after"];
    if let Some(s) = a["ready_state"].as_str() {
        ok &= ready.as_ref().is_some_and(|(r, _)| r == s);
    }
    if let Some(n) = a["ready_reordered"].as_u64() {
        ok &= n == ready_re;
    }
    if let Some(n) = a["prompt_reordered"].as_u64() {
        ok &= n == prompt_re;
    }
    if let Some(o) = a["last_prompt_origin"].as_str() {
        ok &= prompt.as_ref().is_some_and(|(p, _)| p == o);
    }
    if let Some(ts) = a["turn_stopped"].as_bool() {
        ok &= ts == stopped;
    }
    ok
}

#[test]
fn p2_parity_fixture_agrees_with_the_written_rule_and_refutes_at_ms_ordering() {
    let d = doc();
    for c in cases(&d) {
        assert!(oracle_agrees(c, spec_key), "{}: the fixture contradicts its own `about`", c["name"]);
    }
    // Negative control: the at_ms rule fails every case, as the fixture says.
    let control = d["negative_controls"][0].as_str().unwrap();
    assert!(control.contains("orders by at_ms fails every case"), "{control}");
    let passing: Vec<&str> = cases(&d).iter().filter(|c| oracle_agrees(c, at_ms_key)).map(|c| c["name"].as_str().unwrap()).collect();
    assert!(passing.is_empty(), "at_ms ordering satisfies {passing:?}: those cases do not separate the rules");
    // The other two controls name cases that exist.
    for (i, case) in [(1, "mono-ns-as-decimal-string-above-2-pow-53"), (2, "invalid-or-half-pairs-use-the-receive-stamp")] {
        assert!(d["negative_controls"][i].as_str().unwrap().contains(case));
        assert!(cases(&d).iter().any(|c| c["name"] == case), "{case}");
    }
    // The string form above 2^53 is really above 2^53 (the point of the case).
    let big = &cases(&d).iter().find(|c| c["name"] == "mono-ns-as-decimal-string-above-2-pow-53").unwrap()["steps"][0]["payload"]["mono_ns"];
    assert!(big.as_str().unwrap().parse::<u64>().unwrap() > 1u64 << 53);
}

// ---- 3. hook requests -------------------------------------------------------------------------

#[test]
fn p2_parity_fixture_hook_requests_match_the_built_hooks() {
    let d = doc();
    let h = &d["hook_requests"];
    assert_eq!(h["mono_ns_form"], "decimal-string");
    let fields: Vec<&str> = h["order_fields"].as_array().unwrap().iter().map(|v| v.as_str().unwrap()).collect();
    assert_eq!(fields, ["boot_id", "mono_ns"]);
    let boot = termlink_session::input_meter::boot_id().expect("this host has a boot id");
    for e in h["events"].as_array().unwrap() {
        let hook = e["hook"].as_str().unwrap();
        let req = termlink_sidecar::hook::request(hook, "s", &json!({"session_id": "s"})).unwrap();
        assert_eq!(req["op"], e["op"], "{hook}");
        assert_eq!(req["boot_id"], boot.as_str(), "{hook}");
        assert!(req["mono_ns"].as_str().is_some_and(|s| s.parse::<u64>().is_ok()), "{hook}: {req}");
        assert!(adapter_ord(req.as_object().unwrap()).is_some(), "{hook}: the meter reads the order");
    }
}

/// The hook's retry, driven by the fixture's `old_sidecar_answer`: the first
/// request carries the order fields, the second drops exactly `retry_drops`.
#[test]
fn p2_parity_fixture_old_sidecar_retry_matches_the_hook() {
    use std::io::{BufRead, BufReader, Write};
    use std::sync::Mutex;
    let d = doc();
    let answer = d["hook_requests"]["old_sidecar_answer"].clone();
    let drops: Vec<String> = d["hook_requests"]["retry_drops"].as_array().unwrap().iter().map(|v| v.as_str().unwrap().to_string()).collect();
    let e = termlink_sidecar::testkit::Estate::create_without_hub().unwrap();
    let sock = e.runtime_dir().join("p2-parity-old.sock");
    let lis = std::os::unix::net::UnixListener::bind(&sock).unwrap();
    lis.set_nonblocking(true).unwrap();
    let seen = Arc::new(Mutex::new(Vec::<Value>::new()));
    let seen2 = seen.clone();
    let srv = std::thread::spawn(move || {
        let end = std::time::Instant::now() + std::time::Duration::from_secs(5);
        for _ in 0..2 {
            let s = loop {
                match lis.accept() {
                    Ok((s, _)) => break s,
                    Err(_) if std::time::Instant::now() < end => std::thread::sleep(std::time::Duration::from_millis(10)),
                    Err(_) => return,
                }
            };
            s.set_nonblocking(false).unwrap();
            let mut line = String::new();
            BufReader::new(&s).read_line(&mut line).unwrap();
            let v: Value = serde_json::from_str(&line).unwrap();
            let ans = if v.get("mono_ns").is_some() { answer.clone() } else { json!({"ok": true, "ready": true}) };
            seen2.lock().unwrap().push(v);
            writeln!(&s, "{ans}").unwrap();
        }
    });
    let out = termlink_sidecar::hook::run("stop", &json!({"session_id": "s"}).to_string(), Some(&sock), Some(&e.runtime_dir().join("p2-parity-hook.log")));
    srv.join().unwrap();
    assert_eq!(out.error, None, "{out:?}");
    let seen = seen.lock().unwrap();
    assert_eq!(seen.len(), 2, "{seen:?}");
    let mut first = seen[0].clone();
    for f in &drops {
        assert!(first.get(f).is_some(), "first request carries {f}");
        first.as_object_mut().unwrap().remove(f);
    }
    assert_eq!(seen[1], first, "the retry is the same request without {drops:?}");
}
