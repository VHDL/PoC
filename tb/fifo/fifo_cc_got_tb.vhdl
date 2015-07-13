entity fifo_cc_got_tb is
end entity;

library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	PoC;
use			PoC.utils.all;


architecture tb of fifo_cc_got_tb is

  -- component generics
  constant D_BITS         : positive := 8;
  constant MIN_DEPTH      : positive := 30;
  constant ESTATE_WR_BITS : natural  := 2;
  constant FSTATE_RD_BITS : natural  := 2;

  -- Clock Control
  signal rst  : std_logic;
  signal clk  : std_logic                := '0';
  signal done : std_logic_vector(0 to 7) := (others => '0');
  
begin

  clk <= not clk after 5 ns when done /= (done'range => '1') else '0';
  rst <= '1', '0' after 10 ns;

  genDUTs: for c in 0 to 7 generate

    -- Local Configuration
    constant CFG_CASE : std_logic_vector(2 downto 0) := std_logic_vector(to_unsigned(c, 3));

    constant DATA_REG   : boolean := CFG_CASE(0) = '1';
    constant STATE_REG  : boolean := CFG_CASE(1) = '1';
    constant OUTPUT_REG : boolean := CFG_CASE(2) = '1';
    
    -- Local Component Ports
    signal put   : std_logic;
    signal din   : std_logic_vector(D_BITS-1 downto 0);
    signal full  : std_logic;
    signal got   : std_logic;
    signal dout  : std_logic_vector(D_BITS-1 downto 0);
    signal valid : std_logic;

  begin

    DUT : entity PoC.fifo_cc_got
      generic map (
        D_BITS         => D_BITS,
        MIN_DEPTH      => MIN_DEPTH,
        STATE_REG      => STATE_REG,
        DATA_REG       => DATA_REG,
        OUTPUT_REG     => OUTPUT_REG,
        ESTATE_WR_BITS => ESTATE_WR_BITS,
        FSTATE_RD_BITS => FSTATE_RD_BITS
      )
      port map (
        rst       => rst,
        clk       => clk,
        put       => put,
        din       => din,
        full      => full,
        estate_wr => open,
        got       => got,
        dout      => dout,
        valid     => valid,
        fstate_rd => open
      );

    -- Writer
    process
    begin
      din <= (others => '-');
      put <= '0';
      wait until rising_edge(clk) and rst = '0';
    
      for i in 0 to 2**(D_BITS-1)-1 loop
        din <= std_logic_vector(to_unsigned(i, D_BITS));
        put <= '1';
        wait until rising_edge(clk) and full = '0';
      end loop;

      for i in 2**(D_BITS-1) to 2**D_BITS-1 loop
        din <= (others => '-');
        put <= '0';
        wait until rising_edge(clk) and valid = '0';
        din <= std_logic_vector(to_unsigned(i, D_BITS));
        put <= '1';
        wait until rising_edge(clk);
      end loop;

      din <= (others => '-');
      put <= '0';
      wait;                             -- forever
    
    end process;

    -- Reader
    process
    begin
      got <= '0';
      for i in 0 to 2**D_BITS-1 loop
        wait until rising_edge(clk) and valid = '1';
        assert dout = std_logic_vector(to_unsigned(i, D_BITS))
          report
             "Output Failure in Configuration "&integer'image(c)&
             " @ Pos "&integer'image(i)
          severity failure;
        got <= '1';
        wait until rising_edge(clk);
        got <= '0';
        wait until rising_edge(clk);
      end loop;
    
      done(c) <= '1';
      report "Test "&integer'image(c)&" completed." severity note;
      wait;                             -- forever
    end process;
  end generate genDUTs;

end;
