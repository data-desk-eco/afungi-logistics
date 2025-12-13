# Data Desk Research Notebooks

Data Desk publishes investigative research as interactive notebooks using Observable Notebook Kit 2.0. Notebooks are standalone HTML pages with embedded JavaScript that compile to static sites.

## File structure

```
repo/
├── docs/
│   ├── index.html           # Notebook source (EDIT THIS)
│   ├── assets/              # Images
│   └── .observable/dist/    # Built output (gitignored)
├── data/                    # DuckDB, CSV, JSON files
├── template.html            # HTML wrapper (auto-updates from .github repo)
├── Makefile
└── CLAUDE.md                # This file (auto-updates)
```

**Commit:** `docs/index.html`, `data/*`, `docs/assets/*`, `Makefile`
**Don't commit:** `docs/.observable/dist/`, `node_modules/`, `template.html`, `CLAUDE.md`, `.claude/`

## Style guide

- Use **sentence case** for all titles, headings, and chart titles (e.g., "Outages by country" not "Outages By Country")

## Critical gotchas

1. **Data paths:** Use `../data/` from notebook, not `data/`
2. **SQL database path:** `database="../data/data.duckdb"` in SQL cells
3. **Display everything:** Use `display()` explicitly, don't rely on return values
4. **Cell IDs:** Must be unique across notebook
5. **Await FileAttachment:** All FileAttachment calls return promises
6. **Edit source:** Edit `docs/index.html`, not `docs/.observable/dist/`
7. **Auto-updating files:** `template.html`, `CLAUDE.md`, and `.claude/` download from `.github` repo on deploy
8. **Case-sensitive paths:** GitHub Pages is case-sensitive
9. **SQL cells at build time:** Database must exist when running `make build`

## Resources

- Observable Notebook Kit: https://observablehq.com/notebook-kit/
- Observable Plot: https://observablehq.com/plot/
- Observable Inputs: https://observablehq.com/notebook-kit/inputs
- DuckDB SQL: https://duckdb.org/docs/sql/introduction
- All Data Desk notebooks: https://research.datadesk.eco/
