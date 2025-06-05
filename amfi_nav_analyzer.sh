#!/bin/bash

# AMFI NAV Analyzer - A creative way to analyze mutual fund data
# Features: TSV export, ASCII visualization, emojis, colors, markdown report

# --- Colors & Styles ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
NC='\033[0m' # No Color
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

# --- Configuration ---
URL="https://www.amfiindia.com/spages/NAVAll.txt"
TSV_FILE="scheme_assets.tsv"
MD_REPORT="fund_analysis.md"
TEMP_FILE=$(mktemp)

# --- Download Data ---
echo -e "${BLUE}📡 Downloading latest NAV data from AMFI...${NC}"
if ! curl -s "$URL" > "$TEMP_FILE"; then
    echo -e "${RED}❌ Failed to download data! Check internet connection.${NC}"
    exit 1
fi

# --- Extract Scheme & Asset Value ---
echo -e "${GREEN}🔍 Extracting Scheme Names & Asset Values...${NC}"
awk -F ';' '
BEGIN {
    print "Scheme Name\tAsset Value (Cr)"
}
/^[0-9]+;/ {
    scheme = $4
    sub(/^[[:space:]]+/, "", scheme)
    sub(/[[:space:]]+$/, "", scheme)
    if (scheme != "") current_scheme = scheme
    next
}
/^;/ && $3 ~ /Asset Value/ {
    asset = $3
    sub(/.*Asset Value:/, "", asset)
    sub(/Cr.*/, "", asset)
    gsub(/,/, "", asset)
    gsub(/ /, "", asset)
    if (current_scheme != "" && asset != "") {
        print current_scheme "\t" asset
    }
    next
}
' "$TEMP_FILE" > "$TSV_FILE"

# --- Generate Summary & Visualization ---
echo -e "${PURPLE}📊 Generating Summary & Visualization...${NC}"

# Get top 10 funds by AUM
TOP_10=$(sort -t$'\t' -k2,2nr "$TSV_FILE" | head -10)

# Calculate total AUM
TOTAL_AUM=$(awk -F'\t' '{sum += $2} END {printf "%.2f", sum}' "$TSV_FILE")

# --- Terminal Visualization ---
echo -e "\n${CYAN}🏆 ${BOLD}Top 10 Funds by AUM${NORMAL} (in Crores)${NC}"
echo -e "${YELLOW}----------------------------------------${NC}"

while IFS=$'\t' read -r scheme asset; do
    # Calculate bar length (scaled for terminal)
    bar_length=$(( (asset + 500) / 1000 ))  # Simple scaling for visibility
    printf "${GREEN}%-50s ${BLUE}₹%'8.2f ${PURPLE}" "$scheme" "$asset"
    printf "▮%.0s" $(seq 1 $bar_length)
    printf "\n${NC}"
done <<< "$TOP_10"

# --- Generate Markdown Report ---
echo -e "\n${CYAN}📝 Generating Markdown Report: ${MD_REPORT}${NC}"
cat <<EOF > "$MD_REPORT"
# 🏦 AMFI Mutual Fund Analysis Report  
**Generated on**: $(date)  

## 📈 Top 5 Funds by AUM  

| Scheme Name               | Asset Value (₹ Cr) |
|---------------------------|-------------------:|
$(sort -t$'\t' -k2,2nr "$TSV_FILE" | head -5 | awk -F'\t' '{printf "| %-25s | %18.2f |\n", $1, $2}')

## 📊 Summary  
- **Total Funds Analyzed**: $(wc -l < "$TSV_FILE")  
- **Total AUM**: ₹ $(printf "%'d" $TOTAL_AUM) Crores  
- **Largest Fund**: $(head -1 <<< "$TOP_10" | awk -F'\t' '{print $1}') (₹ $(head -1 <<< "$TOP_10" | awk -F'\t' '{printf "%\'d", $2}') Cr)  

### 🔍 Full Data  
[Download TSV]($TSV_FILE)  
EOF

# --- Cleanup ---
rm "$TEMP_FILE"

# --- Final Output ---
echo -e "\n${GREEN}✅ Done!${NC}"
echo -e "🔹 ${BOLD}TSV Data:${NORMAL} ${TSV_FILE}"
echo -e "🔹 ${BOLD}Markdown Report:${NORMAL} ${MD_REPORT}"
echo -e "\n${YELLOW}💡 Pro Tip: Run 'cat ${MD_REPORT}' to view the report!${NC}"