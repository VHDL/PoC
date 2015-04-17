This directory contains HDL source files for controlling the 
ISSI IS61NLP* synchronous SRAMs.

Directories:
------------

rtl/		FPGA independent VHDL source files
test/		Memory tests.

Memory Controller files:
------------------------

is61nlp_ctrl.vhdl	Memory controller with simple interface.
is61nlp_ctrl_wb.vhdl	Wishbone adapter for is61nlp_ctrl.
