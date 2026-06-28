onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /axi4_Mux_TestHarness/AXI4_Manager_Transaction
add wave /axi4_Mux_TestHarness/AXI4_Subordinate_Transaction
add wave /axi4_Mux_TestHarness/DUT/Clock
add wave /axi4_Mux_TestHarness/DUT/Reset
add wave -expand /axi4_Mux_TestHarness/DUT/In_M2S
add wave -expand /axi4_Mux_TestHarness/DUT/In_S2M
add wave /axi4_Mux_TestHarness/DUT/Out_M2S
add wave /axi4_Mux_TestHarness/DUT/Out_S2M
add wave /axi4_Mux_TestHarness/DUT/In_M2S_g
add wave /axi4_Mux_TestHarness/DUT/In_S2M_g
add wave /axi4_Mux_TestHarness/DUT/Out_M2S_g
add wave /axi4_Mux_TestHarness/DUT/Out_S2M_g
add wave -divider write_blk
add wave /axi4_Mux_TestHarness/DUT/write_blk/State
add wave /axi4_Mux_TestHarness/DUT/write_blk/NextState
add wave /axi4_Mux_TestHarness/DUT/write_blk/Put
add wave /axi4_Mux_TestHarness/DUT/write_blk/Full
add wave /axi4_Mux_TestHarness/DUT/write_blk/DataIn
add wave /axi4_Mux_TestHarness/DUT/write_blk/IndexOut
add wave /axi4_Mux_TestHarness/DUT/write_blk/Got
add wave /axi4_Mux_TestHarness/DUT/write_blk/Valid
add wave /axi4_Mux_TestHarness/DUT/write_blk/DataOut
add wave /axi4_Mux_TestHarness/DUT/write_blk/Arbitrate
add wave /axi4_Mux_TestHarness/DUT/write_blk/RequestVector
add wave /axi4_Mux_TestHarness/DUT/write_blk/Arbitrated
add wave /axi4_Mux_TestHarness/DUT/write_blk/GrantVector
add wave /axi4_Mux_TestHarness/DUT/write_blk/GrantIndex
add wave /axi4_Mux_TestHarness/DUT/write_blk/RequestWithSelf
add wave /axi4_Mux_TestHarness/DUT/write_blk/RequestWithoutSelf
add wave /axi4_Mux_TestHarness/DUT/write_blk/Write_Response_Error
add wave /axi4_Mux_TestHarness/DUT/write_blk/~ANONYMOUS~0
add wave -divider read_blk
add wave /axi4_Mux_TestHarness/DUT/read_blk/Mux_In_M2S
add wave /axi4_Mux_TestHarness/DUT/read_blk/Mux_In_S2M
add wave /axi4_Mux_TestHarness/DUT/read_blk/Mux_Out_M2S
add wave /axi4_Mux_TestHarness/DUT/read_blk/Mux_Out_S2M
add wave /axi4_Mux_TestHarness/DUT/read_blk/Put
add wave /axi4_Mux_TestHarness/DUT/read_blk/Full
add wave /axi4_Mux_TestHarness/DUT/read_blk/DataIn
add wave /axi4_Mux_TestHarness/DUT/read_blk/IndexOut
add wave /axi4_Mux_TestHarness/DUT/read_blk/Got
add wave /axi4_Mux_TestHarness/DUT/read_blk/Valid
add wave /axi4_Mux_TestHarness/DUT/read_blk/Read_idx/IndexIn
add wave /axi4_Mux_TestHarness/DUT/read_blk/DataOut
add wave -varray DataOut.index \
	/axi4_Mux_TestHarness/DUT/read_blk/DataOut(5) \
	/axi4_Mux_TestHarness/DUT/read_blk/DataOut(4) \
	/axi4_Mux_TestHarness/DUT/read_blk/DataOut(3)
add wave -varray DataOut.return-ID \
	/axi4_Mux_TestHarness/DUT/read_blk/DataOut(2) \
	/axi4_Mux_TestHarness/DUT/read_blk/DataOut(1) \
	/axi4_Mux_TestHarness/DUT/read_blk/DataOut(0)
add wave /axi4_Mux_TestHarness/DUT/read_blk/~ANONYMOUS~2
wv.cursors.add -time 0fs+0 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.cursors.subcursor.add -time 10ns -name {Cursor 1}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 514500ps
wv.time.unit.auto.set
transcript $curr_transcript
