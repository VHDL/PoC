set_false_path -to   [get_ports -regexp {Output\[\d\]}]
set_false_path -from [get_ports -regexp {Input\[\d\]}]

#set_property ASYNC_REG true [get_cells {test_1/genXilinx.sync/gen[0].Sync/FF2}]
#set_property ASYNC_REG true [get_cells {test_1/genXilinx.sync/gen[0].Sync/FF1_METASTABILITY_FFS}]
#set_clock_groups -asynchronous -group [get_clocks NET_Clock1] -group [get_clocks NET_Clock2]
