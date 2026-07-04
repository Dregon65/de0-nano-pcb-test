# 50 MHz board oscillator
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

derive_clock_uncertainty

# All I/O is asynchronous (buttons, switches, encoder, LEDs, PWM audio)
# or slow relative to the pixel/shift clocks, so no I/O delay constraints
# are needed for this test design.
set_false_path -from [get_ports {BUTTON[*] SWITCH[*] RotaryEncoder[*] RotaryEncoder_SW}]
set_false_path -to [get_ports {LED[*] led_pcb[*] AUDIO_OUT LedMatrix_* VGA_*}]
