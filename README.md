# AXI-to-CXL Flit Engine — VLSI Capstone

A Verilog-based FPGA implementation of an **AXI write-burst to CXL-style flit formatting datapath**, with a UART interface for sending test transactions from a host computer and receiving completion and performance counters.

The project is designed for the **AMD/Xilinx Arty A7-100T** development board and targets a **100 MHz** system clock. It includes synthesizable RTL, board constraints, simulation testbenches, and a Python hardware-validation script.

> **Scope note:** This is an educational RTL datapath/demo that formats AXI write data into CXL-style flits. It should not be described as a complete, protocol-certified CXL controller or a full PCIe/CXL physical interface.

## Features

- UART-based host interface for issuing write-burst transactions to the FPGA.
- AXI-style write address, write data, and write response handshaking.
- 128-bit data path (16 bytes per word).
- Byte packing and byte-enable (`KEEP`) generation.
- 256-byte flit-boundary tracking and crossing support.
- Header generation and flit metadata.
- Ping-pong bank/storage control and staging FIFO structures.
- Status reporting, including output byte/word/flit counts and stall metrics.
- Testbenches for individual blocks, integration, boundary cases, and traffic profiles.
- Python script for automated hardware testing over USB-UART.

## Repository layout

```text
VLSI-CAPSTONE-main/
├── Constraints/
│   └── arty_a7_100t.xdc       # Arty A7-100T pin and clock constraints
├── PythonTestRun/
│   └── v1_demo.py             # Host-side UART hardware validation
├── RTL/
│   ├── board_top.v             # FPGA board-level integration
│   ├── top_flit_engine.v       # Main datapath integration
│   ├── ingress.v               # AXI write ingress/handshaking
│   ├── packing.v               # Byte/word packing
│   ├── flit_staging_fifo.v     # Staging FIFO
│   ├── storage.v               # Storage path
│   ├── ping_pong_bank_ctrl.v   # Ping-pong bank control
│   ├── ping_pong_bram.v        # Bank memory
│   ├── cxl_header_gen.v        # Header generation
│   ├── cxl_formatter.v         # CXL-style output formatting
│   ├── uart_burst_bridge.v     # UART command/response bridge
│   ├── uart_rx.v               # UART receiver
│   ├── uart_tx.v               # UART transmitter
│   └── ...                     # Supporting control and datapath modules
└── TB/
    ├── tb_ingress.v
    ├── tb_packing.v
    ├── tb_storage.v
    ├── tb_egress.v
    └── sim2/                   # Integration, boundary and profile tests
```

## Hardware requirements

- AMD/Xilinx **Arty A7-100T** board (Artix-7 `XC7A100T-CSG324-1`).
- USB cable for programming and USB-UART communication.
- Computer with a serial port exposed by the board.
- Vivado Design Suite for synthesis, implementation, bitstream generation, and programming.
- Python 3 and `pyserial` for the host-side demo.

The included XDC targets the Arty A7-100T board's 100 MHz clock and USB-UART pins. If you use a different board or revision, verify and update the constraints before implementation.

## Build and program the FPGA

1. Extract or clone this repository.
2. Open **AMD/Xilinx Vivado** and create a project for the Arty A7-100T (`xc7a100t-csg324-1`).
3. Add the Verilog source files from `RTL/`.
4. Set `board_top` as the top-level module.
5. Add `Constraints/arty_a7_100t.xdc` as the constraints file.
6. Run **Synthesis**, **Implementation**, and **Generate Bitstream**.
7. Program the FPGA with the generated bitstream.
8. Connect the board over USB and identify the serial device on your host computer.

The board-level design uses a 100 MHz clock and configures the UART for 115200 baud. The UART timing parameter in the RTL is set for this clock/baud combination.

## Host-side hardware demo

Install the Python serial dependency:

```bash
python3 -m pip install pyserial
```

Open `PythonTestRun/v1_demo.py` and set `PORT` to the serial device used by your system. For example, on Linux it may be `/dev/ttyUSB1`:

```python
PORT = "/dev/ttyUSB1"
BAUD = 115200
```

Then run:

```bash
python3 PythonTestRun/v1_demo.py
```

