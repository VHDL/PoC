
library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

use     work.config.all;
use     work.utils.all;
use     work.mem.all;
use     work.ocram.ocram_sdp;


entity fifo_cc_got_tempput_pipelined is
	generic (
		PRE_PIPELINES   : positive   := 2;
		POST_PIPELINES  : positive   := 2;
		RAM_TYPE        : T_RAM_TYPE := RAM_TYPE_ULTRA_RAM; -- RAM_TYPE_AUTO;     
		D_BITS          : positive   := 200;                -- Data Width
		MIN_DEPTH       : positive   := 8096;               -- Minimum FIFO Depth
		DATA_REG        : boolean    := false;              -- Store Data Content in Registers
		STATE_REG       : boolean    := false;              -- Registered Full/Empty Indicators
		OUTPUT_REG      : boolean    := true;               -- Registered FIFO Output
		 ESTATE_WR_BITS : natural    := 0;                  -- Empty State Bits
		 FSTATE_RD_BITS : natural    := 0                   -- Full State Bits
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
end entity;


architecture rtl of fifo_cc_got_tempput_pipelined is

	signal fifo_put       : std_logic;                            -- Write Request
	signal fifo_din       : std_logic_vector(D_BITS +1 downto 0);  -- Input Data
	signal fifo_full      : std_logic;
	signal fifo_commit    : std_logic;
	signal fifo_rollback  : std_logic;
	signal fifo_got       : std_logic;                            -- Read Completed
	signal fifo_dout      : std_logic_vector(D_BITS-1 downto 0);  -- Output Data
	signal fifo_valid     : std_logic;


begin
	pre_stage : entity work.fifo_glue
	generic map(
		PIPELINE_STAGES => PRE_PIPELINES,
		D_BITS          => D_BITS +2
	)
	port map(
		-- Control
		clk             => clk,
		rst             => rst,

		-- Input
		put             => put,
		di(din'range)   => din,
		di(din'high +1) => commit,
		di(din'high +2) => rollback,
		ful             => full,

		-- Output
		vld             => fifo_put,
		do              => fifo_din,
		got             => not fifo_full
	);

	fifo : entity work.fifo_cc_got_tempput
	generic map(
		RAM_TYPE       => RAM_TYPE       ,
		D_BITS         => D_BITS         ,
		MIN_DEPTH      => MIN_DEPTH      ,
		DATA_REG       => DATA_REG       ,
		STATE_REG      => STATE_REG      ,
		OUTPUT_REG     => OUTPUT_REG     ,
		ESTATE_WR_BITS => 0 ,
		FSTATE_RD_BITS => 0
	)
	port map(
		-- Global Reset and Clock
		rst       => rst,
		clk       => clk,

		-- Writing Interface
		put       => fifo_put,
		din       => fifo_din(D_BITS-1 downto 0),
		full      => fifo_full,
		estate_wr => estate_wr,

		commit    => fifo_din(D_BITS),
		rollback  => fifo_din(D_BITS +1),

		-- Reading Interface
		got       => not fifo_got,
		dout      => fifo_dout,
		valid     => fifo_valid,
		fstate_rd => fstate_rd
	);
	
	post_stage : entity work.fifo_glue
	generic map(
		PIPELINE_STAGES => POST_PIPELINES,
		D_BITS          => D_BITS
	)
	port map(
		-- Control
		clk             => clk,
		rst             => rst,

		-- Input
		put             => fifo_valid,
		di              => fifo_dout,
		ful             => fifo_got,

		-- Output
		vld             => valid,
		do              => dout,
		got             => got
	);


end architecture;
