# PCB_Test

FPGA design for functional testing of a custom peripheral PCB, developed as part of my diploma thesis. It runs on a Terasic DE0-Nano (Intel Cyclone IV E, EP4CE22F17C6) with the test board attached to the GPIO headers, and exercises every peripheral on the board: buttons, switches, a rotary encoder, a 5x7 LED matrix, PWM audio and VGA output.

## Hardware

- Terasic DE0-Nano, 50 MHz onboard oscillator (no PLLs used)
- Custom test PCB with:
  - 4 push buttons and 4 slide switches
  - quadrature rotary encoder with integrated push button
  - 5x7 LED matrix driven by a 74HC595 (row select) and an STP08DP05 (column driver) shift register chain
  - PWM audio output
  - VGA output with 4-bit R, G and B channels

## Controls

| Input | Function |
|---|---|
| SWITCH 3 | Enable audio output |
| SWITCH 2 | Enable LED matrix |
| SWITCH 1 | Enable VGA output |
| BUTTON 0 | Cycle VGA test pattern (diagonal split, window, bar graph) |
| BUTTON 0-3 | Select the character shown on the LED matrix (binary value 0-F) |
| Rotary encoder | Select the audio note (natural notes G3-A5) and the VGA bar graph width |
| Encoder push button | Shown on LED 1 |

The eight LEDs (`led_pcb`) mirror the debounced button and switch states, so debouncing and wiring can be checked at a glance. LED 0 of the two-bit `LED` output blinks as a heartbeat.

## Design overview

| File | Description |
|---|---|
| `PCB_Test.vhd` | Top level: instantiates all controllers and maps inputs to status LEDs |
| `input_handler.vhd` | Button/switch debouncing (1 ms sampling, 15 ms stability window) |
| `rotary_encoder_controller.vhd` | Synchronization, debouncing and quadrature decoding; 4-bit position counter with wrap-around |
| `audio_controller.vhd` | Direct digital synthesis: 16-bit phase accumulator at a 100 kHz sample rate, quarter-wave sine table, 8-bit PWM output |
| `led_matrix_controller.vhd` | Scan driver for the 5x7 matrix; shifts 16-bit row/column frames into the 74HC595/STP08DP05 chain and latches them with an EN pulse |
| `vga_controller.vhd` | 800x600 @ 72 Hz timing directly from the 50 MHz clock; three test patterns |

Everything runs in the single 50 MHz clock domain. Timing constraints are in `PCB_Test.sdc`, pin assignments in `PCB_Test.qsf`.

## Building and programming

Requires Intel Quartus Prime Lite 20.1 (or newer). Open `PCB_Test.qpf` in the GUI and start compilation, or from the command line:

```
quartus_sh --flow compile PCB_Test
quartus_pgm -m jtag -o "p;output_files/PCB_Test.sof"
```

## Simulation

`wave.do` is a ModelSim wave setup for inspecting the LED matrix controller signals at the top level.

## Attribution

The VGA timing core in `vga_controller.vhd` and the rotary encoder state
machine in `rotary_encoder_controller.vhd` are based on example code by my
thesis mentor, doc. dr. Andrej Trost (Faculty of Electrical Engineering,
University of Ljubljana). Both were extended for this project (test
patterns, enable logic, decoding of both rotation directions).
