--
-- Copyright (c) 2008-2012
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Package: fifo
-- Author(s): Martin Zabel       <martin.zabel@tu-dresden.de>
--            Thomas B. Preusser <thomas.preusser@tu-dresden.de>
-- 
-- Component declarations for various FIFO types.
--
-- Revision:    $Revision: 1.28 $
-- Last change: $Date: 2013-08-06 12:35:14 $
--
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library poc;
use poc.functions.all;

package fifo is

  -- Minimal FIFO with single clock to decouple enable domains.
  component fifo_glue
    generic (
      D_BITS : positive                   -- Data Width
    );
    port (
      -- Control
      clk : in std_logic;                 -- Clock
      rst : in std_logic;                 -- Synchronous Reset

      -- Input
      put : in  std_logic;                            -- Put Value
      di  : in  std_logic_vector(D_BITS-1 downto 0);  -- Data Input
      ful : out std_logic;                            -- Full

      -- Output
      vld : out std_logic;                            -- Data Available
      do  : out std_logic_vector(D_BITS-1 downto 0);  -- Data Output
      got : in  std_logic                             -- Data Consumed
    );
  end component;

  -- Minimal Local-Link-FIFO with single clock and first-word-fall-through mode. 
  component fifo_ll_glue
    generic (
      D_BITS          : positive;
      FRAME_USER_BITS : natural;
      REGISTER_PATH   : boolean
      ); 
    port (
      clk   : in std_logic;
      reset : in std_logic;

      -- in port
      sof_in        : in  std_logic;
      data_in       : in  std_logic_vector(D_BITS downto 1);
      frame_data_in : in  std_logic_vector(imax(1, FRAME_USER_BITS) downto 1);
      eof_in        : in  std_logic;
      src_rdy_in    : in  std_logic;
      dst_rdy_in    : out std_logic;

      -- out port
      sof_out        : out std_logic;
      data_out       : out std_logic_vector(D_BITS downto 1);
      frame_data_out : out std_logic_vector(imax(1, FRAME_USER_BITS) downto 1);
      eof_out        : out std_logic;
      src_rdy_out    : out std_logic;
      dst_rdy_out    : in  std_logic
      );
  end component;

  -- Simple FIFO backed by a shift register.
  component fifo_shift
    generic (
      D_BITS    : positive;               -- Data Width
      MIN_DEPTH : positive                -- Minimum FIFO Size in Words
    );
    port (
      -- Global Control
      clk : in std_logic;
      rst : in std_logic;

      -- Writing Interface
      put : in  std_logic;                            -- Write Request
      din : in  std_logic_vector(D_BITS-1 downto 0);  -- Input Data
      ful : out std_logic;                            -- Capacity Exhausted

      -- Reading Interface
      got  : in  std_logic;                            -- Read Done Strobe
      dout : out std_logic_vector(D_BITS-1 downto 0);  -- Output Data
      vld  : out std_logic                             -- Data Valid
    );
  end component;

  -- Full-fledged FIFO with single clock domain using on-chip RAM.
  component fifo_cc_got
    generic (
      D_BITS         : positive;          -- Data Width
      MIN_DEPTH      : positive;          -- Minimum FIFO Depth
      DATA_REG       : boolean := false;  -- Store Data Content in Registers
      STATE_REG      : boolean := false;  -- Registered Full/Empty Indicators
      OUTPUT_REG     : boolean := false;  -- Registered FIFO Output
      ESTATE_WR_BITS : natural := 0;      -- Empty State Bits
      FSTATE_RD_BITS : natural := 0       -- Full State Bits
    );
    port (
      -- Global Reset and Clock
      rst, clk : in  std_logic;

      -- Writing Interface
      put       : in  std_logic;                            -- Write Request
      din       : in  std_logic_vector(D_BITS-1 downto 0);  -- Input Data
      full      : out std_logic;
      estate_wr : out std_logic_vector(imax(0, ESTATE_WR_BITS-1) downto 0);

      -- Reading Interface
      got       : in  std_logic;                            -- Read Completed
      dout      : out std_logic_vector(D_BITS-1 downto 0);  -- Output Data
      valid     : out std_logic;
      fstate_rd : out std_logic_vector(imax(0, FSTATE_RD_BITS-1) downto 0)
    );
  end component;

  component fifo_dc_got_sm
    generic (
      D_BITS    : positive;
      MIN_DEPTH : positive);
    port (
      clk_wr : in  std_logic;
      rst_wr : in  std_logic;
      put    : in  std_logic;
      din    : in  std_logic_vector(D_BITS-1 downto 0);
      full   : out std_logic;
      clk_rd : in  std_logic;
      rst_rd : in  std_logic;
      got    : in  std_logic;
      valid  : out std_logic;
      dout   : out std_logic_vector(D_BITS-1 downto 0));
  end component;
  
  component fifo_ic_got
    generic (
      D_BITS         : positive;          -- Data Width
      MIN_DEPTH      : positive;          -- Minimum FIFO Depth
      DATA_REG       : boolean := false;  -- Store Data Content in Registers
      OUTPUT_REG     : boolean := false;  -- Registered FIFO Output
      ESTATE_WR_BITS : natural := 0;      -- Empty State Bits
      FSTATE_RD_BITS : natural := 0       -- Full State Bits
    );
    port (
      -- Write Interface
      clk_wr    : in  std_logic;
      rst_wr    : in  std_logic;
      put       : in  std_logic;
      din       : in  std_logic_vector(D_BITS-1 downto 0);
      full      : out std_logic;
      estate_wr : out std_logic_vector(imax(ESTATE_WR_BITS-1, 0) downto 0);

      -- Read Interface
      clk_rd    : in  std_logic;
      rst_rd    : in  std_logic;
      got       : in  std_logic;
      valid     : out std_logic;
      dout      : out std_logic_vector(D_BITS-1 downto 0);
      fstate_rd : out std_logic_vector(imax(FSTATE_RD_BITS-1, 0) downto 0)
    );
  end component;

  component fifo_cc_got_tempput
    generic (
      D_BITS         : positive;          -- Data Width
      MIN_DEPTH      : positive;          -- Minimum FIFO Depth
      DATA_REG       : boolean := false;  -- Store Data Content in Registers
      STATE_REG      : boolean := false;  -- Registered Full/Empty Indicators
      OUTPUT_REG     : boolean := false;  -- Registered FIFO Output
      ESTATE_WR_BITS : natural := 0;      -- Empty State Bits
      FSTATE_RD_BITS : natural := 0       -- Full State Bits
      );
    port (
      -- Global Reset and Clock
      rst, clk : in  std_logic;

      -- Writing Interface
      put       : in  std_logic;                            -- Write Request
      din       : in  std_logic_vector(D_BITS-1 downto 0);  -- Input Data
      full      : out std_logic;
      estate_wr : out std_logic_vector(imax(0, ESTATE_WR_BITS-1) downto 0);

      commit    : in  std_logic;
      rollback  : in  std_logic;

      -- Reading Interface
      got       : in  std_logic;                            -- Read Completed
      dout      : out std_logic_vector(D_BITS-1 downto 0);  -- Output Data
      valid     : out std_logic;
      fstate_rd : out std_logic_vector(imax(0, FSTATE_RD_BITS-1) downto 0)
      );
  end component;

  component fifo_cc_got_tempgot is
    generic (
      D_BITS         : positive;          -- Data Width
      MIN_DEPTH      : positive;          -- Minimum FIFO Depth
      DATA_REG       : boolean := false;  -- Store Data Content in Registers
      STATE_REG      : boolean := false;  -- Registered Full/Empty Indicators
      OUTPUT_REG     : boolean := false;  -- Registered FIFO Output
      ESTATE_WR_BITS : natural := 0;      -- Empty State Bits
      FSTATE_RD_BITS : natural := 0       -- Full State Bits
    );
    port (
      -- Global Reset and Clock
      rst, clk : in  std_logic;

      -- Writing Interface
      put       : in  std_logic;                            -- Write Request
      din       : in  std_logic_vector(D_BITS-1 downto 0);  -- Input Data
      full      : out std_logic;
      estate_wr : out std_logic_vector(imax(0, ESTATE_WR_BITS-1) downto 0);

      -- Reading Interface
      got       : in  std_logic;                            -- Read Completed
      dout      : out std_logic_vector(D_BITS-1 downto 0);  -- Output Data
      valid     : out std_logic;
      fstate_rd : out std_logic_vector(imax(0, FSTATE_RD_BITS-1) downto 0);

      commit    : in  std_logic;
      rollback  : in  std_logic
    );
  end component;
end fifo;

package body fifo is
end fifo;
