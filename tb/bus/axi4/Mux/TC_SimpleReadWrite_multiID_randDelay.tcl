onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /AXI4_Mux_TestHarness/AXI4_Manager_Transaction
add wave /AXI4_Mux_TestHarness/AXI4_Subordinate_Transaction
add wave /AXI4_Mux_TestHarness/DUT/Clock
add wave /AXI4_Mux_TestHarness/DUT/Reset
add wave -expand /AXI4_Mux_TestHarness/DUT/In_M2S
add wave -expand /AXI4_Mux_TestHarness/DUT/In_S2M
add wave /AXI4_Mux_TestHarness/DUT/Out_M2S
add wave /AXI4_Mux_TestHarness/DUT/Out_S2M
add wave /AXI4_Mux_TestHarness/DUT/In_M2S_g
add wave /AXI4_Mux_TestHarness/DUT/In_S2M_g
add wave /AXI4_Mux_TestHarness/DUT/Out_M2S_g
add wave /AXI4_Mux_TestHarness/DUT/Out_S2M_g
add wave -divider write_blk
add wave /AXI4_Mux_TestHarness/DUT/write_blk/State
add wave /AXI4_Mux_TestHarness/DUT/write_blk/NextState
add wave /AXI4_Mux_TestHarness/DUT/write_blk/Put
add wave /AXI4_Mux_TestHarness/DUT/write_blk/Full
add wave /AXI4_Mux_TestHarness/DUT/write_blk/DataIn
add wave /AXI4_Mux_TestHarness/DUT/write_blk/IndexOut
add wave /AXI4_Mux_TestHarness/DUT/write_blk/Got
add wave /AXI4_Mux_TestHarness/DUT/write_blk/Valid
add wave /AXI4_Mux_TestHarness/DUT/write_blk/DataOut
add wave /AXI4_Mux_TestHarness/DUT/write_blk/Arbitrate
add wave /AXI4_Mux_TestHarness/DUT/write_blk/RequestVector
add wave /AXI4_Mux_TestHarness/DUT/write_blk/Arbitrated
add wave /AXI4_Mux_TestHarness/DUT/write_blk/GrantVector
add wave /AXI4_Mux_TestHarness/DUT/write_blk/GrantIndex
add wave /AXI4_Mux_TestHarness/DUT/write_blk/RequestWithSelf
add wave /AXI4_Mux_TestHarness/DUT/write_blk/RequestWithoutSelf
add wave /AXI4_Mux_TestHarness/DUT/write_blk/Write_Response_Error
add wave /AXI4_Mux_TestHarness/DUT/write_blk/~ANONYMOUS~0
add wave -divider read_blk
add wave /AXI4_Mux_TestHarness/DUT/read_blk/Mux_In_M2S
add wave /AXI4_Mux_TestHarness/DUT/read_blk/Mux_In_S2M
add wave /AXI4_Mux_TestHarness/DUT/read_blk/Mux_Out_M2S
add wave /AXI4_Mux_TestHarness/DUT/read_blk/Mux_Out_S2M
add wave /AXI4_Mux_TestHarness/DUT/read_blk/Put
add wave /AXI4_Mux_TestHarness/DUT/read_blk/Full
add wave /AXI4_Mux_TestHarness/DUT/read_blk/DataIn
add wave /AXI4_Mux_TestHarness/DUT/read_blk/IndexOut
add wave /AXI4_Mux_TestHarness/DUT/read_blk/Got
add wave /AXI4_Mux_TestHarness/DUT/read_blk/Valid
add wave /AXI4_Mux_TestHarness/DUT/read_blk/Read_idx/IndexIn
add wave /AXI4_Mux_TestHarness/DUT/read_blk/DataOut
add wave -varray DataOut.index \
	/AXI4_Mux_TestHarness/DUT/read_blk/DataOut(5) \
	/AXI4_Mux_TestHarness/DUT/read_blk/DataOut(4) \
	/AXI4_Mux_TestHarness/DUT/read_blk/DataOut(3)
add wave -varray DataOut.return-ID \
	/AXI4_Mux_TestHarness/DUT/read_blk/DataOut(2) \
	/AXI4_Mux_TestHarness/DUT/read_blk/DataOut(1) \
	/AXI4_Mux_TestHarness/DUT/read_blk/DataOut(0)
add wave /AXI4_Mux_TestHarness/DUT/read_blk/~ANONYMOUS~2
wv.cursors.add -time 0fs+0 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.cursors.subcursor.add -time 10ns -name {Cursor 1}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 514500ps
wv.time.unit.auto.set
transcript $curr_transcript
