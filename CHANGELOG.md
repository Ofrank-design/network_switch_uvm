# Changelog

All notable changes are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-10-31

### Added
- Reference RTL: four port input buffered switch with per input FIFOs, per
  output round robin arbiters and registered outputs. Parameterised for port
  count, data width and FIFO depth.
- Six built in bugs behind `FAULT_MODE` for proving the testbench can fail.
- UVM environment: packet, sequencer, driver, monitors, ready sink, input and
  output agents, scoreboard with a per route reference model, functional
  coverage, virtual sequencer and environment.
- Protocol assertions in the interface for stability, framing, routing and reset.
- Eight tests from smoke to stress, with a drain based end of test.
- Scripts for Verilator, Questa, VCS and Xcelium, a seeded regression runner,
  a fault campaign runner and a coverage merger.
- Repository files: licence, security policy, contributing guide, code of
  conduct, CI workflow, issue and pull request templates, code owners.
- Documentation: DUT contract, verification plan, coverage plan.
