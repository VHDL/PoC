--
-- Copyright (c) 2007
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
--
-- Authors: Thomas B. Preusser, Martin Zabel, Peter Reichel
--
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

-----------------------------------------------------------------------------
-- Configuration for Top-Level SHAP-Module
--
--   Target: ml505
--
-- Excerpt from original file
-----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

package config is
  ---------------------------------------------------------------------------
  -- CPU setup
  constant CORE_CNT     : positive := 1;
  constant STK_BLOCKS   : positive := 32;  -- Block Count in Stack Module
  constant STK_OFS_BITS : positive := 6;   -- Block Size within Stack Module

  constant JPC_BITS     : positive := 11;  -- JPC Width = Maximum Method Size

  -- Also update zpu_pgc/sys_config.h and jvm/main.asm
  constant ALIGNMENT    : natural  := 2;   -- Alignment of Objects on Heap
  constant BIAS_BITS    : positive := 8;   -- BIAS_BITS of mmu
  constant OFFS_BITS    : positive := 14;  -- OFFS_BITS of mmu
  constant REF_BITS     : positive := 13;  -- REF_BITS of mmu
  constant SEG_OFFS     : positive := 14;  -- SEG_OFFS of mmu

  constant MEM_ADDR_BITS : positive := 18;
  constant BASE_BITS     : positive := MEM_ADDR_BITS-ALIGNMENT;

  -----------------------------------------------------------------------------
  -- Tracing Mode  (new, from Stefan Alex)

  -- error-correction
  constant TRC_METHOD              : boolean := false;
  constant TRC_GC_REF              : boolean := false;
  constant TRC_MM_MOV              : boolean := false;
  constant TRC_THREAD              : boolean := false;
  constant TRC_BYTECODE            : boolean := true;
  constant TRC_MICROCODE           : boolean := false;

  -- benchmarks
  constant TRC_BYTECODE_LENGTH     : boolean := false;
  constant TRC_METHOD_CACHE_METRIC : boolean := false;
  constant TRC_MEM                 : boolean := false;

  -- others
  constant TRC_WISHBONE            : boolean := false;
  constant TRC_MMU                 : boolean := false;
  constant TRC_MC                  : boolean := false;

end config;

package body config is
end config;
