##	Bank:						15
##		VCCO:					2.5V (VCC2V5_FPGA)
##	Location:				J11, J12
set_property PACKAGE_PIN		L25				[get_ports KC705_SMAClock_p]
set_property PACKAGE_PIN		K25				[get_ports KC705_SMAClock_n]
# set I/O standard
set_property IOSTANDARD			LVDS_25				[get_ports -regexp {KC705_SMAClock_.}]
