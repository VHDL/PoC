
xil_ChipScopeICON
#################

This module wraps 15 ChipScope ICON IPCore netlists generated from ChipScope
ICON xco files. The generic parameter PORTS selects the apropriate ICON
instance with 1 to 15 ICON ControlBus ports. Each ControlBus port is of type
T_XIL_CHIPSCOPE_CONTROL and of mode 'inout'.
PoC IPCore compiler:
------------------------------------
Please use the provided PoC netlist compiler tool to recreate the needed source
and netlist files on your computer.
	cd <PoCRoot>\netlist
	.\netlist.ps1 -rl --coregen PoC.xil.ChipScopeICON_1 --board KC705
	[...]
	.\netlist.ps1 -rl --coregen PoC.xil.ChipScopeICON_15 --board KC705


.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/xil/xil_ChipScopeICON.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 52-59


	 