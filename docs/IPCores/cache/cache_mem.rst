
cache_mem
#########

This unit provides a cache (:doc:`PoC.cache.par2 <cache_par2>`) together
with a cache controller which reads / writes cache lines from / to memory.
It has two :doc:`PoC.Mem </Interfaces/Memory>` interfaces:

* one for the "CPU" side  (ports with prefix ``cpu_``), and
* one for the memory side (ports with prefix ``mem_``).

Thus, this unit can be placed into an already available memory path between
the CPU and the memory (controller).


Configuration
*************

+--------------------+-----------------------------------------------------+
| Parameter          | Description                                         |
+====================+=====================================================+
| REPLACEMENT_POLICY | Replacement policy of embedded cache. For supported |
|                    | values see PoC.cache_replacement_policy.            |
+--------------------+-----------------------------------------------------+
| CACHE_LINES        | Number of cache lines.                              |
+--------------------+-----------------------------------------------------+
| ASSOCIATIVITY      | Associativity of embedded cache.                    |
+--------------------+-----------------------------------------------------+
| CPU_ADDR_BITS      | Number of address bits on the CPU side. Each address|
|                    | identifies one memory word as seen from the CPU.    |
|                    | Calculated from other parameters as described below.|
+--------------------+-----------------------------------------------------+
| CPU_DATA_BITS      | Width of the data bus (in bits) on the CPU side.    |
|                    | CPU_DATA_BITS must be divisible by 8.               |
+--------------------+-----------------------------------------------------+
| MEM_ADDR_BITS      | Number of address bits on the memory side. Each     |
|                    | address identifies one word in the memory.          |
+--------------------+-----------------------------------------------------+
| MEM_DATA_BITS      | Width of a memory word and of a cache line in bits. |
|                    | MEM_DATA_BITS must be divisible by CPU_DATA_BITS.   |
+--------------------+-----------------------------------------------------+

If the CPU data-bus width is smaller than the memory data-bus width, then
the CPU needs additional address bits to identify one CPU data word inside a
memory word. Thus, the CPU address-bus width is calculated from:

  ``CPU_ADDR_BITS=log2ceil(CPU_DATA_BITS/MEM_DATA_BITS)+MEM_ADDR_BITS``


Operation
*********

Memory accesses are always aligned to a word boundary. Each memory word
(and each cache line) consists of MEM_DATA_BITS bits.
For example if MEM_DATA_BITS=128:

* memory address 0 selects the bits   0..127 in memory,
* memory address 1 selects the bits 128..256 in memory, and so on.

Cache accesses are always aligned to a CPU word boundary. Each CPU word
consists of CPU_DATA_BITS bits. For example if CPU_DATA_BITS=32:

* CPU address 0 selects the bits   0.. 31 in memory word 0,
* CPU address 2 selects the bits  32.. 63 in memory word 0,
* CPU address 3 selects the bits  64.. 95 in memory word 0,
* CPU address 4 selects the bits  96..127 in memory word 0,
* CPU address 5 selects the bits   0.. 31 in memory word 1,
* CPU address 6 selects the bits  32.. 63 in memory word 1, and so on.

A synchronous reset must be applied even on a FPGA.

The interface is documented in detail :doc:`here </Interfaces/Memory>`.

The write policy is: write-through, no-write-allocate.



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/cache/cache_mem.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 107-140

Source file: `cache/cache_mem.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/cache/cache_mem.vhdl>`_



