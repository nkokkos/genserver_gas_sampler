#!/bin/bash

# Clean script for Gas Sensor Poncho Project
# Removes build artifacts and dependencies for a fresh start

set -e

echo "======================================"
echo "Gas Sensor Firmware Clean Script"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get project root
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Project root: $PROJECT_ROOT"
echo ""

# Parse arguments
NUCLEAR=false
SKIP_CONFIRMATION=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --nuclear|-n)
      NUCLEAR=true
      shift
      ;;
    --yes|-y)
      SKIP_CONFIRMATION=true
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -n, --nuclear    Full nuclear clean (delete _build and deps directories)"
      echo "  -y, --yes        Skip confirmation prompts"
      echo "  -h, --help       Show this help message"
      echo ""
      echo "Examples:"
      echo "  $0                    # Soft clean (mix clean + deps.clean)"
      echo "  $0 --nuclear          # Nuclear clean (rm -rf _build deps)"
      echo "  $0 -n -y              # Nuclear clean without confirmation"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Confirmation function
confirm() {
  if [ "$SKIP_CONFIRMATION" = true ]; then
    return 0
  fi
  
  echo -e "${YELLOW}$1${NC}"
  read -p "Continue? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborted.${NC}"
    exit 1
  fi
}

# Calculate what will be deleted
calculate_cleanup() {
  local app=$1
  local size_build=0
  local size_deps=0
  
  if [ -d "$PROJECT_ROOT/$app/_build" ]; then
    size_build=$(du -sb "$PROJECT_ROOT/$app/_build" 2>/dev/null | cut -f1)
  fi
  
  if [ -d "$PROJECT_ROOT/$app/deps" ]; then
    size_deps=$(du -sb "$PROJECT_ROOT/$app/deps" 2>/dev/null | cut -f1)
  fi
  
  local total=$((size_build + size_deps))
  echo $total
}

format_size() {
  local size=$1
  if [ $size -gt 1073741824 ]; then
    echo "$(echo "scale=2; $size/1073741824" | bc)GB"
  elif [ $size -gt 1048576 ]; then
    echo "$(echo "scale=2; $size/1048576" | bc)MB"
  elif [ $size -gt 1024 ]; then
    echo "$(echo "scale=2; $size/1024" | bc)KB"
  else
    echo "${size}B"
  fi
}

# Main cleaning logic
if [ "$NUCLEAR" = true ]; then
  echo -e "${RED}NUCLEAR CLEAN MODE${NC}"
  echo ""
  
  # Calculate total size to be freed
  GAS_SENSOR_SIZE=$(calculate_cleanup "core")
  GAS_SENSOR_WEB_SIZE=$(calculate_cleanup "ui")
  SAMPLER_SIZE=$(calculate_cleanup "firmware")
  TOTAL_SIZE=$((GAS_SENSOR_SIZE + GAS_SENSOR_WEB_SIZE + SAMPLER_SIZE))
  
  echo "This will delete the following directories:"
  echo "  - gas_sensor/_build"
  echo "  - gas_sensor/deps"
  echo "  - gas_sensor_web/_build"
  echo "  - gas_sensor_web/deps"
  echo "  - sampler/_build"
  echo "  - sampler/deps"
  echo ""
  echo "Total space to be freed: $(format_size $TOTAL_SIZE)"
  echo ""
  
  confirm "This will PERMANENTLY DELETE all build artifacts and dependencies!"
  
  echo -e "${YELLOW}Starting nuclear clean...${NC}"
  echo ""
  
  # Step 1: gas_sensor
  echo -e "${BLUE}Cleaning gas_sensor...${NC}"
  cd "$PROJECT_ROOT/gas_sensor"
  if [ -d "_build" ]; then
    rm -rf _build
    echo -e "${GREEN}  ✓ Removed _build/$(format_size $GAS_SENSOR_SIZE)${NC}"
  else
    echo "  - _build/ (already clean)"
  fi
  if [ -d "deps" ]; then
    rm -rf deps
    echo -e "${GREEN}  ✓ Removed deps/${NC}"
  else
    echo "  - deps/ (already clean)"
  fi
  
  # Step 2: gas_sensor_web
  echo -e "${BLUE}Cleaning gas_sensor_web...${NC}"
  cd "$PROJECT_ROOT/gas_sensor_web"
  if [ -d "_build" ]; then
    rm -rf _build
    echo -e "${GREEN}  ✓ Removed _build/$(format_size $GAS_SENSOR_WEB_SIZE)${NC}"
  else
    echo "  - _build/ (already clean)"
  fi
  if [ -d "deps" ]; then
    rm -rf deps
    echo -e "${GREEN}  ✓ Removed deps/${NC}"
  else
    echo "  - deps/ (already clean)"
  fi
  
  # Step 3: sampler
  echo -e "${BLUE}Cleaning sampler...${NC}"
  cd "$PROJECT_ROOT/sampler"
  if [ -d "_build" ]; then
    rm -rf _build
    echo -e "${GREEN}  ✓ Removed _build/$(format_size $SAMPLER_SIZE)${NC}"
  else
    echo "  - _build/ (already clean)"
  fi
  if [ -d "deps" ]; then
    rm -rf deps
    echo -e "${GREEN}  ✓ Removed deps/${NC}"
  else
    echo "  - deps/ (already clean)"
  fi
  
  echo ""
  echo -e "${GREEN}Nuclear clean complete!${NC}"
  echo "Freed $(format_size $TOTAL_SIZE) of disk space."
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo "  1. Run ./build.sh to rebuild everything from scratch"
  echo "  2. Or run 'mix deps.get' in individual apps"
  
