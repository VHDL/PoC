set_false_path -to   [get_ports {full valid}]
set_false_path -to   [get_ports -regexp {dout\[\d+\]}]
set_false_path -from [get_ports {put got rst_rd rst_wr}]
set_false_path -from [get_ports -regexp {din\[\d\]}]
