This directory contains HDL source files for controlling the 
ISSI IS61LV* SRAMs.

Directories:
------------

rtl/		FPGA independent VHDL source files
rtl_xilinx	VHDL source files for Xilinx FPGAs
tests		Hardware tests (see README there).

Memory Controller files:
------------------------

is61lv_ctrl.vhdl	Memory controller with simple interface.
is61lv_ctrl_wb.vhdl	Wishbone adapter for is61lv_ctrl.

Sample Tests:
--------------------

subdir s3sk		Memory test Spartan-3 Starter Kit Board.
