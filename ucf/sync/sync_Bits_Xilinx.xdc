# This XDC file must be directly applied to all instances of sync_Bits_Xilinx.
# To achieve this, set property SCOPED_TO_REF to sync_Bits_Xilinx within the Vivado project.
# Load XDC file defining the clocks before this XDC file by using the property PROCESSING_ORDER.
set_property  ASYNC_REG true  [ get_cells -regexp {gen\[\d+\]\.Sync/FALSE_PATH_gen.METASTABILITY_FF_MAX_DELAY} ]
set_property  ASYNC_REG true  [ get_cells -regexp {gen\[\d+\]\.Sync/FALSE_PATH_gen.METASTABILITY_FF_FALSE_PATH} ]
set_property  ASYNC_REG true  [ get_cells -regexp {gen\[\d+\]\.Sync/gen\[\d+\]\.FF}        ]

set_max_delay             -to [ get_pins -regexp {gen\[\d+\]\.Sync/FALSE_PATH_gen.METASTABILITY_FF_MAX_DELAY/D} ] -datapath_only [ get_property PERIOD [ get_clocks -of_objects [get_pins -regexp {gen\[0\]\.Sync/FALSE_PATH_gen.METASTABILITY_FF_MAX_DELAY/C} ] ] ]
set_false_path -hold      -to [ get_pins -regexp {gen\[\d+\]\.Sync/FALSE_PATH_gen.METASTABILITY_FF_MAX_DELAY/D} ]

set_false_path            -to [ get_pins -regexp {gen\[\d+\]\.Sync/FALSE_PATH_gen.METASTABILITY_FF_FALSE_PATH/D} ]
