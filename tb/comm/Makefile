DUT_PATH := ../../src/comm
SRCS := ../../src/common/utils.vhdl \
	$(DUT_PATH)/comm_scramble.vhdl comm_scramble_tb.vhdl \
	$(DUT_PATH)/comm_crc.vhdl comm_crc_tb.vhdl comm_crc_eth_tb.vhdl

.PHONY: clean

all: comm_crc_tb comm_crc_eth_tb comm_scramble_tb

%_tb: poc-obj93.cf
	ghdl -e --work=poc $@

poc-obj93.cf: $(SRCS)
	ghdl -a --work=poc $(SRCS) || rm $@

clean:
	rm -f *_tb *.o *.cf *~
