onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /AXI4_Demux_TestHarness/DUT/Clock
add wave /AXI4_Demux_TestHarness/DUT/Reset
add wave /AXI4_Demux_TestHarness/DUT/In_M2S
add wave /AXI4_Demux_TestHarness/DUT/In_S2M
add wave /AXI4_Demux_TestHarness/DUT/Out_M2S
add wave /AXI4_Demux_TestHarness/DUT/Out_S2M
add wave /AXI4_Demux_TestHarness/DUT/In_M2S_g
add wave /AXI4_Demux_TestHarness/DUT/In_S2M_g
add wave /AXI4_Demux_TestHarness/DUT/Out_M2S_g
add wave /AXI4_Demux_TestHarness/DUT/Out_S2M_g
add wave -divider write_blk
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Address_hit
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Mux_In_M2S
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Mux_In_S2M
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Mux_Out_M2S
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Mux_Out_S2M
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Response_fifo_put
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Response_fifo_ful
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Response_fifo_got
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Response_fifo_dout
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Response_fifo_vld
add wave /AXI4_Demux_TestHarness/DUT/write_blk/State
add wave /AXI4_Demux_TestHarness/DUT/write_blk/NextState
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Put
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Full
add wave /AXI4_Demux_TestHarness/DUT/write_blk/IndexOut
add wave /AXI4_Demux_TestHarness/DUT/write_blk/Write_Response_Error
add wave -divider read_blk
add wave /AXI4_Demux_TestHarness/DUT/read_blk/Address_hit
add wave /AXI4_Demux_TestHarness/DUT/read_blk/DeMux_In_M2S
add wave /AXI4_Demux_TestHarness/DUT/read_blk/DeMux_In_S2M
add wave /AXI4_Demux_TestHarness/DUT/read_blk/DeMux_Out_M2S
add wave /AXI4_Demux_TestHarness/DUT/read_blk/DeMux_Out_S2M
add wave /AXI4_Demux_TestHarness/DUT/read_blk/Mux_In_M2S
add wave /AXI4_Demux_TestHarness/DUT/read_blk/Mux_In_S2M
add wave /AXI4_Demux_TestHarness/DUT/read_blk/Mux_Out_M2S
add wave /AXI4_Demux_TestHarness/DUT/read_blk/Mux_Out_S2M
add wave /AXI4_Demux_TestHarness/DUT/read_blk/Response_fifo_put
add wave /AXI4_Demux_TestHarness/DUT/read_blk/Response_fifo_ful
add wave /AXI4_Demux_TestHarness/DUT/read_blk/Response_fifo_got
add wave /AXI4_Demux_TestHarness/DUT/read_blk/Response_fifo_dout
add wave /AXI4_Demux_TestHarness/DUT/read_blk/Response_fifo_vld
wv.cursors.add -time 255ns+0 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 514500ps
wv.time.unit.auto.set
transcript $curr_transcript
