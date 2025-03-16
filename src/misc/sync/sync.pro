analyze ./sync.pkg.vhdl

if { $::poc::vendor eq "Xilinx" } {
	analyze ./sync_Bits_Xilinx.vhdl
	analyze ./sync_Reset_Xilinx.vhdl
	analyze ./sync_Pulse_Xilinx.vhdl

} elseif { $::poc::vendor eq "Altera" } {
	analyze ./sync_Bits_Altera.vhdl
	analyze ./sync_Reset_Altera.vhdl
	analyze ./sync_Pulse_Altera.vhdl

} elseif { $::poc::vendor ne "GENERIC" } {
	puts "Unknow vendor '$::poc::vendor' in arith!"
	exit 1
}

analyze ./sync_Bits.vhdl
analyze ./sync_Reset.vhdl
analyze ./sync_Pulse.vhdl

analyze ./sync_Strobe.vhdl
analyze ./sync_Vector.vhdl
analyze ./sync_Command.vhdl
