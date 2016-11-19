.. _NS:cache:

PoC.cache
=========

The namespace `PoC.cache` offers different cache implementations.

**Entities**

 * :ref:`IP:cache_mem`: Cache with PoC's "mem" interface based
   on :ref:`IP:cache_par2` and including a cache controller.

 * :ref:`IP:cache_par`: Cache with parallel tag-unit and
   data memory (using infered memory).

 * :ref:`IP:cache_par2`: Cache with parallel tag-unit and
   data memory (using :ref:`IP:ocram_sp`).

 * :ref:`IP:cache_tagunit_par`: Tag-Unit with
   parallel tag comparison. Configurable as:

   * Full-associative cache,
   * Direct-mapped cache, or
   * Set-associative cache.

 * :ref:`IP:cache_tagunit_seq`: Tag-Unit with
   sequential tag comparison. Configurable as:

   * Full-associative cache,
   * Direct-mapped cache, or
   * Set-associative cache.



.. toctree::
   :hidden:

   cache_mem <cache_mem>
   cache_par <cache_par>
   cache_par2 <cache_par2>
   cache_replacement_policy <cache_replacement_policy>
   cache_tagunit_par <cache_tagunit_par>
   cache_tagunit_seq <cache_tagunit_seq>
