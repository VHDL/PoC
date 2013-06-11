--
-- Copyright (c) 2011-2012
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
-- Entity: fifo_glue
-- Author(s): Thomas B. Preusser <thomas.preusser@tu-dresden.de>
-- 
-- Minimal FIFO with single clock and first-word-fall-through mode.
-- Its primary use is the decoupling of enable domains in a processing
-- pipeline. Data storage is limited to two words only so as to allow both
-- the 'ful'  and the 'vld' indicators to be driven by registers.
--

library IEEE;
use IEEE.std_logic_1164.all;

entity fifo_glue is
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
end fifo_glue;

architecture rtl of fifo_glue is

  -- Data Buffer Registers
  signal A, B : std_logic_vector(D_BITS-1 downto 0);

  -- State Registers
  signal Full, Avail : std_logic := '0';
  
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        A <= (others => '-');
        B <= (others => '-');

        Full  <= '0';
        Avail <= '0';
      else

        if Avail = '0' then
          if put = '1' then
            B     <= di;
            Avail <= '1';
          end if;
        elsif Full = '0' then
          if got = '1' then
            if put = '1' then
              B <= di;
            else
              Avail <= '0';
            end if;
          else
            if put = '1' then
              A    <= di;
              Full <= '1';
            end if;
          end if;
        else
          if got = '1' then
            B    <= A;
            Full <= '0';
          end if;
        end if;
        
      end if;
    end if;
  end process;
  
  ful <= Full;
  vld <= Avail;
  do  <= B;

end rtl;
