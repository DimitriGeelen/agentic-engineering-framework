# TermLink Distribution

This directory contains templates for distributing TermLink via Homebrew.

## Files

- `github-release.yml` - GitHub Actions workflow for building macOS binaries
- `termlink.rb` - Homebrew formula template

## Setup Instructions

### 1. Mirror TermLink to GitHub

TermLink source is at OneDev. Mirror it to GitHub for public distribution:

```bash
# Clone from OneDev
git clone https://onedev.docker.ring20.geelenandcompany.com/termlink termlink-mirror
cd termlink-mirror

# Add GitHub remote
git remote add github https://github.com/DimitriGeelen/termlink.git

# Push all branches and tags
git push github --all
git push github --tags
```

### 2. Set Up GitHub Actions

```bash
# Copy workflow to termlink repo
mkdir -p termlink/.github/workflows
cp github-release.yml termlink/.github/workflows/release.yml
cd termlink
git add .github/workflows/release.yml
git commit -m "Add GitHub Actions release workflow"
git push
```

### 3. Create a Release

```bash
# Tag a version
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions will build and create the release automatically
```

### 4. Create Homebrew Tap

```bash
# Create tap repository
gh repo create homebrew-termlink --public

# Clone and add formula
git clone https://github.com/DimitriGeelen/homebrew-termlink.git
cd homebrew-termlink
mkdir -p Formula

# Copy formula and update SHA256 hashes from release checksums.txt
cp /path/to/termlink.rb Formula/termlink.rb
# Edit Formula/termlink.rb to replace REPLACE_WITH_*_SHA256 with actual values

git add Formula/termlink.rb
git commit -m "Add termlink formula"
git push
```

### 5. Install via Homebrew

```bash
# Option 1: Direct install
brew install DimitriGeelen/termlink/termlink

# Option 2: Tap then install
brew tap DimitriGeelen/termlink
brew install termlink
```

## Development Installation

For developers who want to build from source:

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Clone and build
git clone https://github.com/DimitriGeelen/termlink.git
cd termlink
cargo install --path crates/termlink-cli
```

## Verification

After installation, verify with:

```bash
termlink --version
fw termlink check
```
