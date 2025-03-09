analyze ./sync.pkg.vhdl

if { [info exists ::OMIT_XILINX_FILES] && $::OMIT_XILINX_FILES eq "1"} {
	puts "Skip xilinx file."
} else {
	analyze ./sync_Bits_Xilinx.vhdl
	analyze ./sync_Reset_Xilinx.vhdl
	analyze ./sync_Pulse_Xilinx.vhdl
}
analyze ./sync_Bits.vhdl
analyze ./sync_Reset.vhdl
#analyze ./sync_Pulse.vhdl

analyze ./sync_Strobe.vhdl
analyze ./sync_Vector.vhdl
analyze ./sync_Command.vhdl
