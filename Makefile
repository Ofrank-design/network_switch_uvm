# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Oduro <frankoduro1912@gmail.com>

SIM   ?= verilator
SEEDS ?= 3
TEST  ?= router_smoke_test

export UVM_HOME ?= $(CURDIR)/third_party/uvm-core/src

.PHONY: help setup lint build smoke test regress faults clean

help:
	@echo "make setup     fetch the pinned UVM source (open source flow)"
	@echo "make lint      lint the RTL for 1, 2, 4 and 8 ports"
	@echo "make build     compile the testbench"
	@echo "make smoke     run the smoke test"
	@echo "make test      run one test, TEST=router_rand_test SEED=5"
	@echo "make regress   all tests over SEEDS seeds, merged coverage"
	@echo "make faults    check that every injected bug is caught"
	@echo "make clean     remove build and log output"

setup:
	scripts/fetch_uvm.sh

lint:
	scripts/lint.sh

build:
	scripts/run_sim.sh -s $(SIM) -b

smoke:
	scripts/run_sim.sh -s $(SIM) -t router_smoke_test

test:
	scripts/run_sim.sh -s $(SIM) -t $(TEST) -n $(or $(SEED),1)

regress:
	scripts/regress.sh -s $(SIM) -n $(SEEDS)

faults:
	scripts/fault_campaign.sh -s $(SIM)

clean:
	rm -rf build logs
