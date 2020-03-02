# This XDC file must be directly applied to all instances of sync_Resets.
# To achieve this, set property SCOPED_TO_REF to sync_Reset within the Vivado project.
# Load XDC file defining the clocks before this XDC file by using the property PROCESSING_ORDER.
set_property ASYNC_REG true [ get_cells {Data_meta_reg}    ]
set_property ASYNC_REG true [ get_cells {Data_sync_reg[0]} ]

set_max_delay                     -to [ get_pins {Data_meta_reg/D} ] [ get_property PERIOD [ get_clocks -of_objects [ get_pins {Data_meta_reg/C} ] ] ]

set_false_path -from [all_clocks] -to [ get_pins {Data_meta_reg/PRE}  ]
set_false_path -from [all_clocks] -to [ get_pins {Data_sync_reg*/PRE} ]
