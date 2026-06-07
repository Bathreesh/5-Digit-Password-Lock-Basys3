# 🔐 5-Digit Password Lock System — Basys3 FPGA

A hardware-implemented password lock system built in **Verilog HDL** on the **Digilent Basys3 (Artix-7)** FPGA, using a **Finite State Machine (FSM)** architecture. The system supports setting and verifying a 5-digit password using onboard push buttons, with real-time signal monitoring via **Xilinx ILA (Integrated Logic Analyzer)**.

---

## 📋 Table of Contents

- [Project Overview](#project-overview)
- [Hardware Requirements](#hardware-requirements)
- [System Architecture](#system-architecture)
- [FSM Design](#fsm-design)
- [Pin Mapping](#pin-mapping)
- [Module Descriptions](#module-descriptions)
- [Operating Procedure](#operating-procedure)
- [ILA Debugging](#ila-debugging)
- [Project Structure](#project-structure)
- [How to Reproduce](#how-to-reproduce)
- [Concepts Demonstrated](#concepts-demonstrated)

---

## 📌 Project Overview

| Field | Details |
|---|---|
| **Board** | Digilent Basys3 (Artix-7 XC7A35T) |
| **HDL** | Verilog |
| **Tool** | Xilinx Vivado 2025.2 |
| **Architecture** | Finite State Machine (FSM) |
| **Password Length** | 5 digits |
| **Input Method** | 4 directional push buttons (5 presses) + 1 confirm button |
| **Output** | 3 onboard LEDs |
| **Debugging** | Xilinx ILA (Integrated Logic Analyzer) |

---

## 🛠️ Hardware Requirements

- Digilent Basys3 FPGA Board
- USB-A to Micro-USB cable (for programming and JTAG debugging)
- Xilinx Vivado Design Suite (2020.x or later)

---

## 🏗️ System Architecture

```
                        ┌─────────────────────────────────────┐
                        │           Basys3 FPGA                │
                        │                                      │
  BTNU ──┐              │  ┌──────────┐    ┌───────────────┐  │
  BTNL ──┤──[Debounce]──┼──┤          │    │               │  │──► LED[0] Locked
  BTNR ──┤──[Debounce]──┼──┤   FSM    │    │  ILA Core     │  │──► LED[1] Unlocked
  BTND ──┤──[Debounce]──┼──┤ Password │◄───┤  (Monitoring) │  │──► LED[2] Wrong
  BTNC ──┘──[Debounce]──┼──┤  Lock    │    │               │  │
                        │  └──────────┘    └───────────────┘  │
  SW[0] ────────────────┼──► Mode Select                      │
  CLK  ────────────────┼──► 100 MHz System Clock              │
                        └─────────────────────────────────────┘
```

---

## 🔄 FSM Design

The system is implemented as a **6-state Mealy FSM**:

```
                    SW=1 (Set Mode)
                          │
          ┌───────────────▼───────────────┐
          │                               │
     ┌────▼─────┐   any digit        ┌────▼──────┐
     │   IDLE   ├───pressed──────────►  COLLECT  │
     │  LED[0]  │                    │  LED[0]   │
     └────▲─────┘                    └─────┬─────┘
          │                                │ BTNC pressed
          │                                │ & digit_count==5
          │           ┌────────────────────┤
          │           │ SW=1               │ SW=0
          │    ┌──────▼──────┐     ┌───────▼───────┐
          │    │  SET_DONE   │     │    COMPARE    │
          │    │   LED[1]    │     │  (no LEDs)    │
          │    └──────┬──────┘     └───────┬───────┘
          │           │               ┌────┴────┐
          │       3 sec timer    Match?       No Match?
          │           │            │               │
          └───────────┘     ┌──────▼──────┐ ┌─────▼──────┐
                            │  UNLOCKED   │ │   WRONG    │
                            │   LED[1]    │ │   LED[2]   │
                            └──────┬──────┘ └─────┬──────┘
                                   │               │
                               3 sec timer    3 sec timer
                                   │               │
                                   └───────────────┘
                                           │
                                        back to IDLE
```

### State Table

| State | LED[0] | LED[1] | LED[2] | Description |
|---|---|---|---|---|
| `IDLE` | ON | OFF | OFF | System locked, waiting for input |
| `COLLECT` | ON | OFF | OFF | Receiving 5 button presses |
| `SET_DONE` | OFF | ON | OFF | Password saved confirmation (3 sec) |
| `COMPARE` | OFF | OFF | OFF | Comparing input vs saved password |
| `UNLOCKED` | OFF | ON | OFF | Correct password — unlocked (3 sec) |
| `WRONG` | OFF | OFF | ON | Wrong password (3 sec) |

---

## 📍 Pin Mapping

### Push Buttons

| Button | Package Pin | Function |
|---|---|---|
| BTNC | U18 | Confirm / Enter |
| BTNU | T18 | Digit "1" |
| BTNL | W19 | Digit "2" |
| BTNR | T17 | Digit "3" |
| BTND | U17 | Digit "4" |

### Switch

| Switch | Package Pin | Function |
|---|---|---|
| SW[0] | V17 | Mode: HIGH = Set, LOW = Check |

### LEDs

| LED | Package Pin | Function |
|---|---|---|
| LED[0] | U16 | System Locked |
| LED[1] | E19 | System Unlocked / Password Set |
| LED[2] | U19 | Incorrect Password |

### Clock

| Signal | Package Pin | Frequency |
|---|---|---|
| CLK | W5 | 100 MHz |

---

## 📦 Module Descriptions

### `debounce.v`
Eliminates mechanical switch bounce using a 20ms counter-based filter.
- **Debounce time:** 20ms (2,000,000 cycles @ 100MHz)
- **Method:** Two-stage synchronizer + stable-state counter
- **Protects against:** Metastability and false edge detection

### `edge_detect.v`
Converts a debounced button level signal into a **single-cycle pulse** on the rising edge.
- Ensures each button press is registered exactly once
- Prevents FSM from advancing multiple states on a single press

### `password_lock.v` *(Top Module)*
Main FSM implementing all password lock logic.
- Instantiates debounce and edge_detect for all 5 buttons
- Manages 5-digit password storage (`saved_pass[0:4]`)
- Controls 3-second display timer via `timer_run` / `timer_done` handshake
- `pass_set` flag prevents checking before any password has been set
- Instantiates ILA core for on-chip debugging

---

## 🔑 Operating Procedure

### Setting a Password

```
1. Flip SW[0] UP         → Enter Set Mode
2. Press any 5 button sequence using BTNU / BTNL / BTNR / BTND
   Example: BTNU → BTNR → BTND → BTNL → BTNU
3. Press BTNC            → Confirm
4. LED[1] lights for 3 seconds → Password saved ✓
5. Returns to IDLE automatically
```

### Checking a Password

```
1. Flip SW[0] DOWN       → Enter Check Mode
2. Press the same 5 buttons in the exact same order
3. Press BTNC            → Confirm

   ✓ Correct: LED[1] ON for 3 seconds → returns to IDLE
   ✗ Wrong:   LED[2] ON for 3 seconds → returns to IDLE
```

### Button Role Summary

```
┌──────────┬──────────────────────────────────────────────┐
│  BTNU    │  Digit "1" — usable multiple times           │
│  BTNL    │  Digit "2"                                   │
│  BTNR    │  Digit "3"                                   │
│  BTND    │  Digit "4"                                   │
├──────────┼──────────────────────────────────────────────┤
│  BTNC    │  CONFIRM only — never counts as a digit      │
└──────────┴──────────────────────────────────────────────┘
```

> ℹ️ Repetition is allowed. `BTNU → BTNU → BTNU → BTNU → BTNU` is a valid password.

> ⚠️ Pressing BTNC before all 5 digits are entered is safely ignored.

---

## 🔬 ILA Debugging

This project uses a **Xilinx ILA (Integrated Logic Analyzer)** core to monitor internal FSM signals in real time over JTAG — no external oscilloscope needed.

### Probes Configured

| Probe | Signal | Width | What It Shows |
|---|---|---|---|
| probe0 | `state[2:0]` | 3-bit | FSM state number |
| probe1 | `led_locked` | 1-bit | HIGH during IDLE/COLLECT |
| probe2 | `led_unlock` | 1-bit | HIGH during UNLOCKED/SET_DONE |
| probe3 | `led_wrong` | 1-bit | HIGH during WRONG |
| probe4 | `digit_count[2:0]` | 3-bit | Counts 0 → 5 as digits entered |
| probe5 | `timer_run` | 1-bit | HIGH when 3-sec timer is active |

### Trigger Setup

```
Trigger on: state[2:0] != 0
(captures waveform the moment FSM leaves IDLE)
```

### Expected Waveform (Correct Password Entry)

```
Time ──────────────────────────────────────────────────────►

state       000──001──────────────011─100────────000
            IDLE  COLLECT          CMP  UNLOCKED  IDLE

led_locked  ████████████████████░░░░░░░░░░░░░░░░████
led_unlock  ░░░░░░░░░░░░░░░░░░░░░░░░░████████████░░░░
led_wrong   ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

digit_count 0──1──2──3──4──5──────0──────────────0──

timer_run   ░░░░░░░░░░░░░░░░░░░░░░░░░████████████░░░░
```

---

## 📁 Project Structure

```
5-Digit-Password-Lock-Basys3/
│
├── src/
│   ├── debounce.v           # Button debounce module
│   ├── edge_detect.v        # Rising edge pulse detector
│   └── password_lock.v      # Top-level FSM (includes ILA)
│
├── constraints/
│   └── password_lock.xdc    # Basys3 pin constraints
│
├── sim/
│   └── tb_password_lock.v   # Testbench (optional simulation)
│
└── README.md
```

---

## ⚙️ How to Reproduce

```
1. Clone this repository
   git clone https://github.com/Bathreesh/5-Digit-Password-Lock-Basys3.git

2. Open Vivado 2020.x or later

3. Create New RTL Project
   → Part: xc7a35tcpg236-1  (Basys3)

4. Add Source Files
   → src/debounce.v
   → src/edge_detect.v
   → src/password_lock.v   (set as Top)

5. Add Constraints
   → constraints/password_lock.xdc

6. Add ILA IP
   → IP Catalog → ILA → 6 probes (widths: 3,1,1,1,3,1)

7. Run Synthesis → Implementation → Generate Bitstream

8. Open Hardware Manager → Program Device

9. Open hw_ila_1 tab → Set trigger → Arm → Press buttons
```

---

## 🧠 Concepts Demonstrated

- **FSM Design in Verilog** — 6-state Mealy machine with clean state encoding
- **Button Debouncing** — Counter-based hardware debounce (20ms window)
- **Edge Detection** — Single-cycle pulse generation from level signals
- **Sequential Logic** — Password storage using register arrays
- **Timer Design** — Handshake-based `timer_run`/`timer_done` pattern
- **On-Chip Debugging** — Xilinx ILA integration for real-time signal capture
- **FPGA Constraint File** — XDC pin assignment for Basys3
- **RTL Design Verification** — Hardware validation via ILA waveforms

---

## 👤 Author

**Bathreesh M**
Electronics & Communication Engineering
GitHub: [github.com/Bathreesh](https://github.com/Bathreesh)

---

## 🏷️ Tags

`FPGA` `Verilog` `Basys3` `FSM` `RTL` `DigitalDesign` `ILA` `Xilinx` `Vivado` `HardwareDebugging` `EmbeddedSystems` `SequentialLogic`
