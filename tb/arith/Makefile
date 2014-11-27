DUT_PATH := ../../src/arith
SRCS := ../common/my_project.vhdl ../common/my_config_ML505.vhdl \
	$(DUT_PATH)/../common/utils.vhdl $(DUT_PATH)/../common/strings.vhdl \
	$(DUT_PATH)/../common/vectors.vhdl $(DUT_PATH)/../common/board.vhdl \
	$(DUT_PATH)/../common/config.vhdl \
	../common/simulation.vhdl \
	$(DUT_PATH)/arith_pkg.vhdl \
	../xilinx/MUXCY.vhd \
	$(DUT_PATH)/arith_prefix_and.vhdl arith_prefix_and_tb.vhdl \
	$(DUT_PATH)/arith_prefix_or.vhdl arith_prefix_or_tb.vhdl \
	$(DUT_PATH)/arith_prng.vhdl arith_prng_tb.vhdl \
	$(DUT_PATH)/arith_addw.vhdl arith_addw_tb.vhdl \
	$(DUT_PATH)/arith_addw_xil.vhdl arith_addw_xil_tb.vhdl

.PHONY: all clean

all: arith_prefix_and_tb arith_prefix_or_tb arith_prng_tb \
     arith_addw_tb arith_addw_xil_tb

%_tb: ../xilinx/unisim-obj93.cf poc-obj93.cf
	ghdl -e --syn-binding --work=poc -P../xilinx $@

../xilinx/unisim-obj93.cf:
	make -C ../xilinx

poc-obj93.cf: $(SRCS)
	ghdl -a --work=poc -P../xilinx $(SRCS) || rm $@

clean:
	rm -f *_tb *.o *.cf *~
