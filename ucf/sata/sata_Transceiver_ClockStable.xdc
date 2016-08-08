# This XDC file must be directly applied to all instances of sata_Transceiver_ClockStable.
# To achieve this, set property SCOPED_TO_REF to sata_Transceiver_ClockStable within the Vivado project.
# Load XDC file defining the clocks before this XDC file by using the property PROCESSING_ORDER.
set_property ASYNC_REG true [get_cells {FF1_METASTABILITY_FFS}]
set_false_path -from [all_clocks] -to  [get_pins {FF1_METASTABILITY_FFS/CLR FF1_METASTABILITY_FFS/D}]
set_false_path -from [all_clocks] -to  [get_pins FF2/CLR]
set_false_path -from [all_clocks] -to  [get_pins FF3/CLR]
set_false_path -from [all_clocks] -to  [get_pins FF4/CLR]
set_false_path -from [all_clocks] -to  [get_pins FF5/CLR]
