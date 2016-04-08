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

# list all required Python files here
sim: $(MODULE).py lru_dict.py utils.py sim_build/modelsim.ini

# copy rule(s)
lru_dict.py: $(POC_TB)/common/lru_dict.py
	cp $< $@

utils.py: $(POC_TB)/common/utils.py
	cp $< $@

%.py: $(POC_TB)/sort/%.py
	cp $< $@

sim_build/modelsim.ini:
	mkdir -p sim_build
	cp $(POC)/temp/precompiled/vsim/modelsim.ini $@
