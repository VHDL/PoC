
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

+--------------------+----------------------------------------------------+
| Parameter          | Description                                        |
+====================+====================================================+
| REPLACEMENT_POLICY | Replacement policy of embedded cache. For supported|
|                    | values see PoC.cache_replacement_policy.           |
+--------------------+----------------------------------------------------+
| CACHE_LINES        | Number of cache lines.                             |
+--------------------+----------------------------------------------------+
| ASSOCIATIVITY      | Associativity of embedded cache.                   |
+--------------------+----------------------------------------------------+
| ADDR_BITS          | Number of bits of full memory address, including   |
|                    | byte address bits.                                 |
+--------------------+----------------------------------------------------+
| DATA_BITS          | Size of a cache line in bits. Equals also the size |
|                    | of the read and write data ports of the CPU and    |
|                    | memory side. DATA_BITS must be divisible by 8.     |
+--------------------+----------------------------------------------------+


Operation
*********

A synchronous reset must be applied even on a FPGA.

The interface is documented in detail :doc:`here </Interfaces/Memory>`.

The write policy is: write-through, no-write-allocate.



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/cache/cache_mem.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 75-107

Source file: `cache/cache_mem.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/cache/cache_mem.vhdl>`_



