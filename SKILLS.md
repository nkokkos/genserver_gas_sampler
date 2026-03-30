# Elixir Nerves Poncho Project — SKILL.md

A comprehensive reference for architecture, design, and best practices in a Nerves poncho project.

---

## 1. Poncho Project Structure

A poncho project is a collection of independent Mix apps that share no umbrella parent but reference each other via `path` dependencies. Each app is its own Mix project with its own `mix.exs`, tests, and supervision tree.

```
my_project/
├── my_firmware/          # Nerves target app (the device)
│   ├── mix.exs
│   ├── config/
│   └── lib/
├── my_ui/                # Phoenix LiveView or web layer
│   ├── mix.exs
│   ├── config/
│   └── lib/
├── my_core/              # Shared business logic (pure Elixir)
│   ├── mix.exs
│   └── lib/
└── my_shared/            # Shared types, protocols, helpers
    ├── mix.exs
    └── lib/
```

**Rules:**
- `my_firmware` depends on `my_core` and `my_shared` via `path:`.
- `my_ui` depends on `my_core` and `my_shared` via `path:`.
- `my_core` depends only on `my_shared`.
- No circular dependencies. Ever.

```elixir
# my_firmware/mix.exs
defp deps do
  [
    {:my_core, path: "../my_core"},
    {:my_shared, path: "../my_shared"},
    {:nerves, "~> 1.10", runtime: false},
    {:nerves_runtime, "~> 0.13"},
    {:vintage_net, "~> 0.13"},
  ]
end
```

---

## 2. Firmware App (`my_firmware`)

The firmware app is the Nerves entry point. It must stay thin — hardware setup, supervision, and delegation to `my_core`.

### Supervision Tree

```elixir
defmodule MyFirmware.Application do
  use Application

  def start(_type, _args) do
    children = [
      {MyCore.Supervisor, []},
      {MyFirmware.Hardware.Supervisor, []},
      {MyFirmware.Network, []},
    ]

    opts = [strategy: :one_for_one, name: MyFirmware.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**Rule:** Never put business logic in `MyFirmware`. Delegate to `MyCore`.

### Target Configuration

```elixir
# mix.exs — firmware only
def project do
  [
    app: :my_firmware,
    version: "0.1.0",
    nerves_app: true,                         # marks this as the Nerves app
    archives: [nerves_bootstrap: "~> 1.12"],
    releases: [{:my_firmware, release()}],
    preferred_cli_target: [run: :host, test: :host]
  ]
end

defp release do
  [
    overwrite: true,
    cookie: "replace_with_secure_cookie",
    include_erts: &Nerves.Release.erts/0,
    steps: [&Nerves.Release.init/1, :assemble],
    strip_beams: Mix.env() == :prod
  ]
end
```

### Target-specific config

```elixir
# config/target.exs
import Config

config :my_firmware, :target, :rpi4

config :vintage_net,
  regulatory_domain: "US",
  config: [
    {"usb0", %{type: VintageNetDirect}},
    {"wlan0", %{
      type: VintageNetWiFi,
      vintage_net_wifi: %{
        networks: [%{ssid: System.get_env("WIFI_SSID"), psk: System.get_env("WIFI_PSK")}]
      }
    }}
  ]
```

---

## 3. Core App (`my_core`)

All domain logic lives here. No Nerves dependencies. Fully testable on the host.

### GenServer Pattern

```elixir
defmodule MyCore.SensorManager do
  use GenServer
  require Logger

  @poll_interval 5_000

  defstruct readings: [], status: :idle

  # --- Public API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_readings, do: GenServer.call(__MODULE__, :get_readings)
  def start_polling, do: GenServer.cast(__MODULE__, :start_polling)

  # --- Callbacks ---

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:get_readings, _from, state) do
    {:reply, state.readings, state}
  end

  @impl true
  def handle_cast(:start_polling, state) do
    schedule_poll()
    {:noreply, %{state | status: :polling}}
  end

  @impl true
  def handle_info(:poll, state) do
    case MyCore.Sensor.read() do
      {:ok, reading} ->
        schedule_poll()
        {:noreply, %{state | readings: [reading | state.readings]}}

      {:error, reason} ->
        Logger.warning("Sensor read failed: #{inspect(reason)}")
        schedule_poll()
        {:noreply, state}
    end
  end

  defp schedule_poll, do: Process.send_after(self(), :poll, @poll_interval)
end
```

### Supervisor Pattern

```elixir
defmodule MyCore.Supervisor do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      MyCore.SensorManager,
      MyCore.EventBus,
      {MyCore.Storage, path: "/data/store"},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
```

### Functional Core

Keep pure functions in plain modules, no process state:

```elixir
defmodule MyCore.Reading do
  @enforce_keys [:value, :unit, :timestamp]
  defstruct [:value, :unit, :timestamp, :source]

  @type t :: %__MODULE__{
    value: float(),
    unit: atom(),
    timestamp: DateTime.t(),
    source: atom() | nil
  }

  def new(value, unit) do
    %__MODULE__{
      value: value,
      unit: unit,
      timestamp: DateTime.utc_now(),
    }
  end

  def celsius_to_fahrenheit(%__MODULE__{unit: :celsius} = r) do
    %{r | value: r.value * 9 / 5 + 32, unit: :fahrenheit}
  end
