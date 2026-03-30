# Gas Sensor Web Application

This Phoenix application provides a LiveView web interface for the gas sensor.

## Architecture

- **DashboardLive** (`/`) - Overview dashboard with visual indicators
- **SensorLive** (`/sensor`) - Detailed sensor data with recent samples
- **SensorController** (`/api/readings`) - JSON API for external integrations

## Features

- Real-time LiveView updates (1-second polling)
- Visual PPM indicators (green/yellow/red based on levels)
- Responsive design optimized for mobile and desktop
- JSON API for programmatic access
- Minimal dependencies for embedded deployment

## Configuration

### Development
```bash
# Run on host
mix phx.server
# Access at http://localhost:4000
```

### Production (Target)
```bash
# Set environment variables or use defaults
export MIX_TARGET=rpi0
mix firmware
```

The web server runs on port 80 on the Pi Zero W.

## API Endpoints

- `GET /api/readings` - All readings
- `GET /api/readings/current` - Current reading only

## Styling

Uses inline Tailwind-like CSS classes embedded in the root layout for minimal 
asset size - no external CSS files or JavaScript build step needed for the 
embedded deployment.

## Dependencies

- Phoenix 1.7+ and LiveView 0.20+
- Bandit web server (lighter than Cowboy)
- No Ecto/database (data comes from GenServer state)
