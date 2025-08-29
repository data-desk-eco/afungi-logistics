# Afungi Logistics Project - Claude Reference

## Project Overview
This project tracks and visualizes logistics operations for the Mozambique LNG project at Afungi, Cabo Delgado. It monitors passenger flights between Maputo (capital), Pemba (coastal port), and the Afungi project site using ADS-B flight tracking data.

## Key Locations & Coordinates
- **Maputo**: ~(-25.9, 32.57) - Mozambique capital, main hub
- **Pemba**: ~(-12.99, 40.52) - Coastal port city, intermediate stop
- **Afungi**: ~(-10.82, 40.53) - LNG project site, limited ADS-B coverage

## Technical Architecture

### Data Pipeline
1. **Flight Track Collection**: JSON files from ADS-B Exchange API (`docs/data/flight-track-YYYY-MM-DD.json`)
2. **Data Processing**: DuckDB SQL query with altitude-based flight segmentation
3. **Visualization**: Observable Notebook Kit with Mapbox GL JS for 3D flight paths

### Key Files
- `docs/index.html` - Observable notebook with flight visualization
- `generate_flight_summary.sh` - DuckDB script to process flight data
- `docs/data/flight-summary.csv` - Processed flight segments with takeoff/landing data
- `scripts/download_flight_data.js` - Downloads flight tracks from ADS-B Exchange

## Flight Data Processing

### Multi-Flight Segmentation
Many days contain multiple flight segments (e.g., Maputo → Pemba → Afungi → Pemba → Maputo). The DuckDB query detects these using:
- **Altitude threshold**: < 2000ft considered "on ground"
- **Time filter**: Minimum 15 minutes flight duration
- **Point filter**: Minimum 50 airborne data points

### Signal Loss at Afungi
ADS-B coverage is poor at the remote Afungi site. The signal often cuts out during approach:
- Flights to Afungi may show landing at 3000-9000ft altitude
- Location detection uses wider bounding boxes for Afungi
- Special handling in query for high-altitude "landings" near Afungi

### DuckDB Query Pattern
```sql
-- Key technique: unnest array while maintaining order
WITH unnested AS (
    SELECT 
        unnest(range(1, array_length(trace)+1)) as idx,
        unnest(trace) as point
    FROM read_json('flight-track-*.json', ...)
),
-- Detect ground-to-air transitions
transitions AS (
    SELECT *,
        LAG(is_ground) OVER (ORDER BY idx) as prev_ground,
        CASE WHEN prev_ground = 1 AND is_ground = 0 THEN 1 ELSE 0 END as is_takeoff
    FROM altitudes
),
-- Assign flight numbers based on takeoffs
flight_segments AS (
    SELECT *,
        SUM(is_takeoff) OVER (ORDER BY idx) as flight_num
    FROM transitions
)
```

## Observable Notebook Integration

### Key Components
1. **FileAttachment**: Loads pre-generated CSV data (no runtime DuckDB needed)
2. **Mapbox Visualization**: 3D flight paths with altitude-based coloring
3. **Flight Table**: Shows date, flight number, times, route, and duration

### Build Process
```bash
# 1. Generate flight summary CSV
./generate_flight_summary.sh

# 2. Build the notebook
npm run docs:build
```

## Data Insights

### Flight Patterns
- **Aircraft**: V5-WEN (Embraer ERJ-145, ~50 passengers)
- **Frequency**: Multiple flights per day during active periods
- **Routes**: Common patterns include:
  - Direct: Maputo ↔ Afungi
  - Via Pemba: Maputo → Pemba → Afungi
  - Multi-stop: Complex logistics with multiple segments

### Operational Notes
- Flights started May 1, 2025 (project restart after force majeure)
- Some days show 7+ flight segments indicating shuttle operations
- Flight durations: ~20-30 min for Pemba-Afungi, ~2 hours for Maputo-Pemba

## Troubleshooting

### Common Issues
1. **Malformed JSON files**: Some API responses return HTML 404 pages
   - Solution: Delete bad files, query handles with `ignore_errors=true`

2. **Multiple flights not detected**: Check altitude thresholds
   - Current: 2000ft ground threshold works well
   - Too low (500ft) creates too many segments
   - Too high (5000ft) misses some landings

3. **Unknown locations**: Usually intermediate points or high-altitude positions
   - These are often mid-flight waypoints, not actual landing locations

## Future Improvements
- Implement proper multi-leg flight tracking with intermediate stops
- Add flight path interpolation for missing Afungi approach data
- Include vessel tracking data from Global Fishing Watch
- Add real-time updates when API data becomes available