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
-- Entity: trace_triggerDoubleRegister
-- Author(s): Stefan Alex
--
------------------------------------------------------
-- A double register for trigger-inputs             --
------------------------------------------------------
--
-- Revision:    $Revision: 1.1 $
-- Last change: $Date: 2010-03-29 15:44:33 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.trace_types.all;
use poc.trace_functions.all;

entity trace_triggerDoubleRegister is
  generic (
    INPUTS     : positive;
    WIDTH      : positive;
    REG1_INIT  : std_logic_vector;
    REG2_INIT  : std_logic_vector;
    CMP_INIT   : tTriggerCmp2
  );
  port (
    -- globals
    clk : in std_logic;
    rst : in std_logic;

    -- trigger-input and event-fire-signal
    values_in : in  std_logic_vector(INPUTS*WIDTH-1 downto 0);
    events    : out std_logic_vector(INPUTS-1 downto 0);

    -- set registers an compares
    setReg1      : in std_logic;
    setReg1Value : in std_logic_vector(WIDTH-1 downto 0);
    setReg2      : in std_logic;
    setReg2Value : in std_logic_vector(WIDTH-1 downto 0);
    setCmp       : in std_logic;
    setCmpValue  : in tTriggerCmp2
  );
end trace_triggerDoubleRegister;

architecture rtl of trace_triggerDoubleRegister is

  constant REG1_INIT_I : std_logic_vector(WIDTH-1 downto 0) := ifThenElse(REG1_INIT'length = 1, (WIDTH-1 downto 0 => REG1_INIT(0)),
                                                                          REG1_INIT(WIDTH-1 downto 0));
  constant REG2_INIT_I : std_logic_vector(WIDTH-1 downto 0) := ifThenElse(REG2_INIT'length = 1, (WIDTH-1 downto 0 => REG2_INIT(0)),
                                                                          REG2_INIT(WIDTH-1 downto 0));

  signal reg1_r   : std_logic_vector(WIDTH-1 downto 0) := REG1_INIT_I;
  signal reg2_r   : std_logic_vector(WIDTH-1 downto 0) := REG2_INIT_I;
  signal reg1_nxt : std_logic_vector(WIDTH-1 downto 0);
  signal reg2_nxt : std_logic_vector(WIDTH-1 downto 0);

  signal cmp_r   : tTriggerCmp2 := CMP_INIT;
  signal cmp_nxt : tTriggerCmp2;

  signal cmpBetweenEqualRange : std_logic_vector(INPUTS-1 downto 0);
  signal cmpOutsideRange      : std_logic_vector(INPUTS-1 downto 0);

begin

  -- compare

  cmp_gen : for i in 0 to INPUTS-1 generate
    signal value : std_logic_vector(WIDTH-1 downto 0);
  begin
    value <= values_in((i+1)*WIDTH-1 downto i*WIDTH);
    cmpBetweenEqualRange(i) <= '1' when reg1_r <= value and value <= reg2_r else '0';
    cmpOutsideRange(i)      <= '1' when value < reg1_r or reg2_r < value    else '0';
  end generate cmp_gen;

  -- output

  with cmp_r select
    events <= cmpBetweenEqualRange when betweenEqualRange,
              cmpOutsideRange      when outsideRange;

  -- set register

  reg1_nxt <= setReg1Value;
  reg2_nxt <= setReg2Value;
  cmp_nxt  <= setCmpValue;

  clk_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        reg1_r <= REG1_INIT_I;
        reg2_r <= REG2_INIT_I;
        cmp_r  <= CMP_INIT;
      else
        if setReg1 = '1' then
          reg1_r <= reg1_nxt;
        end if;
        if setReg2 = '1' then
          reg2_r <= reg2_nxt;
        end if;
        if setCmp = '1' then
          cmp_r <= cmp_nxt;
        end if;
      end if;
    end if;
  end process clk_proc;

end rtl;
