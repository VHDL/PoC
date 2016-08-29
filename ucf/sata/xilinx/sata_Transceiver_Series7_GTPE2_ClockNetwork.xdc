# This XDC file must be directly applied to all instances of sata_Transceiver_Series7_GTPE2_ClockNetwork.
# To achieve this, set property SCOPED_TO_REF to sata_Transceiver_Series7_GTPE2_ClockNetwork within the Vivado project.
# Load XDC file defining the clocks before this XDC file by using the property PROCESSING_ORDER.

# create_generated_clock -name CLK_SATA_ControlClock [get_pins {ClockIn_150MHz}]
create_generated_clock -name CLK_SATA_FeedThrough  [get_pins SATA_MMCM/CLKOUT0]
create_generated_clock -name CLK_SATAClock_2X      [get_pins SATA_MMCM/CLKOUT1]
create_generated_clock -name CLK_SATAClock_4X      [get_pins SATA_MMCM/CLKOUT2]
