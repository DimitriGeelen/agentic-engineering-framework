# T-539: TermLink Homebrew Tap Distribution

## Finding
TermLink (Rust CLI) needs a distribution channel for macOS users. Homebrew tap is the standard approach for CLI tools. Requires: GitHub Actions workflow to build universal binaries, tap formula pointing to release artifacts.

## Decision: GO — create DimitriGeelen/homebrew-termlink tap with GitHub Actions release workflow
