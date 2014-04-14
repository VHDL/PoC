DUT_PATH := ../../../src/mem/ocram
SRCS := ../../../src/common/functions.vhdl \
	config_v5.vhdl \
	$(DUT_PATH)/ocram.vhdl \
	$(DUT_PATH)/ocram_sdp.vhdl ocram_sdp_tb.vhdl \
	$(DUT_PATH)/ocram_wb.vhdl ocram_wb_tb.vhdl \
	$(DUT_PATH)/ocrom_chain.vhdl ocrom_chain_tb.vhdl

.PHONY: clean

all: ocram_sdp_tb ocram_wb_tb ocrom_chain_tb

%_tb: poc-obj93.cf
	ghdl -e -P../../xilinx --work=poc $@

poc-obj93.cf: ../../xilinx/unisim-obj93.cf $(SRCS)
	ghdl -a -P../../xilinx --work=poc $(SRCS) || rm $@

../../xilinx/unisim-obj93.cf:
	make -C ../../xilinx $(notdir $@)

clean:
	rm -f *_tb *.o *.cf *~
