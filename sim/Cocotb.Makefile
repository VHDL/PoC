# Overwrite PWD from environment because current working directory is changed
# within py/Base/Simulator.py (_PrepareSimulationEnvironment)
PWD=$(shell pwd)
POC={PoCRootDirectory}
COCOTB=$(POC)/lib/cocotb
POC_TB=$(POC)/tb

SIM=questa
TOPLEVEL_LANG=vhdl
VHDL_SOURCES ={VHDLSources}

CUSTOM_SIM_DEPS=$(POC)/temp/cocotb/Makefile

RTL_LIBRARY=poc
TOPLEVEL={TopLevel}
MODULE={CocotbModule}
include $(COCOTB)/makefiles/Makefile.inc
include $(COCOTB)/makefiles/Makefile.sim
