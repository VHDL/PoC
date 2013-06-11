--
-- Copyright (c) 2007-2012
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Authors: Thomas B. Preusser
-- 
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Entity: fifo_shift
-- Author(s): Thomas B. Preusser <thomas.preusser@tu-dresden.de>
-- 
-- FIFO, common clock, pipelined interface
-- implemented within a shift register - useful on some FPGA devices
--
-- Revision:    $Revision: 1.4 $
-- Last change: $Date: 2012-10-01 12:20:51 $
--

library IEEE;
use IEEE.std_logic_1164.all;

library poc;
use poc.functions.all;                       

entity fifo_shift is
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
end fifo_shift;

library IEEE;
use IEEE.numeric_std.all;

library poc;
use poc.functions.all;

architecture rtl of fifo_shift is

  -- Data Register
  type tData is array(natural range<>) of std_logic_vector(D_BITS-1 downto 0);
  signal Dat : tData(0 to MIN_DEPTH-1);
  signal Ptr : unsigned(log2ceilnz(MIN_DEPTH) downto 0);

begin

  -- Data anf Pointer Registers
  process(clk)
  begin
    if clk'event and clk = '1' then
      if put = '1' then
        Dat <= din & Dat(0 to MIN_DEPTH-2);
      end if;
    end if;
  end process;
  process(clk)
  begin
    if clk'event and clk = '1' then
      if rst = '1' then
        Ptr <= (others => '0');
      else
        if put /= got then
          if put = '1' then
            Ptr <= Ptr - 1;
          else
            Ptr <= Ptr + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Outputs
  dout <= Dat(to_integer(not Ptr(Ptr'left-1 downto 0)));
  vld  <= Ptr(Ptr'left);
  ful  <= '1' when ((not Ptr(Ptr'left-1 downto 0)) and to_unsigned(MIN_DEPTH-1, Ptr'length-1)) = MIN_DEPTH-1 else '0';

end rtl;
