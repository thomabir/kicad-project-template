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

.PHONY: help init fab-rules part distributors distributors-write prices outputs readme check release-check stock partsbox-project case pcb-3d fit render verify case-all all clean

help:
	@echo "init ID=PRJ-0123 TITLE='Name'  rename the KiCad files, set title blocks and README title"
	@echo "fab-rules [PROCESS=...]        copy process rules into the project; without PROCESS: list them"
	@echo "part LCSC=C25804               import symbol, footprint and 3D model of an LCSC part"
	@echo "distributors                   dry run: DigiKey, Mouser and datasheet fields from the APIs"
	@echo "distributors-write             write these fields into the schematic"
	@echo "prices                         price cache from the distributor APIs"
	@echo "outputs                        PDFs, renders, Gerbers, BOM, order files, README blocks"
	@echo "readme                         README generated blocks only"
	@echo "check                          KiCad checks, ERC, DRC, outputs and README up to date"
	@echo "release-check                  check, and no TODO in the README"
	@echo "stock                          PartsBox stock of the BOM parts; stock.csv, DigiKey order file against stock"
	@echo "partsbox-project               PartsBox project with the BOM"
	@echo "case                           case model (case/cad/case.py): print files, assembly files, Bambu project"
	@echo "pcb-3d                         PCB STEP and GLB exports for the fit check and the render"
	@echo "fit                            interference check of the case against the PCB STEP"
	@echo "render                         exploded views of the case and the PCB (render/render.py)"
	@echo "verify                         slice the Bambu project and check the G-code"
	@echo "case-all                       case, pcb-3d, fit, render, verify"
	@echo "all                            outputs, check, and case-all if case/cad/case.py exists"
	@echo "clean                          delete the build folders (the next make runs all steps)"
	@echo "BOARDS=$(BOARDS) (number of boards for order files and prices)"

init:
	$(HWKIT) kicad init "$(PRO)" --id "$(ID)" --title "$(TITLE)" --readme README.md

fab-rules:
	$(HWKIT) kicad fab-rules "$(PRO)" $(PROCESS)

part:
	$(HWKIT) kicad import-part "$(PRO)" $(LCSC)

distributors:
	$(HWKIT) kicad fill-distributors "$(PRO)"

distributors-write:
	$(HWKIT) kicad fill-distributors "$(PRO)" --write

prices:
	$(HWKIT) kicad prices "$(PRO)" --out $(PRICES) --work pcb/build/prices

outputs: $(OUTPUTS) $(README_STAMP)

$(OUTPUTS): $(KICAD_DEP) uv.lock
	$(HWKIT) kicad outputs "$(PRO)" --out pcb --boards $(BOARDS)
	@mkdir -p $(@D) && touch $@

readme: $(README_STAMP)

$(README_STAMP): $(OUTPUTS) $(wildcard $(PRICES)) README.md
	$(HWKIT) readme update $(README_ARGS)
	@mkdir -p $(@D) && touch $@

check: $(CHECK)

$(CHECK): $(KICAD_DEP) $(OUTPUTS) $(README_STAMP) uv.lock
	$(HWKIT) kicad check "$(PRO)" --work pcb/build/check --outputs pcb --boards $(BOARDS)
	$(HWKIT) readme check $(README_ARGS)
	@touch $@

release-check:
	$(HWKIT) kicad check "$(PRO)" --work pcb/build/check --outputs pcb --boards $(BOARDS)
	$(HWKIT) readme check $(README_ARGS) --release

stock:
	$(HWKIT) partsbox stock "$(PRO)" --boards $(BOARDS) --work pcb/build/partsbox --out pcb/bom

partsbox-project:
	$(HWKIT) partsbox project "$(PRO)" --work pcb/build/partsbox

case: $(CASE)

$(CASE): $(wildcard case/cad/*.py case/cad/*.config) uv.lock
	uv run python case/cad/case.py

pcb-3d: $(PCB_STEP) $(PCB_GLB)

$(PCB_STEP): $(PCB_DEP)
	$(KICAD_CLI) pcb export step --subst-models --force -o $@ "$(PCB)"

$(PCB_GLB): $(PCB_DEP)
	$(KICAD_CLI) pcb export glb --subst-models --force -o $@ "$(PCB)"

fit: $(FIT)

$(FIT): $(CASE) $(PCB_STEP)
	uv run python case/cad/check_fit.py
	@mkdir -p $(@D) && touch $@

render: $(RENDER)

$(RENDER): $(CASE) $(PCB_GLB) $(wildcard render/*.py)
	uv run python render/render.py

verify: $(VERIFY)

$(VERIFY): $(CASE)
	$(HWKIT) bambu verify case/print/print-case.3mf --labels case/print/print-lid-labels.stl --body case/print/print-lid.stl --out case/build/verify
	@touch $@

case-all: case pcb-3d fit render verify

all: outputs check
ifneq ($(HAS_CASE),)
all: case-all
endif

clean:
	rm -rf pcb/build case/build
