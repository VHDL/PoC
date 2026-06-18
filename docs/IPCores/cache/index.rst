.. _NS/cache:

PoC.cache
=========

The namespace `PoC.cache` offers different cache implementations.

**Entities**

 * :ref:`IP/cache_CPU`: Cache with cache controller to be used within a CPU.

 * :ref:`IP/cache_Memory`: Cache with :ref:`INT:PoC.Memory` interface on the "CPU" side.

 * :ref:`IP/cache_Parallel`: Cache with parallel tag-unit and data memory (using infered memory).

 * :ref:`IP/cache_Parallel2`: Cache with parallel tag-unit and data memory (using :ref:`IP/ocram_SinglePort`).

 * :ref:`IP/cache_TagUnit_Parallel`: Tag-Unit with parallel tag comparison. Configurable as:
* Full-associative cache,
* Direct-mapped cache, or
* Set-associative cache.

 * :ref:`IP/cache_TagUnit_Sequential`: Tag-Unit with sequential tag comparison. Configurable as:

* Full-associative cache,
* Direct-mapped cache, or
* Set-associative cache.



.. toctree::
:hidden:

   cache_CPU <cache_CPU>
   cache_Memory <cache_Memory>
   cache_Parallel <cache_Parallel>
   cache_Parallel2 <cache_Parallel2>
   cache_ReplacementPolicy <cache_ReplacementPolicy>
   cache_TagUnit_Parallel <cache_TagUnit_Parallel>
   cache_TagUnit_Sequential <cache_TagUnit_Sequential>
