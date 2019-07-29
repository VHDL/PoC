library IEEE;
use     IEEE.STD_LOGIC_1164.all;

use     work.sync.all;
use     work.components.all;


entity sync_Resets is
	generic (
    SNYC_MODE     : T_SYNC_MODE         := SYNC_MODE_STRICTLY_ORDERED; --SYNC_MODE_UNORDERED, SYNC_MODE_ORDERED, SYNC_MODE_STRICTLY_ORDERED
		SYNC_DEPTH    : T_MISC_SYNC_DEPTH   := T_MISC_SYNC_DEPTH'low +2;        -- generate SYNC_DEPTH many stages, at least 2
    NUM_CLOCKS    : natural             := 4
  );
	port (
		Clocks             : in  std_logic_vector(NUM_CLOCKS -1 downto 0);   -- <Clocks> output clock domains
		Input_Reset        : in  std_logic;                                  -- @async:  reset input
		Output_Resets      : out std_logic_vector(NUM_CLOCKS -1 downto 0)
	);
end entity;


architecture rtl of sync_Resets is
  -- attribute ASYNC_REG                    : string;
  -- attribute SHREG_EXTRACT                : string;

  -- signal Data_meta                      : std_logic    := '1';
  -- signal Data_sync                      : std_logic_vector(SYNC_DEPTH - 1 downto 0)    := (others => '1');

  -- -- Mark registers as asynchronous
  -- attribute ASYNC_REG      of Data_meta  : signal is "TRUE";
  -- attribute ASYNC_REG      of Data_sync  : signal is "TRUE";

  -- -- Prevent XST from translating two FFs into SRL plus FF
  -- attribute SHREG_EXTRACT of Data_meta  : signal is "NO";
  -- attribute SHREG_EXTRACT of Data_sync  : signal is "NO";
  
  signal sync_reset_d      : std_logic_vector(NUM_CLOCKS -1 downto 1) := (others => '0');
  signal sync_reset_out    : std_logic_vector(NUM_CLOCKS -1 downto 0) := (others => '0');
  signal sync_bits_out     : std_logic_vector(NUM_CLOCKS -1 downto 0) := (others => '0');
begin

  reset_sync_inst :  entity work.sync_Reset
  generic map(
    SYNC_DEPTH    => SYNC_DEPTH
  )
  port map(
    Clock         => Clocks(0),
    Input         => Input_Reset,
    D             => '0',
    Output        => sync_reset_out(0)
  );
  
  sync_bits_inst : entity work.sync_Bits
  generic map(
    SYNC_DEPTH    => 2
  )
  port map(
    Clock         => Clocks(0),
    Input(0)      => sync_reset_out(0),
    Output(0)     => sync_bits_out(0)
  );
    
  sync : for i in 1 to NUM_CLOCKS -1 generate
    signal reset_rs : std_logic := '0';
  begin
    snyc_mode_gen : if SNYC_MODE = SYNC_MODE_UNORDERED generate
      reset_rs <= sync_reset_out(i);
      sync_reset_d(i) <= '0';
      
    elsif SNYC_MODE = SYNC_MODE_ORDERED generate
      sync_reset_d(i) <= sync_reset_out(i -1);
      reset_rs        <= sync_reset_out(i);
      
    elsif SNYC_MODE = SYNC_MODE_STRICTLY_ORDERED generate
      signal set_re           : std_logic;
      signal rst_fe           : std_logic;
      signal sync_reset_out_d : std_logic := '0';
      signal sync_bits_out_d  : std_logic := '0';
    begin
      sync_reset_out_d <= sync_reset_out(i) when rising_edge(Clocks(i));
      set_re           <= not sync_reset_out_d and sync_reset_out(i);
      sync_bits_out_d  <= sync_bits_out(i -1) when rising_edge(Clocks(i));
      rst_fe           <= sync_bits_out_d and not sync_bits_out(i -1);
      reset_rs         <= ffsr(set => set_re, rst => rst_fe, q=> reset_rs) when rising_edge(Clocks(i));
      
    else generate
      assert false report "Not Supported Sync-Mode for Sync-Reset!" severity failure;
    end generate;
    
    
    reset_sync_inst :  entity work.sync_Reset
    generic map(
      SYNC_DEPTH    => SYNC_DEPTH
    )
    port map(
      Clock         => Clocks(i),
      Input         => Input_Reset,
      D             => sync_reset_d(i),
      Output        => sync_reset_out(i)
    );
    
    sync_bits_inst : entity work.sync_Bits
    port map(
      Clock         => Clocks(i),
      Input(0)      => reset_rs,
      Output(0)     => sync_bits_out(i)
    );
    
  end generate;
  
  Output_Resets <= sync_bits_out;
  
end architecture;
