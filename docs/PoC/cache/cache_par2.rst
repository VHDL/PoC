
cache_par2
##########

Cache with parallel tag-unit and data memory. For the data memory,
:doc:`PoC.mem.ocram.sp <../mem/ocram/ocram_sp>` is used.

All inputs are synchronous to the rising-edge of the clock `clock`.

**Command truth table:**

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

All commands use ``Address`` to lookup (request) or replace a cache line.
``Address`` and ``OldAddress`` do not include the word/byte select part.
Each command is completed within one clock cycle, but outputs are delayed as
described below.

Upon requests, the outputs ``CacheMiss`` and ``CacheHit`` indicate (high-active)
whether the ``Address`` is stored within the cache, or not. Both outputs have a
latency of one clock cycle.

Upon writing a cache line, the new content is given by ``CacheLineIn``.
Upon reading a cache line, the current content is outputed on ``CacheLineOut``
with a latency of one clock cycle.

Replacing a cache line requires two steps:

1. Read old contents of cache line by setting ``ReadWrite`` to '0'. The old
   content is outputed on ``CacheLineOut`` and the old tag on ``OldAddress``,
   both with a latency of one clock cycle.

2. Write new cache line by setting ``ReadWrite`` to '1'. The new content is
   given by ``CacheLineIn``.



.. rubric:: Entity Declaration:

.. literalinclude:: ../../../src/cache/cache_par2.vhdl
   :language: vhdl
   :tab-width: 2
   :linenos:
   :lines: 86-110

Source file: `cache/cache_par2.vhdl <https://github.com/VLSI-EDA/PoC/blob/master/src/cache/cache_par2.vhdl>`_



