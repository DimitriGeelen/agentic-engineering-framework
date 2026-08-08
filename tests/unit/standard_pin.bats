#!/usr/bin/env bats
# T-2869 — the vendored AEF↔BPMN standard must stay byte-identical to its pin.
#
# AEF is a ratifying party for this standard. Until 2026-08-08 we held no copy and
# had been citing clauses quoted out of 832's rail messages rather than read from
# the document (OBS-190). The copy under policy/standards/ closes that — but a
# vendored copy is only worth holding while it still hashes to the pin it was
# verified against. A "small fix" to the text, a lint pass that strips trailing
# whitespace, or an editor adding a final newline would silently turn an
# authoritative document into our local paraphrase of one — which is the exact
# failure OBS-190 named, re-created in a place that looks more trustworthy.
#
# The pin is not ours to choose: 832 published it at rail offset 446 and
# re-derived it from their working tree before sending the bytes at 454.
#
# If this test goes red, the correct response is NOT to update PIN_SHA256 to
# whatever the file now hashes to. Either the file was edited (revert it) or 832
# cut a new version (re-vendor from a new pin and update the provenance sidecar).

load ../test_helper

STANDARD="$FRAMEWORK_ROOT/policy/standards/aef-bpmn-mapping-v1-partI.md"
PROVENANCE="$FRAMEWORK_ROOT/policy/standards/aef-bpmn-mapping-v1-partI.provenance.yaml"
PIN_SHA256="970dd530258b1cde1682a3ad9068808efbf3bb9a664b181499d8ee8328b9106f"
PIN_BYTES=7905

@test "T-2869: the vendored standard is present" {
    [ -f "$STANDARD" ]
}

@test "T-2869: it hashes to the pin 832 published and re-derived" {
    run sha256sum "$STANDARD"
    [ "$status" -eq 0 ]
    [[ "$output" == "$PIN_SHA256"* ]]
}

@test "T-2869: byte count matches the pin (catches trailing-byte drift specifically)" {
    # The transfer artefact that actually bit was a single appended newline, which
    # a casual eyeball would never catch. Size is the cheap, independent check.
    run stat -c %s "$STANDARD"
    [ "$output" = "$PIN_BYTES" ]
}

@test "T-2869: the provenance sidecar exists and records the same pin" {
    [ -f "$PROVENANCE" ]
    grep -q "$PIN_SHA256" "$PROVENANCE"
    # Provenance must name the source commit — a hash with no origin is not
    # provenance, it is a checksum.
    grep -q "4a1a30e115faae79d0e8fa95a05858903e0ac550" "$PROVENANCE"
}

@test "T-2869: ANTI-VACUITY — a one-byte change is detected" {
    # Proves the check can fail. Without this, green says only that nobody has
    # edited the file yet.
    local mutant="$BATS_TEST_TMPDIR/mutant.md"
    cp "$STANDARD" "$mutant"
    printf '\n' >> "$mutant"          # exactly the artefact the transfer produced
    run sha256sum "$mutant"
    [[ "$output" != "$PIN_SHA256"* ]]
    run stat -c %s "$mutant"
    [ "$output" != "$PIN_BYTES" ]
}
