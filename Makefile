PRO := $(firstword $(wildcard pcb/kicad/*.kicad_pro))
BOARDS ?= 2
HWKIT ?= uv run hwkit
PRICES := pcb/bom/prices.csv
README_ARGS := README.md --project $(PRO) --prices $(PRICES) --boards $(BOARDS) --work pcb/build/readme

.PHONY: help init fab-rules part distributors distributors-write prices outputs readme check release-check stock partsbox-project all clean

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
	@echo "all                            outputs, then check"
	@echo "clean                          delete the build folders"
	@echo "BOARDS=$(BOARDS) (number of boards for order files and prices)"

init:
	$(HWKIT) kicad init $(PRO) --id "$(ID)" --title "$(TITLE)" --readme README.md

fab-rules:
	$(HWKIT) kicad fab-rules $(PRO) $(PROCESS)

part:
	$(HWKIT) kicad import-part $(PRO) $(LCSC)

distributors:
	$(HWKIT) kicad fill-distributors $(PRO)

distributors-write:
	$(HWKIT) kicad fill-distributors $(PRO) --write

prices:
	$(HWKIT) kicad prices $(PRO) --out $(PRICES) --work pcb/build/prices

outputs:
	$(HWKIT) kicad outputs $(PRO) --out pcb --boards $(BOARDS)
	$(HWKIT) readme update $(README_ARGS)

readme:
	$(HWKIT) readme update $(README_ARGS)

check:
	$(HWKIT) kicad check $(PRO) --work pcb/build/check --outputs pcb --boards $(BOARDS)
	$(HWKIT) readme check $(README_ARGS)

release-check:
	$(HWKIT) kicad check $(PRO) --work pcb/build/check --outputs pcb --boards $(BOARDS)
	$(HWKIT) readme check $(README_ARGS) --release

stock:
	$(HWKIT) partsbox stock $(PRO) --boards $(BOARDS) --work pcb/build/partsbox --out pcb/bom

partsbox-project:
	$(HWKIT) partsbox project $(PRO) --work pcb/build/partsbox

all: outputs check

clean:
	rm -rf pcb/build case/build
