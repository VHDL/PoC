DUT_PATH := ../../src/misc
SRCS := ../common/my_project.vhdl ../common/my_config_ML505.vhdl \
        $(DUT_PATH)/../common/utils.vhdl \
	$(DUT_PATH)/misc_bit_lz.vhdl misc_bit_lz_tb.vhdl

.PHONY: clean

all: misc_bit_lz_tb

%_tb: poc-obj93.cf
	ghdl -e --work=poc $@

poc-obj93.cf: $(SRCS)
	ghdl -a --work=poc $(SRCS) || rm $@

clean:
	rm -f *_tb *.o *.cf *~
