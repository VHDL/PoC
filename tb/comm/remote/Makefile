SRCS := ../../../src/common/functions.vhdl \
	../../../src/io/uart/uart.vhdl \
	../../../src/io/uart/uart_bclk.vhdl \
	../../../src/io/uart/uart_rx.vhdl \
	../../../src/io/uart/uart_tx.vhdl \
	../../../src/comm/remote/remote_terminal_control.vhdl \
	remote_terminal_control_tb.vhdl

.PHONY: clean

all: remote_terminal_control_tb

%_tb: poc-obj93.cf
	ghdl -e --work=poc $@

poc-obj93.cf: $(SRCS)
	ghdl -a --work=poc $(SRCS) || rm $@

clean:
	rm -f *_tb *.o *.cf *~
