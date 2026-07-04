onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /pcb_test/CLOCK_50
add wave -noupdate /pcb_test/SWITCH
add wave -noupdate /pcb_test/BUTTON
add wave -noupdate /pcb_test/RotaryEncoder_SW
add wave -noupdate /pcb_test/RotaryEncoder
add wave -noupdate /pcb_test/led_pcb
add wave -noupdate /pcb_test/LED
add wave -noupdate /pcb_test/led_matrix_inst/matrix_clk_internal
add wave -noupdate /pcb_test/led_matrix_inst/phase
add wave -noupdate /pcb_test/led_matrix_inst/enable
add wave -noupdate /pcb_test/led_matrix_inst/shift_data_package
add wave -noupdate /pcb_test/led_matrix_inst/row_counter
add wave -noupdate /pcb_test/led_matrix_inst/column_counter
add wave -noupdate /pcb_test/led_matrix_inst/bit_counter
add wave -noupdate /pcb_test/led_matrix_inst/matrix_en_internal
add wave -noupdate /pcb_test/led_matrix_inst/row_data
add wave -noupdate /pcb_test/led_matrix_inst/column_select
add wave -noupdate /pcb_test/led_matrix_inst/row_select
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {33171024 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 284
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {33170536 ps} {33171136 ps}
