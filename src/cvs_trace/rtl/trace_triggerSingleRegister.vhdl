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
-- Entity: trace_triggerSingleRegister
-- Author(s): Stefan Alex
--
------------------------------------------------------
-- A single register for trigger-inputs             --
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

entity trace_triggerSingleRegister is
  generic (
    INPUTS     : positive;
    WIDTH      : positive;
    REG_INIT   : std_logic_vector;
    CMP_INIT   : tTriggerCmp1
  );
  port (
    -- globals
    clk : in std_logic;
    rst : in std_logic;

    -- trigger-input and event-fire-signal
    values_in : in  std_logic_vector(INPUTS*WIDTH-1 downto 0);
    events    : out std_logic_vector(INPUTS-1 downto 0);

    -- set registers an compares
    setReg      : in std_logic;
    setRegValue : in std_logic_vector(WIDTH-1 downto 0);
    setCmp      : in std_logic;
    setCmpValue : in tTriggerCmp1
  );
end trace_triggerSingleRegister;

architecture rtl of trace_triggerSingleRegister is

  constant REG_INIT_I : std_logic_vector(WIDTH-1 downto 0) := ifThenElse(REG_INIT'length = 1, (WIDTH-1 downto 0 => REG_INIT(0)),
                                                                         REG_INIT(WIDTH-1 downto 0));

  signal reg_r   : std_logic_vector(WIDTH-1 downto 0) := REG_INIT_I;
  signal reg_nxt : std_logic_vector(WIDTH-1 downto 0);

  signal cmp_r   : tTriggerCmp1 := CMP_INIT;
  signal cmp_nxt : tTriggerCmp1;

  signal cmpGreaterThan : std_logic_vector(INPUTS-1 downto 0);
  signal cmpEqual       : std_logic_vector(INPUTS-1 downto 0);
  signal cmpSmallerThan : std_logic_vector(INPUTS-1 downto 0);

begin

  -- compare

  cmp_gen : for i in 0 to INPUTS-1 generate
    cmpGreaterThan(i) <= '1' when values_in((i+1)*WIDTH-1 downto i*WIDTH) > reg_r else '0';
    cmpEqual(i)       <= '1' when values_in((i+1)*WIDTH-1 downto i*WIDTH) = reg_r else '0';
    cmpSmallerThan(i) <= '1' when values_in((i+1)*WIDTH-1 downto i*WIDTH) < reg_r else '0';
  end generate cmp_gen;

  -- output

  with cmp_r select
    events <= cmpGreaterThan when greaterThan,
              cmpEqual       when equal,
              cmpSmallerThan when smallerThan;

  -- set register

  reg_nxt <= setRegValue;
  cmp_nxt <= setCmpValue;

  clk_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        reg_r <= REG_INIT_I;
        cmp_r <= CMP_INIT;
      else
        if setReg = '1' then
          reg_r <= reg_nxt;
        end if;
        if setCmp = '1' then
          cmp_r <= cmp_nxt;
        end if;
      end if;
    end if;
  end process clk_proc;

end rtl;
