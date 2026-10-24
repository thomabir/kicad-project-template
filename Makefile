# File names can contain spaces: recipes quote PRO and PCB; prerequisite lists use the *_DEP forms with escaped spaces.
PRO := $(shell ls pcb/kicad/*.kicad_pro | head -n 1)
PCB := $(PRO:.kicad_pro=.kicad_pcb)
PCB_DEP := $(subst $() ,\ ,$(PCB))
KICAD_DEP := $(shell find pcb/kicad -maxdepth 1 -type f \( -name '*.kicad_sch' -o -name '*.kicad_pcb' -o -name '*.kicad_pro' -o -name '*.kicad_dru' \) | sed 's/ /\\ /g')
BOARDS ?= 2
HWKIT ?= uv run hwkit
KICAD_CLI ?= /Applications/KiCad/KiCad.app/Contents/MacOS/kicad-cli
PRICES := pcb/bom/prices.csv
README_ARGS := README.md --project "$(PRO)" --prices $(PRICES) --boards $(BOARDS) --work pcb/build/readme

# Stamp files: a step runs again only if one of its inputs is newer. uv.lock stands for the hwkit version.
# BOARDS_STAMP holds the value of BOARDS. Make writes it only when the value changes.
BOARDS_STAMP := pcb/build/boards.txt
$(shell mkdir -p pcb/build && [ "$$(cat $(BOARDS_STAMP) 2>/dev/null)" = "$(BOARDS)" ] || echo "$(BOARDS)" > $(BOARDS_STAMP))
OUTPUTS := pcb/build/outputs.stamp
README_STAMP := pcb/build/readme.stamp
CHECK := pcb/build/check.stamp
CASE := case/print/manifest.json
PCB_STEP := case/assembly/pcb-assembly.step
PCB_GLB := case/assembly/pcb-assembly.glb
FIT := case/build/fit.stamp
RENDER := render/render-exploded.png
VERIFY := case/build/verify.stamp
HAS_CASE := $(wildcard case/cad/case.py)

.PHONY: help new-project list-fab-rules copy-fab-rules import-part show-distributor-fields write-distributor-fields fetch-prices fetch-stock upload-partsbox-project export-pcb update-readme check-pcb check-release build-case export-pcb-3d check-case-fit render-case slice-case build-case-all all clean

help:
	@echo "Usage: make <target> [BOARDS=n]"
	@echo ""
	@echo "BOARDS=$(BOARDS)  number of boards: quantities in the order files, price in the README."
	@echo "          Only the targets marked [BOARDS] use it."
	@echo ""
	@echo "1. New project (once)"
	@echo "   new-project ID=PRJ-0123 TITLE='Name'  rename the KiCad files, set the title blocks and the README title"
	@echo "   list-fab-rules                        list the PCB process rules"
	@echo "   copy-fab-rules PROCESS=name           copy one process rule set into the project"
	@echo ""
	@echo "2. Parts"
	@echo "   import-part LCSC=C25804               import symbol, footprint and 3D model of an LCSC part"
	@echo "   show-distributor-fields               show DigiKey, Mouser and datasheet fields from the APIs (dry run)"
	@echo "   write-distributor-fields              write these fields into the schematic"
	@echo "   fetch-prices                          write pcb/bom/prices.csv from the distributor APIs"
	@echo "   fetch-stock               [BOARDS]    write stock.csv and order-digikey-against-stock.csv from PartsBox"
	@echo "   upload-partsbox-project               write the BOM into a PartsBox project"
	@echo ""
	@echo "3. PCB"
	@echo "   export-pcb                [BOARDS]    write PDFs, renders, Gerbers, BOM, order files, README blocks"
	@echo "   update-readme             [BOARDS]    write the README blocks only"
	@echo "   check-pcb                 [BOARDS]    run ERC, DRC and project checks; check that outputs and README are up to date"
	@echo "   check-release             [BOARDS]    check-pcb, and no TODO in the README"
	@echo ""
	@echo "4. Case (case/cad/case.py)"
	@echo "   build-case                            write the print files, assembly files and Bambu project"
	@echo "   export-pcb-3d                         write the PCB STEP and GLB files"
	@echo "   check-case-fit                        check the case against the PCB STEP for interference"
	@echo "   render-case                           render the exploded views"
	@echo "   slice-case                            slice the Bambu project and check the G-code"
	@echo "   build-case-all                        all steps of group 4"
	@echo ""
	@echo "5. All"
	@echo "   all                       [BOARDS]    export-pcb, check-pcb, and build-case-all if the project has a case"
	@echo "   clean                                 delete the build folders (the next make runs all steps)"

new-project:
	$(if $(ID),,$(error Set ID, for example ID=PRJ-0123))
	$(if $(TITLE),,$(error Set TITLE, for example TITLE='Name'))
	$(HWKIT) kicad init "$(PRO)" --id "$(ID)" --title "$(TITLE)" --readme README.md

list-fab-rules:
	$(HWKIT) kicad fab-rules "$(PRO)"

copy-fab-rules:
	$(if $(PROCESS),,$(error Set PROCESS; make list-fab-rules shows the names))
	$(HWKIT) kicad fab-rules "$(PRO)" $(PROCESS)

import-part:
	$(if $(LCSC),,$(error Set LCSC, for example LCSC=C25804))
	$(HWKIT) kicad import-part "$(PRO)" $(LCSC)

show-distributor-fields:
	$(HWKIT) kicad fill-distributors "$(PRO)"

write-distributor-fields:
	$(HWKIT) kicad fill-distributors "$(PRO)" --write

fetch-prices:
	$(HWKIT) kicad prices "$(PRO)" --out $(PRICES) --work pcb/build/prices

fetch-stock:
	$(HWKIT) partsbox stock "$(PRO)" --boards $(BOARDS) --work pcb/build/partsbox --out pcb/bom

upload-partsbox-project:
	$(HWKIT) partsbox project "$(PRO)" --work pcb/build/partsbox

export-pcb: $(OUTPUTS) $(README_STAMP)

$(OUTPUTS): $(KICAD_DEP) $(BOARDS_STAMP) uv.lock
	$(HWKIT) kicad outputs "$(PRO)" --out pcb --boards $(BOARDS)
	@mkdir -p $(@D) && touch $@

update-readme: $(README_STAMP)

$(README_STAMP): $(OUTPUTS) $(wildcard $(PRICES)) $(BOARDS_STAMP) README.md
	$(HWKIT) readme update $(README_ARGS)
	@mkdir -p $(@D) && touch $@

check-pcb: $(CHECK)

$(CHECK): $(KICAD_DEP) $(OUTPUTS) $(README_STAMP) $(BOARDS_STAMP) uv.lock
	$(HWKIT) kicad check "$(PRO)" --work pcb/build/check --outputs pcb --boards $(BOARDS)
	$(HWKIT) readme check $(README_ARGS)
	@touch $@

check-release:
	$(HWKIT) kicad check "$(PRO)" --work pcb/build/check --outputs pcb --boards $(BOARDS)
	$(HWKIT) readme check $(README_ARGS) --release

build-case: $(CASE)

$(CASE): $(wildcard case/cad/*.py case/cad/*.config) uv.lock
	uv run python case/cad/case.py

export-pcb-3d: $(PCB_STEP) $(PCB_GLB)

$(PCB_STEP): $(PCB_DEP)
	$(KICAD_CLI) pcb export step --subst-models --force -o $@ "$(PCB)"

$(PCB_GLB): $(PCB_DEP)
	$(KICAD_CLI) pcb export glb --subst-models --force -o $@ "$(PCB)"

check-case-fit: $(FIT)

$(FIT): $(CASE) $(PCB_STEP)
	uv run python case/cad/check_fit.py
	@mkdir -p $(@D) && touch $@

render-case: $(RENDER)

$(RENDER): $(CASE) $(PCB_GLB) $(wildcard render/*.py)
	uv run python render/render.py

slice-case: $(VERIFY)

$(VERIFY): $(CASE)
	$(HWKIT) bambu verify case/print/print-case.3mf --labels case/print/print-lid-labels.stl --body case/print/print-lid.stl --out case/build/verify
	@touch $@

build-case-all: build-case export-pcb-3d check-case-fit render-case slice-case

all: export-pcb check-pcb
ifneq ($(HAS_CASE),)
all: build-case-all
endif

clean:
	rm -rf pcb/build case/build