end
```

---

## 4. Shared App (`my_shared`)

Structs, protocols, error types, and constants shared across all apps.

```elixir
# my_shared/lib/my_shared/error.ex
defmodule MyShared.Error do
  @type t :: %__MODULE__{
    code: atom(),
    message: String.t(),
    context: map()
  }
  defstruct [:code, :message, context: %{}]

  def new(code, message, context \\ %{}) do
    %__MODULE__{code: code, message: message, context: context}
  end
end
```

```elixir
# Define shared protocols
defprotocol MyShared.Serializable do
  def to_map(struct)
  def from_map(module, map)
end
```

---

## 5. UI App (`my_ui`) — Phoenix LiveView

```elixir
# my_ui/mix.exs
defp deps do
  [
    {:my_core, path: "../my_core"},
    {:my_shared, path: "../my_shared"},
    {:phoenix, "~> 1.7"},
    {:phoenix_live_view, "~> 0.20"},
    {:bandit, "~> 1.0"},
  ]
end
```

### LiveView connected to Core

```elixir
defmodule MyUiWeb.DashboardLive do
  use MyUiWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      MyCore.EventBus.subscribe(:sensor_reading)
    end

    readings = MyCore.SensorManager.get_readings()
    {:ok, assign(socket, readings: readings)}
  end

  @impl true
  def handle_info({:sensor_reading, reading}, socket) do
    {:noreply, update(socket, :readings, &[reading | &1])}
  end
end
```

---

## 6. Hardware Abstraction Layer (HAL)

Isolate hardware access behind a behaviour so host tests work without real hardware.

```elixir
# my_core/lib/my_core/sensor.ex
defmodule MyCore.Sensor do
  @callback read() :: {:ok, float()} | {:error, term()}

  def read do
    impl().read()
  end

  defp impl do
    Application.get_env(:my_core, :sensor_impl, MyCore.Sensor.Real)
  end
end

# Real implementation — used on device
defmodule MyCore.Sensor.Real do
  @behaviour MyCore.Sensor

  def read do
    case Circuits.I2C.write_read(:i2c_bus, 0x48, <<0x00>>, 2) do
      {:ok, <<msb, lsb>>} -> {:ok, parse_temp(msb, lsb)}
      {:error, _} = err   -> err
    end
  end

  defp parse_temp(msb, lsb) do
    ((msb <<< 8 ||| lsb) >>> 4) * 0.0625
  end
end

# Stub — used in host tests
defmodule MyCore.Sensor.Stub do
  @behaviour MyCore.Sensor

  def read, do: {:ok, 25.0}
end
```

```elixir
# config/test.exs (in my_core)
import Config
config :my_core, sensor_impl: MyCore.Sensor.Stub
```

---

## 7. Event Bus (PubSub without Phoenix)

```elixir
defmodule MyCore.EventBus do
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  def subscribe(event) do
    GenServer.call(__MODULE__, {:subscribe, event, self()})
  end

  def publish(event, payload) do
    GenServer.cast(__MODULE__, {:publish, event, payload})
  end

  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_call({:subscribe, event, pid}, _from, state) do
    subscribers = Map.get(state, event, [])
    {:reply, :ok, Map.put(state, event, [pid | subscribers])}
  end

  @impl true
  def handle_cast({:publish, event, payload}, state) do
    state
    |> Map.get(event, [])
    |> Enum.each(&send(&1, {event, payload}))
    {:noreply, state}
  end
end
```

---

## 8. Configuration Strategy

| File                  | Purpose                                   |
|-----------------------|-------------------------------------------|
| `config/config.exs`   | Shared, compile-time defaults             |
| `config/dev.exs`      | Host development overrides                |
| `config/test.exs`     | Test stubs and fakes                      |
| `config/prod.exs`     | Production compile-time settings          |
| `config/target.exs`   | Device-only runtime config (Nerves)       |
| `config/runtime.exs`  | Runtime config via `System.get_env/1`     |

```elixir
# config/runtime.exs — secrets loaded at boot
import Config

if config_env() == :prod do
  config :my_core, :api_key, System.fetch_env!("API_KEY")
end
```

---

## 9. Testing Strategy

### Host testing (no device needed)

```elixir
# test/my_core/sensor_manager_test.exs
defmodule MyCore.SensorManagerTest do
  use ExUnit.Case, async: true

  setup do
    {:ok, pid} = MyCore.SensorManager.start_link()
    %{pid: pid}
  end

  test "returns empty readings initially", %{pid: _pid} do
    assert MyCore.SensorManager.get_readings() == []
  end
end
```

### Property-based testing with StreamData

```elixir
defmodule MyCore.ReadingTest do
  use ExUnit.Case
  use ExUnitProperties

  property "celsius_to_fahrenheit always returns correct unit" do
    check all value <- float(min: -273.15, max: 1000.0) do
      reading = MyCore.Reading.new(value, :celsius)
      result = MyCore.Reading.celsius_to_fahrenheit(reading)
      assert result.unit == :fahrenheit
    end
  end
