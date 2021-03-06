# Run corner specific calculations

TIMFUZ_DIR=$(XRAY_DIR)/fuzzers/007-timing
CORNER=slow_max
ALLOW_ZERO_EQN?=N
BADPRJ_OK?=N

all: build/$(CORNER)/timgrid-s.json

run:
	$(MAKE) clean
	$(MAKE) all
	touch run.ok

clean:
	rm -rf specimen_[0-9][0-9][0-9]/ seg_clblx.segbits __pycache__ run.ok
	rm -rf vivado*.log vivado_*.str vivado*.jou design *.bits *.dcp *.bit
	rm -rf build

.PHONY: all run clean

build/$(CORNER):
	mkdir build/$(CORNER)

build/checksub:
	false

build/$(CORNER)/leastsq.csv: build/sub.json build/grouped.csv build/checksub build/$(CORNER)
	# Create a rough timing model that approximately fits the given paths
	python3 $(TIMFUZ_DIR)/solve_leastsq.py --sub-json build/sub.json build/grouped.csv --corner $(CORNER) --out build/$(CORNER)/leastsq.csv.tmp
	mv build/$(CORNER)/leastsq.csv.tmp build/$(CORNER)/leastsq.csv

build/$(CORNER)/linprog.csv: build/$(CORNER)/leastsq.csv build/grouped.csv
	# Tweak rough timing model, making sure all constraints are satisfied
	ALLOW_ZERO_EQN=$(ALLOW_ZERO_EQN) python3 $(TIMFUZ_DIR)/solve_linprog.py --sub-json build/sub.json --sub-csv build/$(CORNER)/leastsq.csv --massage build/grouped.csv --corner $(CORNER) --out build/$(CORNER)/linprog.csv.tmp
	mv build/$(CORNER)/linprog.csv.tmp build/$(CORNER)/linprog.csv

build/$(CORNER)/flat.csv: build/$(CORNER)/linprog.csv
	# Take separated variables and back-annotate them to the original timing variables
	python3 $(TIMFUZ_DIR)/csv_group2flat.py --sub-json build/sub.json --corner $(CORNER) --out build/$(CORNER)/flat.csv.tmp build/$(CORNER)/linprog.csv
	mv build/$(CORNER)/flat.csv.tmp build/$(CORNER)/flat.csv

build/$(CORNER)/timgrid-s.json: build/$(CORNER)/flat.csv
	# Final processing
	# Insert timing delays into actual tile layouts
	python3 $(TIMFUZ_DIR)/tile_annotate.py --timgrid-s $(TIMFUZ_DIR)/timgrid/build/timgrid-s.json --out build/$(CORNER)/timgrid-vc.json build/$(CORNER)/flat.csv

