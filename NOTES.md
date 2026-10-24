# Notes

Design notes for the template and the workflow. Maximum 5000 characters: compress when this file gets larger.

## Principles

- The human does deep thinking and the fun work. The LLM is copilot, toolsmith and librarian.
- Everything works without an LLM: `make` runs every deterministic step.
- Code (`hwkit`, Makefile) does deterministic work. LLM tokens are for heuristic decisions.
- Each decision has one source of truth, user first: the schematic, the board, the simulation code, the LTspice file, the render script. No side files for decisions. The agent edits the same files as the user.
- The user decides project number and version. The agent asks.
- Generate only what a human reads and cannot see elsewhere. No file lists: the hierarchy explains itself.
- If a tool behaves unexpectedly, fix it or make a new tool. Do not record workarounds.
- Pin external helper code (`hwkit` in `uv.lock`): old projects build the same outputs again.
- PCB process rule files (`.kicad_dru`, example: PCBWay 2-layer standard) are in a library in `hwkit`.
- Code checks only rules that are always valid. Best practice that a user can decide against (ground pour, mounting holes) is a recommendation in the skill.

## Folder structure

Group by subsystem first, then by role. In each subsystem, one folder is source, the other folders are generated outputs that are committed, and `build/` is gitignored and deletable.

```
PRJ-0123-name/
  README.md, DESIGN.md, AGENTS.md
  Makefile, pyproject.toml, uv.lock
  pcb/
    kicad/         source: .kicad_pro/sch/pcb/dru, lib/ (imported parts)
    manifest.json  source hashes of the outputs
    docs/          schematic and board PDFs, top and bottom renders
    manufacturing/ Gerber archive, drill, positions
    bom/           BOM, interactive BOM, prices, order files
    build/         ERC/DRC reports, temporary exports
  case/
    cad/           source files
    print/         STL, 3MF
    build/
  render/          render script (camera in code) and its images
  experiments/
    001_.../       self-contained: code, data, plots
  docs/            human-made: sketches, photos, diagrams
```

## Knowledge

- `lessons.md` (agent toolkit): general design principles. Example: "Check devices with polarity against the datasheet, the symbol and the footprint." No tool workarounds, no project items. Maximum 100 entries, counted by a check: at the limit, an agent compresses (merges, abstracts, moves to `lessons-archive.md`, which has no limit).
- `DESIGN.md` (per project, human first): decisions and their reasons, bulleted. The human makes the larger edits.
- `AGENTS.md` (per project, agent only): short bulleted list. `CLAUDE.md` refers to it.

## Parts

- The KiCad files are the single source of truth for the BOM. Use symbol fields for extra data. All else follows from them deterministically.
- Each component has: datasheet, manufacturer, MPN, DigiKey link and part number, Mouser link and part number, notes (shown on the BOM).
- Generic passives: prefer PartsBox stock if in the same price class with the same or strictly better specifications.
- PartsBox project upload and inventory crosscheck: by script through the PartsBox API. Notify the user if stock is low.
- Symbol, footprint and 3D model: `make import-part LCSC=...` (easyeda2kicad, no login) into `pcb/kicad/lib/`. The agent finds the LCSC number.
- Prices: DigiKey API, Mouser as fallback. A dated price cache (private, not tracked) keeps the README build offline.

## Outputs

- README: hand-written sections, plus generated blocks between markers (BOM, price, part count, board size, title block). The check fails if a block is not up to date.
- README sections stay. Each holds content, `TODO` or `N/A: <reason>`. Check: missing = issue, `TODO` = note (issue at release).
- The README BOM is never edited manually. The symbol field Notes appears in it.
- DigiKey and Mouser order files: the number of boards is an argument (default 2 for prototypes).
- Renders: with a case, exploded views from more sides.
- A manifest of source hashes shows if outputs are not up to date, and prevents expensive builds when nothing changed.

## Project identifier

- Projects have an identifier such as "PRJ-0046" or "PRT-0121". Ask user if not obvious one present.
- KiCad has no DWG-No field: the identifier is in front of the title, checked by `make check-pcb`. Example: "PRJ-0123 Quad Cell Photoamplifier".

## LLM tasks where heuristics are required

- Is a part in stock a good substitute for a board part?
- Which DigiKey packaging (cut tape, Digi-Reel, full reel)?
- Library import, part search.
- Design review against the intent.
- Sanity checks, reviews, repository consistency beyond the checks.

## Commits

- Before each clean commit: outputs, README and docs up to date. Push the agent toolkit after each clean commit.

## Later

- CI and portability: `lab/profile.toml` has macOS paths.
- PDF/PNG/Gerber time stamps give binary diffs after each export.
