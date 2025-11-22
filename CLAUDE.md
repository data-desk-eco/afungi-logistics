# Data Desk Research Notebooks

Data Desk produces investigative research and analysis on the global oil and gas industry for NGOs, think tanks, and media organizations. We publish our work as interactive research notebooks using Observable Notebook Kit 2.0.

## What Are Observable Notebooks?

Observable notebooks are not traditional Jupyter notebooks. They are standalone HTML pages with embedded JavaScript that compile to static sites. Each notebook is a single `index.html` file in the `docs/` directory that uses a custom `<notebook>` element to organize content into cells.

### Basic Structure

```html
<!doctype html>
<notebook theme="midnight">
  <title>Research Title</title>

  <script id="header" type="text/markdown">
    # Main Heading
    *Date*
  </script>

  <script id="data-loading" type="module">
    const data = await FileAttachment("data/flows.csv").csv({typed: true});
    display(Inputs.table(data));
  </script>
</notebook>
```

**Key points:**
- Each `<script>` tag is a cell with a unique `id` attribute
- Use `type="text/markdown"` for markdown cells
- Use `type="module"` for JavaScript cells
- Use `type="text/html"` for raw HTML cells
- Use `type="application/sql"` for SQL cells that query DuckDB databases

### Cell Execution Model

Unlike Jupyter notebooks that run sequentially, Observable notebooks use reactive execution:
- Cells automatically re-run when their dependencies change
- Variables defined in one cell are available to all other cells
- Use `display()` to explicitly render outputs (don't rely on return values)
- All cells are `type="module"` by default, giving you ES6 module syntax

## Working with Data

### FileAttachment API

Load data files relative to the notebook:

```javascript
// CSV with automatic type inference
const flows = await FileAttachment("../data/flows.csv").csv({typed: true});

// JSON
const projects = await FileAttachment("../data/projects.json").json();

// Parquet (efficient for large datasets)
const tracks = await FileAttachment("../data/tracks.parquet").parquet();

// Images (in docs/assets/)
const img = await FileAttachment("assets/photo.jpg").url();
```

**Important:**
- All paths are relative to the notebook HTML file (`docs/index.html`)
- Data files live in root `data/` directory (use `../data/`)
- Assets (images) live in `docs/assets/` (use `assets/`)
- Use forward slashes even on Windows
- Always `await` FileAttachment calls - they return promises

**Supported formats:** CSV, TSV, JSON, Parquet, Arrow, SQLite, DuckDB, ZIP, images, and more.

### DuckDB Integration

Observable Notebook Kit includes built-in DuckDB support for SQL queries. This is one of the most powerful features for data analysis.

#### SQL Cells

SQL cells query DuckDB databases directly:

```html
<script id="flows" output="flows" type="application/sql" database="../data/data.duckdb" hidden>
  select *
  from flows
  order by loading_date desc
</script>
```

**SQL cell attributes:**
- `type="application/sql"` - marks this as a SQL query
- `database="../data/data.duckdb"` - path to DuckDB database file (relative to notebook)
- `output="flows"` - variable name to store results (accessible in other cells)
- `hidden` - don't display output (optional)
- `id` - unique identifier for the cell

The query results become available as a JavaScript variable with the name specified in `output`:

```javascript
// Use the results from the SQL cell above
display(html`<p>Found ${flows.length} flows</p>`);
display(Inputs.table(flows));
```

#### DuckDB Client

For more complex queries, use `DuckDBClient.of()`:

```javascript
const db = DuckDBClient.of();

// Query returns an array of objects
const summary = await db.query(`
  select
    year,
    count(*) as flow_count,
    sum(volume_kt) as total_volume
  from flows
  group by year
  order by year
`);

display(Inputs.table(summary));
```

#### DuckDB Setup Boilerplate

Some notebooks include this boilerplate for compatibility:

```javascript
<script id="database-setup" type="module">
  // Should be able to remove this in future versions of Notebook Kit
  const db = DuckDBClient.of();
</script>
```

This initializes DuckDB for notebooks that use SQL cells. It may not be needed in newer versions.

### ETL Patterns

Many research notebooks use a two-stage data pipeline:

**Stage 1: Data preparation (outside the notebook)**
- Located in `etl/` directory (dbt + DuckDB is common)
- Processes raw data from APIs, spreadsheets, AIS feeds, etc.
- Outputs clean DuckDB databases or CSV files to `data/`
- Example: `46026b7e69d1df26536300f654ce80e2` uses dbt models to process 71,000 AIS positions into 762 validated cargo flows

**Stage 2: Analysis and visualization (in the notebook)**
- Load prepared data via FileAttachment or SQL cells
- Transform and aggregate using JavaScript/SQL
- Create visualizations with Observable Plot
- Generate interactive tables with Inputs

**Why this pattern?**
- Heavy data processing happens once, not every time the notebook loads
- Raw data sources can require credentials (LSEG API, Planet satellite imagery)
- dbt provides SQL-based transformations with testing and documentation
- DuckDB handles complex geospatial queries and large datasets efficiently
- Compiled notebooks remain fast and don't need external dependencies

## Visualization

### Observable Plot

Observable Plot is the recommended charting library (built into Notebook Kit):

```javascript
// Bar chart with stacking
display(Plot.plot({
  title: "Annual volumes by destination",
  width: 928,
  height: 400,
  x: { label: "Year" },
  y: { label: "Volume (Mt)", grid: true },
  color: {
    legend: true,
    domain: ["Europe", "Asia"],
    range: ["#74c0fc", "#f8f9fa"]
  },
  marks: [
    Plot.barY(data, {
      x: "year",
      y: "volume",
      fill: "continent",
      tip: true
    }),
    Plot.ruleY([0])
  ]
}));

// Line chart
display(Plot.plot({
  marks: [
    Plot.line(timeseries, {
      x: "date",
      y: "value",
      stroke: "#74c0fc"
    })
  ]
}));

// Area chart with stacking
display(Plot.plot({
  marks: [
    Plot.areaY(data, {
      x: "date",
      y: "volume",
      fill: "destination",
      curve: "step-after"
    })
  ]
}));
```

**Plot features:**
- Automatic scales and axes
- Built-in tooltips with `tip: true`
- Responsive by default
- Great for time series, distributions, correlations
- Documentation: https://observablehq.com/plot/

### Interactive Inputs

Use `Inputs` for user controls:

```javascript
// Toggle
const show_all = view(Inputs.toggle({label: "Show all columns", value: false}));

// Search box
const searched = view(Inputs.search(data));

// Table with search
display(Inputs.table(searched, {
  rows: 25,
  columns: show_all ? undefined : ["name", "date", "value"]
}));

// Slider
const threshold = view(Inputs.range([0, 100], {step: 1, value: 50}));

// Select dropdown
const country = view(Inputs.select(["UK", "Norway", "Sweden"]));
```

The `view()` function makes the input value reactive - other cells automatically update when it changes.

### External Libraries

#### Mapbox GL JS

For interactive maps (example from `afungi-logistics`):

```html
<!-- Load CSS in a cell -->
<script id="mapbox-css" type="text/html">
  <link href="https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.css" rel="stylesheet" />
</script>

<!-- Load and use the library -->
<script id="map" type="module">
  // Load the script
  const script = document.createElement('script');
  script.src = 'https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.js';
  script.onload = () => initMap();
  document.head.appendChild(script);

  function initMap() {
    window.mapboxgl.accessToken = 'pk.eyJ1...';
    const map = new window.mapboxgl.Map({
      container: 'map',
      style: 'mapbox://styles/mapbox/dark-v11',
      center: [40.4, -11.6],
      zoom: 8
    });
  }
</script>

<!-- Container for the map -->
<script id="map-container" type="text/html">
  <div id="map" style="height: 500px; width: 100%;"></div>
</script>
```

#### Other Libraries

- **D3**: Available via `require()` or dynamic imports
- **Leaflet**: Alternative to Mapbox for maps
- **Arquero**: Data wrangling (DataFrame-like API)
- Any npm package via dynamic `import()` or `require()`

## Development Workflow

### Build System

All notebooks use a minimal Makefile with three phony targets:

```makefile
.PHONY: build preview data clean

build:
	yarn build

preview:
	yarn preview

data:
	# Repo-specific: generate/update data files

clean:
	rm -rf docs/.observable/dist
```

**Standard targets:**
- `make build` - Build notebook to `docs/.observable/dist/`
- `make preview` - Local dev server with hot reload
- `make data` - Generate/update data (implementation varies by repo)
- `make clean` - Remove build artifacts

**Key insight:** SQL cells query DuckDB at build time, results embedded in HTML. Database files (`data/*.duckdb`) needed for build, not deployment.

**File targets pattern:**
For incremental builds, use file targets under phony targets:

```makefile
.PHONY: data
data: data/data.duckdb

data/data.duckdb: raw/*.csv scripts/process.py
	python scripts/process.py
	duckdb $@ "CREATE TABLE flows AS SELECT * FROM 'raw/*.csv'"
```

Workflow calls `make data || true` (fails gracefully if target doesn't exist).

### Setup

```bash
git clone https://github.com/data-desk-eco/[repo-name]
cd [repo-name]
yarn
make preview  # or: yarn preview
make build    # or: yarn build
```

### Local Preview

The preview server runs at `http://localhost:3000` with:
- Hot reload on file changes
- Same template as production
- Faster iteration than building

**Editing workflow:**
1. Open `docs/index.html` in your editor
2. Run `yarn preview`
3. Edit and save - changes appear immediately
4. Check browser console for errors

### Building

The build process:
1. Parses the `<notebook>` element and its cells
2. Compiles JavaScript cells into modules
3. Bundles dependencies (Plot, DuckDB, etc.)
4. Applies the custom template (`template.html`)
5. Outputs to `docs/.observable/dist/`

**Build command:**
```bash
notebooks build --root docs --template template.html -- docs/*.html
```

**What gets generated:**
- `docs/.observable/dist/index.html` - complete standalone page
- `docs/.observable/dist/assets/` - bundled JavaScript and CSS
- Copies of data files referenced by the notebook

**Important:** The dist folder is gitignored. The source is `docs/index.html`, not the built output.

### Deployment

**Self-updating workflow:** `.github/workflows/deploy.yml` downloads itself from the main repo on every run. Fix bugs once, all repos get them.

Workflow steps:
1. Download shared `template.html`, `CLAUDE.md`, and `deploy.yml` from main repo
2. Run `make data` (if exists)
3. Commit updates to `data/`, `template.html`, `CLAUDE.md`, `deploy.yml`
4. Run `make build`
5. Deploy `docs/.observable/dist/` to GitHub Pages

**GitHub Pages setup:**
- Settings → Pages → Source: GitHub Actions
- Domain: `research.datadesk.eco`
- Each repo becomes subdirectory (e.g., `/afungi-logistics/`)

**Template repo:** `data-desk-eco.github.io` - copy to start new notebook. **Delete CNAME file immediately** to avoid domain conflict.

## Template Customization

The `template.html` file wraps the compiled notebook:

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style type="text/css">
      @import url("observable:styles/index.css");
      @import url("https://rsms.me/inter/inter.css");

      :root {
        font-family: Inter, sans-serif;
      }

      /* Custom styles... */
    </style>
  </head>
  <body>
    <main>
      <!-- Logo, branding -->
    </main>
    <hr>
    <p id="footer">
      <!-- Footer content -->
    </p>
  </body>
</html>
```

**Data Desk template features:**
- Inter font family for clean typography
- Midnight theme for dark mode aesthetic
- Data Desk logo in header
- Custom list styling (using `>` instead of bullets)
- Footer with organization description and Observable attribution

**Customizing:**
- Edit `template.html` in your repo
- Changes apply to all notebooks in that repo
- Use `observable:styles/index.css` to import base styles
- Custom CSS overrides notebook defaults

## Common Patterns

### Data Aggregation

```javascript
// Group by and sum using d3.rollup
const annualTotals = d3.rollup(
  flows,
  v => d3.sum(v, d => d.volume),
  d => d.year
);

// Convert Map to array
const data = Array.from(annualTotals, ([year, volume]) => ({
  year,
  volume
})).sort((a, b) => a.year - b.year);
```

### Formatting

```javascript
// Date formatting
const formatDate = d3.utcFormat("%B %Y");
formatDate(new Date("2025-01-15")); // "January 2025"

// Number formatting
const formatNumber = d3.format(",.1f");
formatNumber(1234.567); // "1,234.6"

// Currency
const formatCurrency = d3.format("$,.0f");
formatCurrency(1234567); // "$1,234,567"
```

### Inline Calculations for Narrative

```javascript
// Calculate stats in a cell
const total = d3.sum(flows, d => d.volume);
const average = d3.mean(flows, d => d.volume);
const maxYear = d3.max(flows, d => d.year);
```

Then reference in markdown:

```html
<script type="text/markdown">
  Our analysis found ${total.toFixed(1)} Mt shipped across ${flows.length}
  voyages, peaking in ${maxYear} with an average of ${average.toFixed(1)} Mt
  per year.
</script>
```

### Conditional Display

```javascript
const show_details = view(Inputs.toggle({label: "Show details"}));

display(Inputs.table(data, {
  columns: show_details
    ? undefined  // all columns
    : ["name", "date", "value"]  // subset
}));
```

### Multi-way Joins

```javascript
// Join two datasets
const enriched = flows.map(f => ({
  ...f,
  vessel_name: vessels.find(v => v.imo === f.vessel_imo)?.name
}));

// Or use arquero for DataFrame-style operations
const joined = aq.table(flows)
  .join(aq.table(vessels), "vessel_imo", "imo")
  .select("loading_date", "vessel_name", "volume")
  .objects();
```

## Debugging

### Common Issues

**"FileAttachment is not defined"**
- FileAttachment is available in `type="module"` cells only
- Make sure your cell has `type="module"`, not `type="text/javascript"`

**Data not loading**
- Check file path is relative to `docs/index.html`
- Verify file exists in `data/` directory (use `../data/` from notebook)
- Check browser network tab for 404 errors
- Ensure filename case matches (case-sensitive on Linux/GitHub)

**Plot not rendering**
- Did you `display()` the plot?
- Check browser console for JavaScript errors
- Verify data structure matches plot spec
- Try wrapping in try/catch to see error messages

**SQL cell returns empty results**
- Verify database file exists at `data/data.duckdb`
- Check table name spelling
- Test query in DuckDB CLI first
- Ensure database path in SQL cell is `../data/data.duckdb`

**Template not applied**
- Verify `--template template.html` in build command
- Check template file exists in repo root
- Look for syntax errors in template HTML

**Preview works but build fails**
- Check for absolute paths in FileAttachment (should be relative)
- Ensure data files use `../data/` from notebook
- Test build locally before pushing

### Debugging SQL

Use DuckDB CLI to test queries:

```bash
duckdb data/data.duckdb

D SELECT count(*) FROM mentions;
D .schema mentions
D .tables
```

### Browser Console

Open browser dev tools (F12) to see:
- JavaScript errors
- Network requests for data files
- Variable values via console.log()
- Live values of notebook cells

## Performance

### Large Datasets

**Strategies:**
- Use Parquet instead of CSV (10-100x smaller, faster)
- Pre-aggregate data in ETL pipeline, not in notebook
- Store data in DuckDB and query subsets via SQL cells
- Use `Inputs.table()` pagination (default 25 rows)
- Consider streaming for very large datasets

**Example:**
```javascript
// Instead of loading 1M rows:
// const all = await FileAttachment("../data/huge.csv").csv();

// Load aggregated subset via SQL cell:
const summary = await db.query(`
  SELECT year, month, sum(value) as total
  FROM huge_table
  GROUP BY year, month
`);
```

### Build Time

**Optimization:**
- Minimize external library imports
- Use SQL cells instead of loading full datasets
- Enable code splitting for large notebooks
- Avoid large images (compress/resize before adding)

**Typical build times:**
- Simple notebook: 2-5 seconds
- With DuckDB queries: 5-10 seconds
- Complex with maps/images: 10-20 seconds

## Repository Structure

Standard layout for Data Desk research notebooks:

```
research-notebook/
├── .github/
│   └── workflows/
│       └── deploy.yml           # GitHub Actions deployment
├── data/                        # Data files (DuckDB, CSV, JSON)
│   ├── data.duckdb              # Main database
│   ├── flows.csv                # Optional: source data
│   └── vessels.json             # Optional: reference data
├── docs/
│   ├── index.html               # Notebook source (EDIT THIS)
│   ├── assets/                  # Images, screenshots
│   │   └── photo.jpg
│   └── .observable/
│       └── dist/                # Built output (gitignored)
├── etl/                         # Optional: data processing
│   ├── models/                  # dbt models (SQL)
│   ├── seeds/                   # Reference data (CSV)
│   └── dbt_project.yml
├── scripts/                     # Optional: data collection scripts
│   └── fetch.sh
├── template.html                # Custom HTML wrapper (auto-updated)
├── package.json                 # Dependencies and scripts
├── Makefile                     # Build targets
├── .gitignore
├── README.md                    # GitHub repo description
└── CLAUDE.md                    # This file (auto-updated)
```

**What to commit:**
- `docs/index.html` (notebook source)
- `data/*` (processed data files and databases)
- `docs/assets/*` (images)
- `etl/*` (data pipeline)
- `scripts/*` (data collection)
- `package.json`, `Makefile`

**What NOT to commit:**
- `docs/.observable/dist/` (built output)
- `node_modules/`
- `.env` (credentials)
- `template.html` (auto-updated from main repo)
- `CLAUDE.md` (auto-updated from main repo)
- Raw/intermediate data files (keep in ETL, export processed to `data/`)

## Creating a New Notebook

### From Template

1. Use `data-desk-eco.github.io` as GitHub template
2. Name repo (becomes URL slug)
3. **⚠️ CRITICAL: Delete the `CNAME` file immediately** - it contains `research.datadesk.eco` which is specific to the main index site. If you leave this file in your new project, it will cause a domain conflict and break the main research index. Your new notebook will deploy to `https://research.datadesk.eco/[repo-name]/` without needing a CNAME file.
4. Enable GitHub Pages (Settings → Pages → Source: GitHub Actions)
5. Clone and install: `git clone [url] && cd [repo] && yarn`

### Minimal Notebook

```html
<!doctype html>
<notebook theme="midnight">
  <title>My Research</title>

  <script type="text/markdown">
    # My Research

    This notebook analyzes...
  </script>

  <script type="module">
    const data = await FileAttachment("data.csv").csv({typed: true});
    display(Inputs.table(data));
  </script>
</notebook>
```

Save as `docs/index.html`, add `data.csv` to `data/`, then `make preview`.

### Workflow steps

1. Plan narrative - what story does the data tell?
2. Prepare data - add `make data` target to Makefile if needed
3. Structure cells - alternate markdown (narrative) and code (analysis)
4. Add visualizations - start simple (tables), add charts as needed
5. Test locally - `make preview` and iterate
6. Deploy - push to GitHub, workflow handles rest

## Advanced Topics

### Geospatial Analysis

DuckDB has spatial extension built-in:

```sql
<script type="application/sql" database="data/flows.duckdb" output="ports">
  SELECT
    port_name,
    ST_AsGeoJSON(geometry) as geojson,
    count(*) as visit_count
  FROM port_visits
  GROUP BY port_name, geometry
</script>
```

Use results in Mapbox/Leaflet:

```javascript
ports.forEach(port => {
  const coords = JSON.parse(port.geojson).coordinates;
  new mapboxgl.Marker()
    .setLngLat(coords)
    .setPopup(new mapboxgl.Popup().setText(port.port_name))
    .addTo(map);
});
```

### Time Series

```javascript
// Resample daily data to monthly
const monthly = d3.rollup(
  daily_data,
  v => d3.mean(v, d => d.value),
  d => d3.utcMonth(d.date)
);

// Calculate moving average
function movingAverage(data, window) {
  return data.map((d, i) => {
    const slice = data.slice(Math.max(0, i - window + 1), i + 1);
    return {
      ...d,
      ma: d3.mean(slice, x => x.value)
    };
  });
}
```

### Complex Transformations

For heavy data wrangling, use Arquero:

```javascript
import * as aq from "npm:arquero";

const summary = aq.table(flows)
  .filter(d => d.year >= 2020)
  .groupby("destination", "year")
  .rollup({
    count: d => op.count(),
    total: d => op.sum(d.volume),
    avg: d => op.mean(d.volume)
  })
  .orderby("year", "destination")
  .objects();

display(Inputs.table(summary));
```

### Multiple Notebooks

For large projects, split into multiple notebooks:

```
docs/
├── index.html           # Overview
├── methodology.html     # Methods
├── findings.html        # Results
└── data/                # Shared data
```

Build all notebooks:
```bash
notebooks build --root docs --template template.html -- docs/*.html
```

Link between notebooks:
```html
<script type="text/markdown">
  See our [methodology](methodology.html) for details.
</script>
```

**Note:** All notebooks share the same `data/` directory, so data can be reused across notebooks.

## Resources

### Documentation

- **Observable Notebook Kit:** https://observablehq.com/notebook-kit/
- **Observable Plot:** https://observablehq.com/plot/
- **Observable Inputs:** https://observablehq.com/notebook-kit/inputs
- **FileAttachment API:** https://observablehq.com/notebook-kit/files
- **Observable stdlib:** https://github.com/observablehq/stdlib
- **DuckDB SQL:** https://duckdb.org/docs/sql/introduction
- **Observable Desktop:** https://observablehq.com/notebook-kit/desktop (visual editor)

### Examples

All Data Desk notebooks are open source — browse at https://research.datadesk.eco/

### Getting Help

- Observable Discord: https://observablehq.com/slack-invite (active community)
- GitHub Issues: https://github.com/observablehq/notebook-kit/issues
- Stack Overflow: Tag `observablehq`

## Tips for AI Agents

1. **Use `make` commands:** `make preview` not `yarn preview`, `make build` not `yarn build`
2. **SQL cells query at build time:** Results embedded in HTML, database not deployed
3. **Data in root data/:** Files in `data/` directory, reference as `../data/` from notebook
4. **Display everything:** Don't return values, use `display()` explicitly
5. **Cell types:** `type="module"` for JS, `type="text/markdown"` for markdown, `type="application/sql"` for SQL
6. **Observable stdlib global:** `html`, `svg`, `FileAttachment`, `display` available everywhere
7. **Always await:** FileAttachment and database queries are async
8. **Edit source not dist:** Don't edit `docs/.observable/dist/`, edit `docs/index.html`
9. **Shared files auto-update:** `template.html` and `CLAUDE.md` download from main repo
10. **Data generation:** Add `make data` target for ETL, use file targets for incremental builds
11. **Test queries:** Use `duckdb data/data.duckdb` to test queries before adding to notebook
12. **Browser console:** Check for errors and inspect variables during preview
13. **Relative paths:** Use `../data/` for data files, `assets/` for images
14. **Plot first:** Use Observable Plot before reaching for D3
15. **Workflow self-updates:** `.github/workflows/deploy.yml` downloads itself from main repo

## Project-Specific Notes

This repository (`data-desk-eco.github.io`) serves as the central index at `https://research.datadesk.eco/`. It:
- Aggregates all Data Desk notebooks via GitHub API
- Auto-updates daily via GitHub Actions
- Also functions as a template for new notebooks

To add a new project to the index:
- Create repo in `data-desk-eco` org
- Enable GitHub Pages (Actions)
- Add description (shows in index)
- It will appear automatically within 24 hours
