DUT_PATH := ../../src/arith
SRCS := ../common/my_project.vhdl ../common/my_config_ML505.vhdl \
	$(DUT_PATH)/../common/utils.vhdl $(DUT_PATH)/../common/strings.vhdl \
	$(DUT_PATH)/../common/vectors.vhdl $(DUT_PATH)/../common/board.vhdl \
	$(DUT_PATH)/../common/config.vhdl \
	../common/simulation.vhdl \
	../xilinx/LUT6_2.vhd ../xilinx/MUXCY.vhd ../xilinx/XORCY.vhd \
	$(DUT_PATH)/arith_pkg.vhdl \
	$(DUT_PATH)/arith_prefix_and.vhdl arith_prefix_and_tb.vhdl \
	$(DUT_PATH)/arith_prefix_or.vhdl arith_prefix_or_tb.vhdl \
	$(DUT_PATH)/arith_prng.vhdl arith_prng_tb.vhdl \
	$(DUT_PATH)/arith_addw.vhdl arith_addw_tb.vhdl

.PHONY: all clean

all: arith_prefix_and_tb arith_prefix_or_tb arith_prng_tb arith_addw_tb

%_tb: poc-obj93.cf
	ghdl -e --work=poc $@

poc-obj93.cf: $(SRCS)
	ghdl -a --work=poc $(SRCS) || rm $@

clean:
	rm -f *_tb *.o *.cf *~
