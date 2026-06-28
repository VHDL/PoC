onerror { resume }
set curr_transcript [transcript]
transcript off

add wave /tb_axi4stream_mux/DUT/Clock
add wave /tb_axi4stream_mux/DUT/Reset
add wave /tb_axi4stream_mux/DUT/MuxControl
add wave /tb_axi4stream_mux/DUT/In_M2S
add wave /tb_axi4stream_mux/DUT/In_S2M
add wave /tb_axi4stream_mux/DUT/Out_M2S
add wave /tb_axi4stream_mux/DUT/Out_S2M
add wave /tb_axi4stream_mux/DUT/State
add wave /tb_axi4stream_mux/DUT/NextState
add wave /tb_axi4stream_mux/DUT/FSM_Dataflow_en
add wave /tb_axi4stream_mux/DUT/RequestVector
add wave /tb_axi4stream_mux/DUT/RequestWithSelf
add wave /tb_axi4stream_mux/DUT/RequestWithoutSelf
add wave /tb_axi4stream_mux/DUT/RequestLeft
add wave /tb_axi4stream_mux/DUT/SelectLeft
add wave /tb_axi4stream_mux/DUT/SelectRight
add wave /tb_axi4stream_mux/DUT/ChannelPointer_en
add wave /tb_axi4stream_mux/DUT/ChannelPointer
add wave /tb_axi4stream_mux/DUT/ChannelPointer_d
add wave /tb_axi4stream_mux/DUT/ChannelPointer_nxt
add wave /tb_axi4stream_mux/DUT/ChannelPointer_bin
add wave /tb_axi4stream_mux/DUT/idx
add wave /tb_axi4stream_mux/DUT/Out_Last_i
wv.cursors.add -time 1090ns+4 -name {Default cursor}
wv.cursors.setactive -name {Default cursor}
wv.zoom.range -from 0fs -to 300ns
wv.time.unit.auto.set
transcript $curr_transcript