end
```

### Testing with mox

```elixir
# test/support/mocks.ex
Mox.defmock(MyCore.SensorMock, for: MyCore.Sensor)

# test/my_core/sensor_manager_test.exs
setup :verify_on_exit!

test "polls sensor and stores reading" do
  expect(MyCore.SensorMock, :read, fn -> {:ok, 42.5} end)
  # ...
end
```

---

## 10. OTP Design Rules

| Rule | Rationale |
|------|-----------|
| Always use `start_link/1` over `start/1` | Ensures crash propagation to supervisor |
| Use `:one_for_one` by default | Isolates failures |
| Use `:rest_for_one` for ordered dependencies | Restarts downstream when upstream crashes |
| Keep `init/1` fast (< 1s) | Prevent supervisor timeout |
| Use `handle_continue/2` for post-init work | Avoid blocking `init/1` |
| Never call self from `init/1` synchronously | Deadlock risk |

```elixir
# Correct: use handle_continue for deferred init
@impl true
def init(opts) do
  {:ok, %{}, {:continue, {:load_state, opts}}}
end

@impl true
def handle_continue({:load_state, opts}, state) do
  loaded = MyCore.Storage.load(opts[:path])
  {:noreply, Map.merge(state, loaded)}
end
```

---

## 11. Nerves-specific Guidelines

### Filesystem

```elixir
# Persistent storage lives on /data (survives firmware updates)
# Read-only rootfs is at /

data_path = "/data/my_app/config.json"
File.mkdir_p!(Path.dirname(data_path))
File.write!(data_path, Jason.encode!(config))
```

### System Validation at Boot

```elixir
defmodule MyFirmware.SystemCheck do
  require Logger

  def run do
    checks = [
      {:network, &check_network/0},
      {:storage, &check_storage/0},
    ]

    Enum.each(checks, fn {name, check} ->
      case check.() do
        :ok -> Logger.info("✓ #{name} OK")
        {:error, reason} -> Logger.error("✗ #{name} failed: #{inspect(reason)}")
      end
    end)
  end

  defp check_network, do: if(VintageNet.get(["interface", "wlan0", "connection"]) == :internet, do: :ok, else: {:error, :no_internet})
  defp check_storage, do: if(File.exists?("/data"), do: :ok, else: {:error, :no_data_partition})
end
```

### Firmware Updates (NervesHub)

```elixir
# my_firmware/mix.exs deps
{:nerves_hub_link, "~> 2.2"},

# config/target.exs
config :nerves_hub_link,
  host: System.get_env("NERVESHUB_HOST", "devices.nerveshub.org"),
  cert: File.read!("/data/nerves_hub/cert.pem"),
  key: File.read!("/data/nerves_hub/key.pem")
```

---

## 12. Mix Tasks and Workflows

```bash
# Build for device
MIX_TARGET=rpi4 mix firmware

# Flash to SD card
MIX_TARGET=rpi4 mix burn

# Upload OTA
MIX_TARGET=rpi4 mix upload

# Run tests on host (no device)
cd my_core && mix test
cd my_ui && mix test

# IEx on device via ssh
ssh nerves.local

# Format all apps
for dir in my_firmware my_core my_ui my_shared; do
  (cd $dir && mix format)
done
```

---

## 13. Code Quality Standards

```elixir
# .formatter.exs — per app, consistent settings
[
  import_deps: [:ecto, :phoenix, :stream_data],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs,heex}"]
]
```

```elixir
# Use typespecs on all public functions in shared/core
@spec get_readings() :: [MyCore.Reading.t()]
def get_readings, do: GenServer.call(__MODULE__, :get_readings)
```

```bash
# Run dialyzer (static analysis)
mix dialyzer

# Run credo (style/lint)
mix credo --strict
```

---

## 14. Dependency Graph (Visual Reference)

```
my_shared   ←──────────────────────────────┐
    ↑                                       │
my_core ←── my_firmware (Nerves device)    │
    ↑                                       │
my_ui   (Phoenix — host or device)  ────────┘
```

**Allowed dependency directions:** only upward (leaf → core → shared).
**Forbidden:** `my_core` importing from `my_firmware` or `my_ui`.

---

## 15. Golden Rules Summary

1. **Keep firmware thin.** Hardware setup + supervision only.
2. **All logic in `my_core`.** Testable on host without a device.
3. **Abstract hardware with behaviours.** Swap real/stub via config.
4. **Shared structs/types in `my_shared`.** No business logic there.
5. **Use `handle_continue/2` for slow init.** Never block `init/1`.
6. **Persistent data goes to `/data`.** Never write to rootfs.
7. **Config secrets in `runtime.exs` via env vars.** Never hardcode.
8. **One supervision strategy per use-case.** Think before choosing.
9. **Test on host.** CI should never need a device.
10. **Format + dialyzer + credo on every PR.** No exceptions.
