DUT_PATH := ../../src/misc
SRCS := ../../src/common/utils.vhdl \
	$(DUT_PATH)/scaler.vhdl scaler_tb.vhdl

.PHONY: clean

all: scaler_tb

%_tb: poc-obj93.cf
	ghdl -e --work=poc $@

poc-obj93.cf: $(SRCS)
	ghdl -a --work=poc $(SRCS) || rm $@

clean:
	rm -f *_tb *.o *.cf *~
