DUT_PATH := ../../src/arith
SRCS := ../common/my_config_ML505.vhdl \
	$(DUT_PATH)/../common/utils.vhdl $(DUT_PATH)/../common/strings.vhdl \
	$(DUT_PATH)/../common/vectors.vhdl $(DUT_PATH)/../common/board.vhdl \
	$(DUT_PATH)/../common/config.vhdl \
	../xilinx/MUXCY.vhd \
	../common/simulation.vhdl \
	$(DUT_PATH)/arith_prefix_and.vhdl arith_prefix_and_tb.vhdl \
	$(DUT_PATH)/arith_prefix_or.vhdl arith_prefix_or_tb.vhdl

.PHONY: all clean

all: arith_prefix_and_tb arith_prefix_or_tb

%_tb: poc-obj93.cf
	ghdl -e --work=poc $@

poc-obj93.cf: $(SRCS)
	ghdl -a --work=poc $(SRCS) || rm $@

clean:
	rm -f *_tb *.o *.cf *~