else
  # Soft clean mode using mix commands
  echo -e "${BLUE}SOFT CLEAN MODE${NC}"
  echo "This uses 'mix clean' and 'mix deps.clean' (safer than nuclear)"
  echo ""
  
  confirm "This will clean compiled files and dependencies using mix commands."
  
  # Step 1: Clean gas_sensor
  echo -e "${YELLOW}Step 1: Cleaning gas_sensor...${NC}"
  cd "$PROJECT_ROOT/gas_sensor"
  if [ -d "_build" ]; then
    mix clean
    echo -e "${GREEN}  ✓ Cleaned compiled files${NC}"
  else
    echo "  - Already clean (no _build directory)"
  fi
  if [ -d "deps" ]; then
    mix deps.clean --all
    echo -e "${GREEN}  ✓ Cleaned dependencies${NC}"
  else
    echo "  - No deps to clean"
  fi
  
  # Step 2: Clean gas_sensor_web
  echo -e "${YELLOW}Step 2: Cleaning gas_sensor_web...${NC}"
  cd "$PROJECT_ROOT/gas_sensor_web"
  if [ -d "_build" ]; then
    mix clean
    echo -e "${GREEN}  ✓ Cleaned compiled files${NC}"
  else
    echo "  - Already clean (no _build directory)"
  fi
  if [ -d "deps" ]; then
    mix deps.clean --all
    echo -e "${GREEN}  ✓ Cleaned dependencies${NC}"
  else
    echo "  - No deps to clean"
  fi
  
  # Step 3: Clean sampler
  echo -e "${YELLOW}Step 3: Cleaning sampler...${NC}"
  cd "$PROJECT_ROOT/sampler"
  export MIX_TARGET=rpi0
  if [ -d "_build" ]; then
    mix clean
    echo -e "${GREEN}  ✓ Cleaned compiled files${NC}"
  else
    echo "  - Already clean (no _build directory)"
  fi
  if [ -d "deps" ]; then
    mix deps.clean --all
    echo -e "${GREEN}  ✓ Cleaned dependencies${NC}"
  else
    echo "  - No deps to clean"
  fi
  
  echo ""
  echo -e "${GREEN}Soft clean complete!${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo "  1. Run ./build.sh to rebuild everything"
  echo "  2. Or run 'mix deps.get && mix compile' in individual apps"
fi

echo ""
echo "======================================"
echo -e "${GREEN}Clean Complete!${NC}"
echo "======================================"
echo ""

# Show current disk usage
echo "Current project size:"
du -sh "$PROJECT_ROOT" 2>/dev/null || echo "  (Unable to calculate)"
