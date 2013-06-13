.PHONY: clean

unisim-obj93.cf: unisim_*.vhd *.vhd
	ghdl -a --work=UNISIM $^ || rm $@

clean:
	rm -f *.o *.cf *~
