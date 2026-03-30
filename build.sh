#!/bin/bash

# Build script for Gas Sensor Poncho Project
# This script compiles all three OTP applications and builds the firmware

set -e

echo "======================================"
echo "Gas Sensor Firmware Build Script"
echo "Target: Raspberry Pi Zero W"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Project root: $PROJECT_ROOT"
echo ""

# Step 1: Build gas_sensor (business logic)
echo -e "${YELLOW}Step 1: Building gas_sensor (business logic)...${NC}"
cd "$PROJECT_ROOT/gas_sensor"
mix deps.get
mix compile
echo -e "${GREEN}✓ gas_sensor compiled successfully${NC}"
echo ""

# Step 2: Build gas_sensor_web (Phoenix web interface)
echo -e "${YELLOW}Step 2: Building gas_sensor_web (web interface)...${NC}"
cd "$PROJECT_ROOT/gas_sensor_web"
mix deps.get
mix compile
echo -e "${GREEN}✓ gas_sensor_web compiled successfully${NC}"
echo ""

# Step 3: Build sampler firmware (Nerves)
echo -e "${YELLOW}Step 3: Building sampler firmware (Nerves)...${NC}"
cd "$PROJECT_ROOT/sampler"

# Check if MIX_TARGET is set
if [ -z "$MIX_TARGET" ]; then
    echo -e "${YELLOW}Setting MIX_TARGET to rpi0...${NC}"
    export MIX_TARGET=rpi0
fi

echo "MIX_TARGET: $MIX_TARGET"
mix deps.get
mix firmware
echo -e "${GREEN}✓ Firmware built successfully${NC}"
echo ""

# Step 4: Display results
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo "Firmware location:"
ls -lh "$PROJECT_ROOT/sampler/_build/rpi0_dev/nerves/images/" 2>/dev/null || echo "  (Check _build/rpi0_dev/nerves/images/)"
echo ""
echo "To burn to SD card, run:"
echo "  cd $PROJECT_ROOT/sampler"
echo "  mix burn"
echo ""
echo "Or use this script:"
echo "  ./build.sh && cd sampler && mix burn"
