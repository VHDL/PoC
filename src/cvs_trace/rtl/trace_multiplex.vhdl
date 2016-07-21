--
-- Copyright (c) 2010
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
-- Entity: trace_multiplex
-- Author(s): Stefan Alex
--
------------------------------------------------------
-- Multiplex values bitwise                         --
------------------------------------------------------
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2010-03-29 15:44:33 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_types.all;
use poc.trace_functions.all;

entity trace_multiplex is
  generic (
    DATA_BITS : tNat_array;
    IMPL      : boolean
    );
  port (
    inputs : in  std_logic_vector(sum(DATA_BITS)-1 downto 0);
    sel    : in  unsigned(log2ceilnz(countValuesGreaterThan(DATA_BITS,0))-1 downto 0);
    output : out std_logic_vector(max(DATA_BITS)-1 downto 0)
    );
end trace_multiplex;

architecture Behavioral of trace_multiplex is
  -- remove zeros
  constant DATA_BITS_I : tNat_array := removeValue(DATA_BITS, 0);
  constant GROUPS      : positive   := ifThenElse(containsValue(DATA_BITS_I, 0), 1, countGroups(DATA_BITS_I));
begin

  assert sum(DATA_BITS_I) > 0
    severity error;

  one_input_gen : if countValuesGreaterThan(DATA_BITS_I, 0) = 1 generate
    output <= inputs;
  end generate one_input_gen;

  more_inputs_fill_gen : if countValuesGreaterThan(DATA_BITS_I, 0) > 1 and (IMPL or GROUPS = 1) generate

    constant MULTIPLEX_CNT     : positive := countValuesGreaterThan(DATA_BITS_I, 0);
    constant OUTPUT_BITS       : positive := max(DATA_BITS_I);
    constant INPUT_UNFOLD_BITS : positive := MULTIPLEX_CNT*OUTPUT_BITS;

    type tInputUnfold is array(natural range <>) of std_logic_vector(OUTPUT_BITS-1 downto 0);
    signal input_unfold : tInputUnfold(MULTIPLEX_CNT-1 downto 0);

  begin

    -- unfold the input

    unfold_gen : for i in 0 to DATA_BITS_I'length-1 generate
      cond_gen : if DATA_BITS_I(i) > 0 generate
        constant MULTIPLEX_SEL : natural := countValuesGreaterThan(DATA_BITS_I, i, 0);
        constant INPUT_INDEX   : natural := sum(DATA_BITS_I, i);
      begin
        input_unfold(MULTIPLEX_SEL)(DATA_BITS_I(i)-1 downto 0)
                                                           <= inputs(INPUT_INDEX+DATA_BITS_I(i)-1 downto INPUT_INDEX);

        -- fill with zeros

        fill_gen : if DATA_BITS_I(i) < OUTPUT_BITS generate
          input_unfold(MULTIPLEX_SEL)(OUTPUT_BITS-1 downto DATA_BITS_I(i)) <= (others => '0');
        end generate fill_gen;

      end generate cond_gen;
    end generate unfold_gen;

    -- multiplex the signals

    output <= input_unfold(to_integer(sel)) when sel < input_unfold'length else (others => '-');

--    multiplex_gen : for i in 0 to max(DATA_BITS_I)-1 generate
--      constant SEL_BITS        : positive := countValuesGreaterThan(DATA_BITS_I,0);
--      constant SEL_UNFOLD_BITS : positive := log2ceil(INPUT_UNFOLD_BITS);
--      signal sel_unfold : unsigned(SEL_UNFOLD_BITS-1 downto 0);
--    begin
--
--      sel_unfold <= to_unsigned(max(DATA_BITS_I), SEL_UNFOLD_BITS-1) * sel;-- + i;
--
--      output(i)  <= input_unfold(to_integer(sel_unfold)) when sel_unfold < input_unfold'length else '0';
--
--    end generate multiplex_gen;

  end generate more_inputs_fill_gen;

  more_inputs_route_gen : if countValuesGreaterThan(DATA_BITS_I, 0) > 1 and (not IMPL and GROUPS > 1 )generate

    constant DATA_BITS_S : tNat_array := sort(DATA_BITS_I);

  begin

    -- multiplex the signals

    group_gen : for i in 0 to GROUPS-1 generate
      constant GROUP_VALUE : positive := getGroup(DATA_BITS_S, i);
      constant PRE_BITS    : natural := ifThenElse(i = 0, 0, getGroup(DATA_BITS_S, ifThenElse(i = 0, 1, i-1)));
                                                                 -- modelsim will throw error, when other argument is -1
      constant BITS        : positive := GROUP_VALUE-PRE_BITS;
      constant MP_CNT      : natural  := countValuesGreaterThan(DATA_BITS_S, GROUP_VALUE-1);
    begin

      -- only one signal to multiplex (so nothing to multiplex)
      one_mp : if MP_CNT = 1 generate
        constant IN_INDEX : natural := sum(DATA_BITS_I, indexOf(DATA_BITS_I, GROUP_VALUE));
      begin
        output(PRE_BITS+BITS-1 downto PRE_BITS) <= inputs(IN_INDEX+GROUP_VALUE-1 downto IN_INDEX+PRE_BITS);
      end generate one_mp;

      more_mps : if MP_CNT > 1 generate
      begin

        -- multiplex
        process(inputs, sel)
          variable index : natural;
        begin
          output(PRE_BITS+BITS-1 downto PRE_BITS) <= (others => '0'); -- TODO input-value to save multiplex
          for j in 0 to DATA_BITS_I'length-1 loop
            if GROUP_VALUE <= DATA_BITS_I(j) then
              index := sum(DATA_BITS_I, j);
              if sel = j then
                output(PRE_BITS+BITS-1 downto PRE_BITS) <= inputs(index+GROUP_VALUE-1 downto index+PRE_BITS);
              end if;
            end if;
          end loop;
        end process;

      end generate more_mps;

    end generate group_gen;

  end generate more_inputs_route_gen;

end Behavioral;
