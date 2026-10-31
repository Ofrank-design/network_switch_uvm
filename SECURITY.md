# Security Policy

## Reporting a vulnerability

Please report security problems privately. Do not open a public issue.

- Preferred: open a private advisory on GitHub
  (Security tab, then "Report a vulnerability").
- Alternative: email **Frank Oduro** at frankoduro1912@gmail.com with the
  subject line `SECURITY network_switch_uvm`.

A useful report names the affected file or script, the steps to reproduce, and
what an attacker gains. Logs and a minimal proof of concept help.

You can expect an acknowledgement within 5 working days and a first assessment
within 14 days. Fixes for confirmed issues are released as soon as they are
tested, and the reporter is credited in the changelog unless they ask not to be.

## What is in scope

This repository is a verification environment. The code that can realistically
hurt a user is the tooling around the hardware, so the scope covers:

- Shell and Python scripts in `scripts/`, for example command injection through
  arguments, environment variables, file names or log content.
- The CI workflows in `.github/workflows/`, for example token exposure, unsafe
  use of untrusted input, or unpinned actions that allow a supply chain attack.
- The dependency fetch in `scripts/fetch_uvm.sh`, which downloads third party
  source and must stay pinned to a known commit.
- Any secret, credential or personal data committed to the repository.

## What is out of scope

- The example switch RTL in `rtl/`. It is a verification target, not a hardened
  or production design. It has no authentication, encryption or isolation
  features, and nothing should be built on the assumption that it does.
- Bugs in third party tools (Verilator, Z3, UVM, commercial simulators). Please
  report those to their own projects.
- Findings that need an attacker who already controls the machine running the
  simulation.

## Supported versions

Security fixes go to the latest release on the `main` branch only.

## Hardening already in place

- GitHub Actions workflows run with read only token permissions by default and
  take no secrets.
- Workflows never run code from pull requests with elevated permissions.
- The UVM dependency is pinned to a full commit hash, not a moving branch.
- Scripts run with `set -euo pipefail`, quote their variables and do not
  evaluate input as code.
- `.gitignore` blocks common secret files (`.env`, `*.pem`, `*.key`).
- Dependabot keeps the workflow actions current.

## Handling secrets

No secrets are needed to build or run this project. If you find one in the
history, report it using the process above so it can be rotated and removed.
