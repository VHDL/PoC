set_false_path -to   [get_ports -regexp {Output\[\d\]}]
set_false_path -from [get_ports -regexp {Input\[\d\]}]

set_max_delay -from [get_clocks NET_Clock1] -to [get_clocks NET_Clock2] -datapath_only 5.0

