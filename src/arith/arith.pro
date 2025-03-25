# =============================================================================
# Authors:
#	Adrian Weiland

analyze ./arith.pkg.vhdl

if { $::poc::vendor eq "Xilinx" } {
	analyze ./xilinx/arith_carrychain_inc_xilinx.vhdl
	analyze ./xilinx/arith_cca_xilinx.vhdl
	analyze ./xilinx/arith_addw_xilinx.vhdl
	analyze ./xilinx/arith_inc_ovcy_xilinx.vhdl
	analyze ./xilinx/arith_prefix_and_xilinx.vhdl
	analyze ./xilinx/arith_prefix_or_xilinx.vhdl

} elseif { $::poc::vendor eq "Altera" } {
	puts "No Altera files for arith."

} elseif { $::poc::vendor ne "GENERIC" } {
	puts "Unknow vendor '$::poc::vendor' in arith!"
	exit 1
}

analyze ./arith_addw.vhdl
analyze ./arith_carrychain_inc.vhdl
analyze ./arith_convert_bin2bcd.vhdl
analyze ./arith_counter_bcd.vhdl
analyze ./arith_counter_free.vhdl
analyze ./arith_counter_gray.vhdl
analyze ./arith_counter_ring.vhdl
analyze ./arith_div.vhdl
analyze ./arith_firstone.vhdl
analyze ./arith_prefix_and.vhdl
analyze ./arith_prefix_or.vhdl
analyze ./arith_prng.vhdl
analyze ./arith_same.vhdl
analyze ./arith_scaler.vhdl
analyze ./arith_shifter_barrel.vhdl
