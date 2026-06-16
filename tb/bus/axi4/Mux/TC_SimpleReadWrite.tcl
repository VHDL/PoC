onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /AXI4_Mux_TestHarness/DUT/Clock
add wave /AXI4_Mux_TestHarness/DUT/Reset
add wave /AXI4_Mux_TestHarness/DUT/In_M2S
add wave /AXI4_Mux_TestHarness/DUT/In_S2M
add wave /AXI4_Mux_TestHarness/DUT/Out_M2S
add wave /AXI4_Mux_TestHarness/DUT/Out_S2M
add wave -divider write_blk
add wave /AXI4_Mux_TestHarness/DUT/write_blk/*
add wave -divider read_blk
add wave /AXI4_Mux_TestHarness/DUT/read_blk/*
wv.cursors.add -time 490ns+0 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 514500ps
wv.time.unit.auto.set
transcript $curr_transcript
