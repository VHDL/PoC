onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /ocram_tdp_sim_tb/clk
add wave -noupdate /ocram_tdp_sim_tb/ce1
add wave -noupdate /ocram_tdp_sim_tb/ce2
add wave -noupdate /ocram_tdp_sim_tb/we1
add wave -noupdate /ocram_tdp_sim_tb/we2
add wave -noupdate -radix hexadecimal /ocram_tdp_sim_tb/a1
add wave -noupdate -radix hexadecimal /ocram_tdp_sim_tb/a2
add wave -noupdate -radix hexadecimal /ocram_tdp_sim_tb/d1
add wave -noupdate -radix hexadecimal /ocram_tdp_sim_tb/d2
add wave -noupdate -radix hexadecimal /ocram_tdp_sim_tb/q1
add wave -noupdate -radix hexadecimal /ocram_tdp_sim_tb/q2
add wave -noupdate -radix hexadecimal /ocram_tdp_sim_tb/rd_d1
add wave -noupdate -radix hexadecimal /ocram_tdp_sim_tb/rd_d2
add wave -noupdate -radix hexadecimal /ocram_tdp_sim_tb/exp_q1
add wave -noupdate -radix hexadecimal /ocram_tdp_sim_tb/exp_q2
add wave -noupdate -divider UUT
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {560000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 1
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
WaveRestoreZoom {261100 ps} {723100 ps}
