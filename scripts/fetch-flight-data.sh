#!/bin/bash

# Fetch ADS-B flight track data from May 1 to August 29, 2025
# This script runs before the build process to avoid CORS issues
# Implements caching - only downloads missing data

echo "Fetching flight track data from May 1 to August 29, 2025..."

# Create docs/data directory if it doesn't exist
mkdir -p docs/data

# Cache file to track checked dates
CACHE_FILE="docs/data/.flight_cache"
touch "$CACHE_FILE"

# Set start and end dates
START_DATE="2025-05-01"
END_DATE="2025-08-29"

# Counter for downloaded files
downloaded=0
skipped=0
failed=0
cached_no_data=0

# Function to check cache for a date
check_cache() {
    local date=$1
    local cached_status=$(grep "^$date:" "$CACHE_FILE" | cut -d: -f2)
    echo "$cached_status"
}

# Function to update cache for a date
update_cache() {
    local date=$1
    local status=$2
    # Remove existing entry if any (macOS and Linux compatible)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "/^$date:/d" "$CACHE_FILE" 2>/dev/null
    else
        # Linux
        sed -i "/^$date:/d" "$CACHE_FILE" 2>/dev/null
    fi
    # Add new entry
    echo "$date:$status" >> "$CACHE_FILE"
}

# Function to download a single day's data
download_flight_data() {
    local date=$1
    local filename="flight-track-${date}.json"
    local filepath="docs/data/${filename}"

    # Check cache first
    local cached_status=$(check_cache "$date")

    # If already downloaded, skip
    if [ -f "$filepath" ]; then
        echo "⏭️  Skipping $date (already exists)"
        ((skipped++))
        return 0
    fi

    # If marked as no_data in cache, skip
    if [ "$cached_status" = "no_data" ]; then
        echo "🚫 Skipping $date (cached as no data)"
        ((cached_no_data++))
        return 0
    fi

    # Format date for URL (YYYY/MM/DD) - macOS compatible
    local url_date=$(date -j -f "%Y-%m-%d" "$date" "+%Y/%m/%d" 2>/dev/null || date -d "$date" +"%Y/%m/%d" 2>/dev/null || echo "$date" | sed 's/-/\\//g')

    echo "📥 Downloading $date..."

    # Try ADS-B Exchange first
    curl -s "https://globe.adsbexchange.com/globe_history/${url_date}/traces/4f/trace_full_20104f.json" \
      -H 'sec-ch-ua-platform: "macOS"' \
      -H 'Referer: https://globe.adsbexchange.com/?icao=20104f&lat=-11.533&lon=40.397&zoom=9.8&showTrace=2025-05-02&leg=2&trackLabels' \
      -H 'sec-ch-ua: "Chromium";v="139", "Not;A=Brand";v="99"' \
      -H 'sec-ch-ua-mobile: ?0' \
      -H 'X-Requested-With: XMLHttpRequest' \
      -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36' \
      -H 'Accept: application/json, text/javascript, */*; q=0.01' \
      -H 'DNT: 1' \
      -o "$filepath"

    # Check if ADS-B Exchange worked
    if [ $? -eq 0 ] && [ -s "$filepath" ] && grep -q '"icao"' "$filepath"; then
        echo "✅ Downloaded $date (ADS-B Exchange)"
        update_cache "$date" "has_data"
        ((downloaded++))
        return 0
    fi

    # If ADS-B Exchange failed, try OpenSky Network (convert ICAO hex to decimal)
    icao_decimal=$((16#20104f))  # Convert 20104f hex to decimal
    opensky_url="https://opensky-network.org/api/tracks/all?icao24=20104f&time=0"

    curl -s "$opensky_url" -o "${filepath}.opensky"

    if [ $? -eq 0 ] && [ -s "${filepath}.opensky" ] && grep -q '"path"' "${filepath}.opensky"; then
        # Convert OpenSky format to our expected format
        mv "${filepath}.opensky" "$filepath"
        echo "✅ Downloaded $date (OpenSky Network)"
        update_cache "$date" "has_data"
        ((downloaded++))
    else
        echo "❌ No flight data for $date"
        update_cache "$date" "no_data"
        ((failed++))
        # Clean up any failed downloads
        [ -f "$filepath" ] && rm "$filepath"
        [ -f "${filepath}.opensky" ] && rm "${filepath}.opensky"
    fi
}

# Download all flight data from May 1 to August 29, 2025
# Using macOS-compatible date handling
START_DATE="2025-05-01"
END_DATE="2025-08-29"

echo "Downloading flight data for the entire period: $START_DATE to $END_DATE"
echo "This will take a while as we're checking 120+ dates..."

# Convert dates to timestamps for iteration
start_timestamp=$(date -j -f "%Y-%m-%d" "$START_DATE" "+%s" 2>/dev/null)
if [ $? -ne 0 ]; then
    # Fallback for Linux
    start_timestamp=$(date -d "$START_DATE" +%s 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "❌ Error: Unable to parse start date"
        exit 1
    fi
fi

end_timestamp=$(date -j -f "%Y-%m-%d" "$END_DATE" "+%s" 2>/dev/null)
if [ $? -ne 0 ]; then
    # Fallback for Linux
    end_timestamp=$(date -d "$END_DATE" +%s 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "❌ Error: Unable to parse end date"
        exit 1
    fi
fi

# Loop through each day
current_timestamp=$start_timestamp
day_count=0

while [ $current_timestamp -le $end_timestamp ]; do
    # Convert timestamp back to date format
    if command -v gdate >/dev/null 2>&1; then
        # Use GNU date if available
        current_date=$(gdate -d "@$current_timestamp" +%Y-%m-%d)
    else
        # Try macOS date first, then Linux date
        current_date=$(date -j -f "%s" "$current_timestamp" "+%Y-%m-%d" 2>/dev/null || date -d "@$current_timestamp" +%Y-%m-%d 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "❌ Error: Unable to format date from timestamp $current_timestamp"
            exit 1
        fi
    fi

    download_flight_data "$current_date"
    ((day_count++))

    # Show progress every 10 days
    if [ $((day_count % 10)) -eq 0 ]; then
        echo "📊 Progress: Processed $day_count dates so far..."
    fi

    # Move to next day (86400 seconds)
    current_timestamp=$((current_timestamp + 86400))
done

echo "✅ Completed processing all $day_count dates in the range!"

# If we want to try more dates later, we can expand this list
# For now, focus on getting the core functionality working

# Summary
echo ""
echo "📊 Download Summary:"
echo "  ✅ Downloaded: $downloaded files"
echo "  ⏭️  Skipped: $skipped files (already cached)"
echo "  🚫 Cached no-data: $cached_no_data files"
echo "  ❌ Failed: $failed files"

total_processed=$((downloaded + skipped + cached_no_data + failed))
echo "  📈 Total processed: $total_processed dates"

if [ $failed -gt 0 ]; then
    echo "⚠️  Some downloads failed. Check the dates above."
    exit 1
else
    echo "🎉 All flight track data is ready!"
fi