Make sure the FPGA is programmed, the board is connected, and the selected serial port is correct. The script sends test transactions and checks the FPGA's response. On Linux, serial-port permissions may require adding your user to the appropriate device-access group or running with the permissions configured for your system.

### UART transaction format

The host script sends a packet with the following structure:

| Field | Size | Description |
|---|---:|---|
| Magic bytes | 2 bytes | `A5 5A` |
| Command | 1 byte | `01` for a write-burst transaction |
| Address | 8 bytes | 64-bit address, little-endian |
| Beat count | 1 byte | Number of 128-bit beats |
| Payload | `16 × beats` bytes | Burst payload |

The response is 21 bytes and begins with magic bytes `5A A5`.

| Response offset | Size | Meaning |
|---|---:|---|
| 0–1 | 2 bytes | Response header: `5A A5` |
| 2 | 1 byte | Status (`00` indicates success in the demo) |
| 3–6 | 4 bytes | Output byte count, little-endian |
| 7–8 | 2 bytes | Output word count, little-endian |
| 9–10 | 2 bytes | Output flit count, little-endian |
| 11–14 | 4 bytes | Stall count, little-endian |
| 15–18 | 4 bytes | Maximum stall run, little-endian |
| 19 | 1 byte | Stall-seen flag |
| 20 | 1 byte | CXL-path completion flag |

## Validation included in `v1_demo.py`

The host-side demo runs several checks:

1. A transaction near a flit end.
2. A boundary-crossing transaction at offset `0xF8`.
3. An extreme boundary case at offset `0xFF`.
4. A 256-byte burst.
5. An exhaustive sweep over all 256 possible low-byte offsets.
6. A seeded randomized test of 1,000 bursts, with 1–16 beats per burst.

The script checks status, byte/word/flit counts, and completion indications. It also reports stall metrics. A test is counted as passed only when the observed response matches the script's expected values.

**Validation status:** The repository includes a hardware test script intended to run these checks on the FPGA. Run it on your own programmed board to reproduce the results; do not assume a pass result from the presence of the script alone.

## Simulation

The `TB/` directory contains block-level and integration testbenches, including tests for ingress, packing, storage, egress, boundary sweeps, FIFO behavior, and traffic profiles.

To run them, add the RTL and relevant testbench files to a simulator such as Vivado Simulator, Icarus Verilog, or Questa. Select the testbench module as the simulation top. Exact compile commands can vary by simulator and by which testbench is being run.

Example using Icarus Verilog (adjust the source list for the chosen testbench):

```bash
iverilog -g2012 -s tb_packing -o sim.out RTL/*.v TB/tb_packing.v
vvp sim.out
```

If a testbench depends on additional modules or include paths, include those files and add the appropriate `-I` option. Review the testbench and RTL dependencies before using a wildcard compile command.

## Board controls and status LEDs

- **SW[0]**: enables the UART burst bridge.
- **BTN[0]**: reset input (active-low internally).
- **LED[0]**: transaction bridge busy.
- **LED[1]**: transaction done.
- **LED[2]**: stall observed.
- **LED[3]**: error indication.

For a fresh transaction, enable the design using `SW[0]` and use the reset button if the design needs to be reset. Keep the enable switch active while running the host demo.

## Known scope and limitations

- The output is a CXL-style formatted/flit datapath for an FPGA capstone demonstration, not a complete standards-compliant CXL endpoint.
- The included Python script communicates with physical FPGA hardware; it is not a software-only simulation.
- Pin assignments and UART settings are board-specific.
- Synthesis and timing results depend on the Vivado version, constraints, and selected implementation settings.
- The V1 test script describes its own checks and expected counts; hardware results should be recorded from an actual run.

## Future improvements

- Add reproducible simulator scripts and a unified regression target.
- Capture synthesis utilization and timing reports in the repository.
- Add assertions for AXI handshake and boundary invariants.
- Improve automated failure diagnostics and save machine-readable test summaries.
- Explore the V2 target noted by the demo: reducing or eliminating stalls through structural boundary handling.

## License

No license file is included in this repository. Add a `LICENSE` file before redistributing the project if you want to specify reuse terms.

## Acknowledgements

Built as a VLSI/FPGA capstone using Verilog RTL, AMD/Xilinx Vivado, the Arty A7-100T development board, and Python-based UART validation.
