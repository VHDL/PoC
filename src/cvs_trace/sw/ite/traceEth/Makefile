# Requires JNI headers of used JRE
CPPFLAGS =-I /usr/lib/jvm/java-6-sun-1.6.0.12/include
CPPFLAGS+=-I /usr/lib/jvm/java-6-sun-1.6.0.12/include/linux

CFLAGS=-fpic
LDFLAGS=-shared

# default target
.PHONY: all
all: libTraceEth.so

libTraceEth.so: trace_eth.o
	$(LD) $(LDFLAGS) -o $@ $^

trace_eth.o: libTraceEth.h

# clean up
.PHONY: clean
clean:
	rm -f *.o *.so
