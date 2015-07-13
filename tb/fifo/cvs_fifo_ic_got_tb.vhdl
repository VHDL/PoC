entity fifo_ic_got_tb is
end fifo_ic_got_tb;

library IEEE;
use IEEE.std_logic_1164.all;

library poc;
use poc.functions.all;
use poc.fifo.all;
use poc.comm.all;

architecture tb of fifo_ic_got_tb is

  -- FIFO Parameters
  constant D_BITS         : positive := 9;
  constant MIN_DEPTH      : positive := 8;
  constant OUTPUT_REG     : boolean  := true;
  constant ESTATE_WR_BITS : natural  := 3;
  constant FSTATE_RD_BITS : natural  := 3;

  -- Sequence Generator
  constant GEN : bit_vector       := "100110001";
  constant ORG : std_logic_vector :=  "00000001";
  
  -- Clock Generation and Reset
  signal rst  : std_logic := '1';
  signal clk0 : std_logic := '0';
  signal clk1 : std_logic := '0';
  signal clk2 : std_logic := '0';
  signal done : std_logic := '0';

  -- clk0 -> clk1 Transfer
  signal di0  : std_logic_vector(D_BITS-1 downto 0);
  signal put0 : std_logic;
  signal ful0 : std_logic;

  signal do1  : std_logic_vector(D_BITS-1 downto 0);
  signal vld1 : std_logic;
  signal got1 : std_logic;

  -- clk1 -> clk2 Transfer
  signal di1  : std_logic_vector(D_BITS-1 downto 0);
  signal put1 : std_logic;
  signal ful1 : std_logic;

  signal do2  : std_logic_vector(D_BITS-1 downto 0);
  signal vld2 : std_logic;
  signal got2 : std_logic;

  signal dat2 : std_logic_vector(D_BITS-1 downto 0);
  
begin

  -----------------------------------------------------------------------------
  -- Clock Generation and Reset
  clk0 <= clk0 xnor done after  7 ns;
  clk1 <= clk1 xnor done after 12 ns;
  clk2 <= clk2 xnor done after  5 ns;
  process
  begin
    wait for 16 ns;
    rst <= '0';
    wait;
  end process;

  -----------------------------------------------------------------------------
  -- Initial Generator
  gen0: comm_scramble
    generic map (
      GEN  => GEN,
      BITS => D_BITS
    )
    port map (
      clk  => clk0,
      set  => rst,
      din  => ORG,
      step => put0,
      mask => di0
    );
  process
    variable cnt : natural := 0;
  begin
    put0 <= '0';
    wait until rst = '0' and rising_edge(clk0);
    
    -- Slow Input Phase
    while cnt < 2*MIN_DEPTH loop
      wait until falling_edge(clk0);
      if ful0 = '0' and vld1 = '0' then
        put0 <= '1';
        cnt := cnt + 1;
      else
        put0 <= '0';
      end if;
    end loop;

    -- Fast Input Phase
    while cnt < 4*MIN_DEPTH loop
      wait until falling_edge(clk0);
      if ful0 = '0' then
        put0 <= '1';
        cnt := cnt + 1;
      else
        put0 <= '0';
      end if;
    end loop;

    -- Let it drain
    wait until falling_edge(clk0);
    put0 <= '0';
    report "Sending Complete." severity note;
    wait;

  end process;
  
  fifo0_1: fifo_ic_got
    generic map (
      D_BITS         => D_BITS,
      MIN_DEPTH      => MIN_DEPTH,
      OUTPUT_REG     => OUTPUT_REG,
      ESTATE_WR_BITS => ESTATE_WR_BITS,
      FSTATE_RD_BITS => FSTATE_RD_BITS
    )
    port map (
      clk_wr    => clk0,
      rst_wr    => rst,
      put       => put0,
      din       => di0,
      full      => ful0,
      estate_wr => open,

      clk_rd    => clk1,
      rst_rd    => rst,
      got       => got1,
      valid     => vld1,
      dout      => do1,
      fstate_rd => open
    );

  -----------------------------------------------------------------------------
  -- Intermediate Checker
  gen1: comm_scramble
    generic map (
      GEN  => GEN,
      BITS => D_BITS
    )
    port map (
      clk  => clk1,
      set  => rst,
      din  => ORG,
      step => put1,
      mask => di1
    );
  got1 <= vld1 and not ful1;
  put1 <= got1;

  process
    variable cnt : natural := 0;
  begin
    -- Pass-thru Checking
    wait until rising_edge(clk1);
    assert rst = '1' or put1 = '0' or do1 = di1
      report "Mismatch in clk1."
      severity error;
    if put1 = '1' then
      cnt := cnt + 1;
    end if;
  end process;

  fifo1_2: fifo_ic_got
    generic map (
      DATA_REG       => true,
      D_BITS         => D_BITS,
      MIN_DEPTH      => MIN_DEPTH,
      ESTATE_WR_BITS => ESTATE_WR_BITS,
      FSTATE_RD_BITS => FSTATE_RD_BITS
    )
    port map (
      clk_wr    => clk1,
      rst_wr    => rst,
      put       => put1,
      din       => di1,
      full      => ful1,
      estate_wr => open,

      clk_rd    => clk2,
      rst_rd    => rst,
      got       => got2,
      valid     => vld2,
      dout      => do2,
      fstate_rd => open
    );

  -----------------------------------------------------------------------------
  -- Final Checker
  gen2: comm_scramble
    generic map (
      GEN  => GEN,
      BITS => D_BITS
    )
    port map (
      clk  => clk2,
      set  => rst,
      din  => ORG,
      step => got2,
      mask => dat2
    );

  process
    variable cnt : natural := 0;
    variable del : natural := 0;
  begin
    -- Final Checking
    wait until rising_edge(clk2);
    got2 <= '0';
    if vld2 = '1' then
      del := del + 1;
      if del = 3 then
        got2 <= '1';
        assert dat2 = do2
          report "Mismatch in clk2."
          severity error;
        cnt := cnt + 1;
        del := 0;
      end if;
    end if;
    --port "Count: "&integer'image(cnt) severity note;
    if cnt = 4*MIN_DEPTH then
      done <= '1';
      report "Test Complete." severity note;
    end if;
  end process;
  
end tb;
