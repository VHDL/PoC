# This XDC file must be directly applied to all instances of fifo_ic_got.
# To achieve this, set property SCOPED_TO_REF to fifo_ic_got within the Vivado project.
# Load XDC file defining the clocks before this XDC file by using the property PROCESSING_ORDER.

# set max delay between regfile write and read side lower clock period
set_max_delay  -from [get_cells -regexp {gSmall\.regfile.*|gLarge\.ram/gInfer.ram_reg.*}] \
                 -to [get_cells -regexp {gSmall\.do_reg\[\d+\]|gLarge\.ram/gInfer\.q_reg\[\d+\]}] \
      -datapath_only [expr "min([get_property period [get_clocks -of_objects [get_pins {IP0_reg[0]/C}]]], [get_property period [get_clocks -of_objects [get_pins {OP0_reg[0]/C}]]])"]
