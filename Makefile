# Project template: https://github.com/thomabir/kicad-project-template (~/code/kicad-project-template)
# File names can contain spaces: recipes quote PRO and PCB; prerequisite lists use the *_DEP forms with escaped spaces.
PRO := $(shell ls pcb/kicad/*.kicad_pro | head -n 1)
PCB := $(PRO:.kicad_pro=.kicad_pcb)
PCB_DEP := $(subst $() ,\ ,$(PCB))
KICAD_DEP := $(shell find pcb/kicad -maxdepth 1 -type f \( -name '*.kicad_sch' -o -name '*.kicad_pcb' -o -name '*.kicad_pro' -o -name '*.kicad_dru' \) | sed 's/ /\\ /g')
BOARDS ?= $(shell sed -n 's/^boards *= *\([0-9]*\).*/\1/p' pyproject.toml)
ifeq ($(BOARDS),)
BOARDS := 2
endif
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

# Terminal colors (disabled when stdout is not a terminal or NO_COLOR is set)
ifneq ($(if $(NO_COLOR),,$(shell [ -t 1 ] && echo 1)),)
  B := \033[1m
  C := \033[1;36m
  Y := \033[33m
  D := \033[2m
  R := \033[0m
endif

.PHONY: help all pcb case check release readme clean part parts-fill prices stock partsbox case-cad case-fit case-render case-slice pcb-3d init rules

help:
	@printf "$(B)Usage:$(R) make <target>\n\n"
	@printf "$(B)Workflow$(R)\n"
	@printf "  $(C)%-12s$(R) %-16s %s\n" "all" "" "Build & check everything (PCB + Case)"
	@printf "  $(C)%-12s$(R) %-16s %s\n" "pcb" "" "Export PCB files (PDFs, Gerbers, BOM, README)"
	@printf "  $(C)%-12s$(R) %-16s %s\n" "case" "" "Build case, check fit, render & slice"
	@printf "  $(C)%-12s$(R) %-16s %s\n" "check" "" "Run all PCB, README & case checks"
	@printf "  $(C)%-12s$(R) %-16s %s\n" "release" "" "Check everything + ensure no TODOs in README"
	@printf "  $(C)%-12s$(R) %-16s %s\n" "readme" "" "Update generated blocks in README.md"
	@printf "  $(C)%-12s$(R) %-16s %s\n\n" "clean" "" "Clear build cache (forces full rebuild next run)"
	@printf "$(B)Parts & BOM$(R)\n"
	@printf "  $(C)%-12s$(R) $(Y)%-16s$(R) %s\n" "part" "LCSC=C1234" "Download symbol, footprint & 3D model from LCSC"
	@printf "  $(C)%-12s$(R) $(D)%-16s$(R) %s\n" "parts-fill" "[WRITE=1]" "Fetch DigiKey/Mouser/datasheet fields (dry-run by default)"
	@printf "  $(C)%-12s$(R) %-16s %s\n" "prices" "" "Update pcb/bom/prices.csv from distributor APIs"
	@printf "  $(C)%-12s$(R) %-16s %s\n" "stock" "" "Check PartsBox stock & generate DigiKey order CSV"
	@printf "  $(C)%-12s$(R) %-16s %s\n\n" "partsbox" "" "Upload BOM to PartsBox project"
	@printf "$(B)Case (individual steps)$(R)\n"
	@printf "  $(C)%-12s$(R) %-16s %s\n" "case-cad" "" "Generate STLs, STEP & Bambu 3MF from case.py"
	@printf "  $(C)%-12s$(R) %-16s %s\n" "case-fit" "" "Check 3D clearance between case and PCB"
	@printf "  $(C)%-12s$(R) %-16s %s\n" "case-render" "" "Render exploded assembly views"
	@printf "  $(C)%-12s$(R) %-16s %s\n\n" "case-slice" "" "Slice 3MF in Bambu Studio & verify G-code"
	@printf "$(B)Setup (once per project)$(R)\n"
	@printf "  $(C)%-12s$(R) $(Y)%-16s$(R) %s\n" "init" "ID=.. TITLE=.." "Rename project files and set title blocks"
	@printf "  $(C)%-12s$(R) $(D)%-16s$(R) %s\n\n" "rules" "[PROCESS=name]" "List fab rules, or apply one if PROCESS is set"
	@printf "$(D)Config: boards = $(BOARDS) (set in pyproject.toml, or override with BOARDS=n)$(R)\n"

init:
	$(if $(ID),,$(error Set ID, for example ID=PRJ-0123))
	$(if $(TITLE),,$(error Set TITLE, for example TITLE='Name'))
	$(HWKIT) kicad init "$(PRO)" --id "$(ID)" --title "$(TITLE)" --readme README.md

rules:
	$(HWKIT) kicad fab-rules "$(PRO)" $(PROCESS)

part:
	$(if $(LCSC),,$(error Set LCSC, for example LCSC=C25804))
	$(HWKIT) kicad import-part "$(PRO)" $(LCSC)

parts-fill:
	$(HWKIT) kicad fill-distributors "$(PRO)" $(if $(WRITE),--write)

prices:
	$(HWKIT) kicad prices "$(PRO)" --out $(PRICES) --work pcb/build/prices

stock:
	$(HWKIT) partsbox stock "$(PRO)" --boards $(BOARDS) --work pcb/build/partsbox --out pcb/bom

partsbox:
	$(HWKIT) partsbox project "$(PRO)" --work pcb/build/partsbox

pcb: $(OUTPUTS) $(README_STAMP)
ifneq ($(HAS_CASE),)
pcb: pcb-3d
endif

$(OUTPUTS): $(KICAD_DEP) $(BOARDS_STAMP) uv.lock
	$(HWKIT) kicad outputs "$(PRO)" --out pcb --boards $(BOARDS)
	@mkdir -p $(@D) && touch $@

readme: $(README_STAMP)

$(README_STAMP): $(OUTPUTS) $(wildcard $(PRICES)) $(BOARDS_STAMP) README.md
	$(HWKIT) readme update $(README_ARGS)
	@mkdir -p $(@D) && touch $@

check: $(CHECK)
ifneq ($(HAS_CASE),)
check: case-fit case-slice
endif

$(CHECK): $(KICAD_DEP) $(OUTPUTS) $(README_STAMP) $(BOARDS_STAMP) uv.lock
	$(HWKIT) kicad check "$(PRO)" --work pcb/build/check --outputs pcb --boards $(BOARDS)
	$(HWKIT) readme check $(README_ARGS)
	@touch $@

release:
	$(HWKIT) kicad check "$(PRO)" --work pcb/build/check --outputs pcb --boards $(BOARDS)
	$(HWKIT) readme check $(README_ARGS) --release
ifneq ($(HAS_CASE),)
	@$(MAKE) case-fit case-slice
endif

case-cad: $(CASE)

$(CASE): $(wildcard case/cad/*.py case/cad/*.config) uv.lock
	uv run python case/cad/case.py

pcb-3d: $(PCB_STEP) $(PCB_GLB)

$(PCB_STEP): $(PCB_DEP)
	@mkdir -p $(@D)
	$(KICAD_CLI) pcb export step --subst-models --force -o $@ "$(PCB)"

$(PCB_GLB): $(PCB_DEP)
	@mkdir -p $(@D)
	$(KICAD_CLI) pcb export glb --subst-models --force -o $@ "$(PCB)"

case-fit: $(FIT)

$(FIT): $(CASE) $(PCB_STEP)
	uv run python case/cad/check_fit.py
	@mkdir -p $(@D) && touch $@

case-render: $(RENDER)

$(RENDER): $(CASE) $(PCB_GLB) $(wildcard render/*.py)
	uv run python render/render.py

case-slice: $(VERIFY)

$(VERIFY): $(CASE)
	$(HWKIT) bambu verify case/print/print-case.3mf --labels case/print/print-lid-labels.stl --body case/print/print-lid.stl --out case/build/verify
	@touch $@

case: case-cad pcb-3d case-fit case-render case-slice

all: pcb check
ifneq ($(HAS_CASE),)
all: case
endif

clean:
	rm -rf pcb/build case/build
