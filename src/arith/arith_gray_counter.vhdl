--
-- Copyright (c) 2012
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
-- Entity: arith_gray_counter
-- Author(s): Martin Zabel    <martin.zabel@tu-dresden.de>
--            Steffen Koehler <steffen.koehler@tu-dresden.de>
--            Thomas Preusser <thomas.preusser@tu-dresden.de>
-- 
-- Gray-Code Counter
--
-- rst = synchronous reset to INIT value
-- inc = increment counter
-- dec = decrement counter (input defaults to '0')
-- val = counter value
--
-- The initial / reset value can be set with INIT.
--
-- Revision:    $Revision: 1.29 $
-- Last change: $Date: 2012-09-26 12:51:59 $
--

library ieee;
use ieee.std_logic_1164.all;

entity arith_gray_counter is
  generic (
    BITS : positive;     -- Bit Width of Counter
    INIT : natural := 0  -- Binary Position of Counter Value after Reset
  );
  port (
    clk : in  std_logic;
    rst : in  std_logic;                          -- Reset to INIT Value
    inc : in  std_logic;                          -- Increment
    dec : in  std_logic := '0';                   -- Decrement
    val : out std_logic_vector(BITS-1 downto 0);  -- Value Output
    cry : out std_logic                           -- Carry Output
  );
end arith_gray_counter;


library IEEE;
use IEEE.numeric_std.all;

architecture rtl of arith_gray_counter is

  -- purpose: gray constant encoder
  function gray_encode (val : natural; len : positive) return unsigned is
    variable bin : unsigned(len-1 downto 0) := to_unsigned(val, len);
  begin
    if len = 1 then
      return bin;
    end if;
    return bin xor '0' & bin(len-1 downto 1);
  end gray_encode;

  -- purpose: parity generation
  function parity (val : unsigned) return std_logic is
    variable res : std_logic := '0';
  begin  -- parity
    for i in val'range loop
      res := res xor val(i);
    end loop;
    return res;
  end parity;

  -- Counter Register
  constant INIT_GRAY  : unsigned(BITS-1 downto 0) := gray_encode(INIT, BITS);
  signal gray_cnt_r   : unsigned(BITS-1 downto 0) := INIT_GRAY;
  signal gray_cnt_nxt : unsigned(BITS-1 downto 0);

  signal en : std_logic;                -- enable: inc xor dec

begin

  -----------------------------------------------------------------------------
  -- Actual Counter Register
  en <= inc xor dec;
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        gray_cnt_r <= INIT_GRAY;
      elsif en = '1' then
        gray_cnt_r <= gray_cnt_nxt;
      end if;
    end if;
  end process;
  val <= std_logic_vector(gray_cnt_r);

  -----------------------------------------------------------------------------
  -- Computation of Increment/Decrement
  

  -- Trivial one-bit Counter
  g1: if BITS = 1 generate
    gray_cnt_nxt <= not gray_cnt_r;
    cry          <= gray_cnt_r(0) xor dec;
  end generate g1;

  -- Multi-Bit Counter
  g2: if BITS > 1 generate

    constant INIT_PAR : std_logic := parity(INIT_GRAY);
    -- search for first one in gray_cnt_r(MSB-1 downto LSB)
    -- first_one_n(i) = '1' denotes position i

    -- parity of gray_cnt_r
    signal par_r   : std_logic := INIT_PAR;
    signal par_nxt : std_logic;

  begin

    -- Parity Register
    process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          par_r <= INIT_PAR;
        elsif en = '1' then
          par_r <= par_nxt;
        end if;
      end if;
    end process;

    -- Computation of next Value
    process(gray_cnt_r, par_r, dec)
      variable  x : unsigned(BITS-1 downto 0);
      variable  s : unsigned(BITS-1 downto 0);
    begin

      -- Prefer inc over dec to keep combinational path short in standard use.
      x         := gray_cnt_r(BITS-2 downto 0) & (par_r xnor dec);
      x(x'left) := not gray_cnt_r(BITS-1);  -- catch final carry to invert last bit
      s         := not x + 1;               -- locate first intermediate '1'

      gray_cnt_nxt <= s(BITS-1) & (gray_cnt_r(BITS-2 downto 0) xor
                                   (s(BITS-2 downto 0) and x(BITS-2 downto 0)));
      par_nxt      <= s(0) xor dec;
    end process;

    cry <=  ((gray_cnt_r(BITS-1) xor dec) and (gray_cnt_nxt(BITS-1) xnor dec));
  end generate g2;

end rtl;
