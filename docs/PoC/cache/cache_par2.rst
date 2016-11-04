
cache_par2
##########

Cache with parallel tag-unit and data memory. For the data memory,
:doc:`PoC.mem.ocram.sp <../mem/ocram/ocram_sp>` is used.

Configuration
*************

+--------------------+----------------------------------------------------+
| Parameter          | Description                                        |
+====================+====================================================+
| REPLACEMENT_POLICY | Replacement policy of embedded cache.              |
+--------------------+----------------------------------------------------+
| CACHE_LINES        | Number of cache lines.                             |
+--------------------+----------------------------------------------------+
| ASSOCIATIVITY      | Associativity of embedded cache.                   |
+--------------------+----------------------------------------------------+
| ADDR_BITS          | Number of bits of full memory address, including   |
|                    | byte address bits.                                 |
+--------------------+----------------------------------------------------+
| BYTE_ADDR_BITS     | Number of byte address bits in full memory address.|
|                    | Can be zero if byte addressing is not required.    |
+--------------------+----------------------------------------------------+
| DATA_BITS          | Size of a cache line in bits. Equals also the size |
|                    | of the read and write data ports of the CPU and    |
|                    | memory side. DATA_BITS must be divisible by        |
|                    | 2**BYTE_ADDR_BITS.                                 |
+--------------------+----------------------------------------------------+


Command truth table
*******************

+---------+-----------+-------------+---------+---------------------------------+
| Request | ReadWrite | Invalidate  | Replace | Command                         |
+=========+===========+=============+=========+=================================+
|  0      |    0      |    0        |    0    | None                            |
+---------+-----------+-------------+---------+---------------------------------+
|  1      |    0      |    0        |    0    | Read cache line                 |
+---------+-----------+-------------+---------+---------------------------------+
|  1      |    1      |    0        |    0    | Update cache line               |
+---------+-----------+-------------+---------+---------------------------------+
|  1      |    0      |    1        |    0    | Read cache line and discard it  |
+---------+-----------+-------------+---------+---------------------------------+
|  1      |    1      |    1        |    0    | Write cache line and discard it |
+---------+-----------+-------------+---------+---------------------------------+
|  0      |    0      |    0        |    1    | Read cache line before replace. |
+---------+-----------+-------------+---------+---------------------------------+
|  0      |    1      |    0        |    1    | Replace cache line.             |
+---------+-----------+-------------+---------+---------------------------------+


Operation
*********

All inputs are synchronous to the rising-edge of the clock `clock`.

All commands use ``Address`` to lookup (request) or replace a cache line.
``Address`` and ``OldAddress`` do not include the word/byte select part.
Each command is completed within one clock cycle, but outputs are delayed as
described below.

Upon requests, the outputs ``CacheMiss`` and ``CacheHit`` indicate (high-active)
whether the ``Address`` is stored within the cache, or not. Both outputs have a
latency of one clock cycle (pipelined) if ``HIT_MISS_REG`` is true, otherwise the
result is outputted immediately (combinational).

Upon writing a cache line, the new content is given by ``CacheLineIn``.
Upon reading a cache line, the current content is outputed on ``CacheLineOut``
with a latency of one clock cycle.

Replacing a cache line requires two steps:

1. Read old contents of cache line by setting ``ReadWrite`` to '0'. The old
   content is outputed on ``CacheLineOut`` and the old tag on ``OldAddress``,
   both with a latency of one clock cycle.

2. Write new cache line by setting ``ReadWrite`` to '1'. The new content is
   given by ``CacheLineIn``.

.. TODO::
   * Allow partial update of cache line (byte write enable).



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/cache/cache_par2.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 120-146

Source file: `cache/cache_par2.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/cache/cache_par2.vhdl>`_



