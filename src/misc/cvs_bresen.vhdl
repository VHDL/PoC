--
-- Copyright (c) 2009
-- Technische Universitaet Dresden, Dresden, Germany
-- Faculty of Computer Science
-- Institute for Computer Engineering
-- Chair of VLSI-Design, Diagnostics and Architecture
--
-- For internal educational use only.
-- The distribution of source code or generated files
-- is prohibited.
--

--
-- Entity: bresen
-- Author: Thomas B. Preusser
--
-- Implements a Bresenham clock divider.
-- Its output clock has edges synchronous to the input clock
-- except for an additional skew delay by the output fliflop.
-- The output clock will toggle P times within Q cycles of the
-- input clock, effectively implementing its division by Q/P.
-- Note that 2*P <= Q must hold.
--
-- If the default T = 0 is chosen, the generated clock approximation
-- is the best achievable with synchronous edges. For T in {1,2}, the
-- output quality might be reduced by the internal use of a carry-save
-- adder so that individual clock edges might be slightly misplaced.
-- Either case totally avois accumulating long-term clock drifts.
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2009-01-29 15:33:38 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

entity bresen is
  generic (
    P : positive;                       -- enumerator
    Q : positive;                       -- denominator
    T : natural := 0                    -- T = 0: exact
                                        -- T = 1: Carry Save
                                        -- T = 2: Carry Save
  );
  port (
    clk  : in  std_logic;               -- Input Clock
    rst  : in  std_logic;               -- Reset

    cdiv : out std_logic                -- Output Clock
  );
end bresen;

architecture bresen_impl of bresen is
begin
  assert 2*P <= Q
    report "Division beyond 0.5 not possible."
    severity error;

  -- Exact Division
  genExact: if T = 0 generate
    signal E : signed(log2ceil(imax(Q-2*P, 2*P)) downto 0);
    signal D : signed(log2ceil(imax(Q-2*P, 2*P)) downto 0);
    signal Z : std_logic;
  begin
    D <= to_signed(2*P,   D'length) when E(E'left) = '1' else
         to_signed(2*P-Q, D'length);
    process(clk)
    begin
      if clk'event and clk = '1' then
        if rst = '1' then
          E <= (others => '0');
          Z <= '0';
        else
          E <= E + D;
          Z <= Z xnor E(E'left);
        end if;
      end if;
    end process;
    cdiv <= Z;
  end generate genExact;

  genCS: if T > 0 generate
    signal EC, ES : unsigned(log2ceil(imax(Q-2*P, 2*P)) downto 0) := (others => '0');
    signal C      : std_logic;
    signal D      : unsigned(log2ceil(imax(Q-2*P, 2*P)) downto 0);
    signal Z      : std_logic := '0';
  begin
    C <= (EC(EC'left) or  ES(ES'left)) when T = 1 else
         (EC(EC'left) and ES(ES'left));

    D <= unsigned(to_signed(2*P-Q, D'length)) when C = '1' else
         to_unsigned(2*P  , D'length);

    EC(0) <= '0';
    process(clk)
    begin
      if clk'event and clk = '1' then
        if rst = '1' then
          ES <= (others => '0');               ES(ES'left) <= '1';
          EC <= (others => '0'); if T > 1 then EC(EC'left) <= '1'; end if;
          Z  <= '0';
        else
          for i in ES'range loop
            ES(i)   <= ES(i) xor EC(i) xor D(i);
          end loop;
          for i in EC'low to EC'high-1 loop
            EC(i+1) <= (ES(i) and EC(i)) or (ES(i) and D(i)) or (EC(i) and D(i));
          end loop;
          Z <= Z xor C;
        end if;
      end if;
    end process;
    cdiv <= Z;

  end generate genCS;

end bresen_impl;

