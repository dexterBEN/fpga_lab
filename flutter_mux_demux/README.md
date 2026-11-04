# MUX / DEMUX Visualizer

A Flutter application for simulating PYNQ-Z2 exercises 5 and 6.
Supports local simulation and an optional WebSocket connection to a notebook.
No board connection is required for simulation.

## Run

```bash
cd flutter_mux_demux
flutter pub get
flutter run -d linux
# Or in Chrome:
flutter run -d chrome
```

Android, Linux, and web platform configurations are included. Running on Linux
requires the usual Flutter desktop tools (Clang, CMake, Ninja, GTK).
Run `flutter doctor` to identify missing prerequisites on your machine.

## Usage

- Separate MUX 4→1 and DEMUX 1→4 tabs.
- Change inputs using the switches or directly in the graph.
- Set the selector using 00…11, the S1/S0 switches, or the selection table.
- The selected path is turquoise, even at logic level 0. Pulses appear when
  the routed signal is 1. Animations respect the reduced motion setting.
- Synchronized output inspector and selection table.
- On narrow screens, the graph scrolls horizontally to remain readable.

Input values are retained when switching tabs during a session.
The selector is shared between both modes. Nothing is persisted across restarts.

## Architecture

`lib/app`: theme and Cubit injection.

`lib/features/mux_demux`:

- `model/circuit_state.dart`: immutable state and combinational results.
- `bloc/mux_demux_cubit.dart`: user actions.
- `data/mux_demux_repository.dart`: repository contract and local simulation.
- `view/`: controls, inspector, table, and animated CustomPainter graph.

The WebSocket adapter implements `MuxDemuxRepository` and communicates with the
notebook using JSON. A single WebSocket reader handles responses and physical
input events. Repositories publish `states` (`Stream<CircuitState>`, broadcast
without replay); the Cubit observes only the active source and serializes commands.
The Cubit owns the repositories and closes their streams when it is closed.
The existing VHDL exercises are unchanged.

Reference visuals are stored in `assets/design/`: a dark background, outlined
nodes, turquoise routes, and a selector below the component.

## Validation

```bash
flutter analyze
flutter test
flutter build web
```

Tests cover all binary MUX/DEMUX combinations, Cubit transitions, and UI
interactions on wide and narrow screens.

## WebSocket notebook connection

Start the server in `notebooks/mux_demux_bridge.ipynb`, then click
**Connecter au serveur** (Connect to server). The default address is
`ws://192.168.200.120:8765` (configurable through `WEBSOCKET_URL` to match the
board's actual address).
MUX and DEMUX commands then use the notebook's JSON protocol, and the indicators
display its responses. **Revenir en simulation** (Return to simulation) restores
the local session. The MUX remains simulated in Python; the DEMUX uses FPGA
outputs read through MMIO in the notebook. `physical_inputs` events automatically
update D, S0/S1 through the selector, and Y0…Y3 without sending a command back
or switching the visible tab. The selector remains shared between modes.
The status indicates the server connection, not hardware validation.

Connecting sends no commands and does not push old Flutter values to the board.
The backend does not yet guarantee a physical input snapshot on every connection:
before the first event, values come from the repository's last snapshot or its
initial values. Change a physical input to receive a measurement.
`get_physical_inputs` is not called automatically because its current
implementation also writes to the DEMUX.

Server errors retain their message and leave the socket reusable. A malformed or
inconsistent message, or a timeout, invalidates the session and terminates pending
commands. Socket closure while idle is also reported. To reconnect, return to
simulation and use the connection button again. There is no automatic retry,
request ID, or revision tracking: states follow reception order.
Late responses from an invalidated session are ignored.

To use a different address:

```bash
flutter run -d chrome --dart-define=WEBSOCKET_URL=ws://192.168.200.120:8765
```

`127.0.0.1` refers to the machine running the application or browser.
When the server runs in a Dev Container, check port 8765 forwarding in VS Code.
On a physical Android device, use a reachable server address.
A web page served over HTTPS requires a secure `wss://` connection.
Connecting is manual; the application starts in local simulation mode.
