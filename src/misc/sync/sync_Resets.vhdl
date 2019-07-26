library IEEE;
use     IEEE.STD_LOGIC_1164.all;

use     work.sync.all;


entity sync_Resets is
	generic (
		SYNC_DEPTH    : T_MISC_SYNC_DEPTH   := T_MISC_SYNC_DEPTH'low;        -- generate SYNC_DEPTH many stages, at least 2
    NUM_CLOCKS    : natural             := 2
  );
	port (
		Slow_Clock         : in  std_logic;                                  -- <Clock>  slowest clock domain
		Clocks             : in  std_logic_vector(NUM_CLOCKS -1 downto 0);   -- <Clocks> output clock domains
		Input_Reset        : in  std_logic;                                  -- @async:  reset input
		Output_Resets      : out std_logic_vector(NUM_CLOCKS -1 downto 0);   
		Output_Resets_fast : out std_logic_vector(NUM_CLOCKS -1 downto 0) 
	);
end entity;


architecture rtl of sync_Resets is
  signal Slow_Reset_sync  : std_logic;
begin

  slow_reset : entity work.sync_Reset
		port map(
			Clock         => Slow_Clock,
			Input         => Input_Reset,
			Output        => Slow_Reset_sync
		);
    
  sync : for i in 0 to NUM_CLOCKS -1 generate
    clock_sync : entity work.sync_Bits
			generic map(
				INIT          => "1"
			)
			port map(
				Clock         => Clocks(i),
				Input(0)      => Slow_Reset_sync,
				Output(0)     => Output_Resets(i)
			);

    fast_reset : entity work.sync_Reset
			port map(
				Clock         => Clocks(i),
				Input         => Input_Reset,
				Output        => Output_Resets_fast(i)
			);
  end generate;
end architecture;
