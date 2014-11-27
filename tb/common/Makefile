DUT_PATH := ../../src/common
SRCS := my_project.vhdl my_config_ML505.vhdl \
	$(DUT_PATH)/utils.vhdl $(DUT_PATH)/strings.vhdl \
	$(DUT_PATH)/vectors.vhdl $(DUT_PATH)/board.vhdl \
	$(DUT_PATH)/config.vhdl \
	simulation.vhdl \
	config_tb.vhdl

.PHONY: all clean

all: config_tb

%_tb: poc-obj93.cf
	ghdl -e --work=poc $@

poc-obj93.cf: $(SRCS)
	ghdl -a --work=poc $(SRCS) || rm $@

clean:
	rm -f *_tb *.o *.cf *~
