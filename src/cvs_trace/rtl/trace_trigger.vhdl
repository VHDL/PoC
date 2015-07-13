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
-- Entity: trace_trigger
-- Author(s): Stefan Alex
-- 
------------------------------------------------------
-- Trigger-Instantiation with mode and type         --
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

entity trace_trigger is
  generic (
    EVENTS         : positive;
    LEVEL          : positive;
    MODE_INIT      : tTriggerMode;
    TYPE_INIT      : tTriggerType;
    ACTIV_INIT     : std_logic_vector;
    PRETRIGGER_INT : positive
  );
  port (
    -- globals
    clk : in std_logic;
    rst : in std_logic;

    -- lower level
    trigger_in : in std_logic_vector(EVENTS*LEVEL-1 downto 0);

    -- outputs
    trc_enable : out std_logic_vector(LEVEL-1 downto 0);
    send_start : out std_logic_vector(LEVEL-1 downto 0);
    send_stop  : out std_logic_vector(LEVEL-1 downto 0);
    send_do    : out std_logic_vector(LEVEL-1 downto 0);

    -- controller
    setMode      : in std_logic;
    setModeValue : in tTriggerMode;
    setType      : in std_logic;
    setTypeValue : in tTriggerType;
    setActiv     : in std_logic;
    setActivSel  : in unsigned(log2ceilnz(EVENTS)-1 downto 0)
  );
end trace_trigger;

architecture rtl of trace_trigger is

  signal activ_r   : std_logic_vector(EVENTS-1 downto 0) := ACTIV_INIT;
  signal activ_nxt : std_logic_vector(EVENTS-1 downto 0);

  signal mode_r   : tTriggerMode := MODE_INIT;
  signal mode_nxt : tTriggerMode;

  signal type_r   : tTriggerType := TYPE_INIT;
  signal type_nxt : tTriggerType;

  type tPreTrigCnt is array(natural range<>) of unsigned(log2ceil(PRETRIGGER_INT+1)-1 downto 0);
  signal preTrig_cnt_r    : tPreTrigCnt(LEVEL-1 downto 0) := (others => (others => '0'));
  signal preTrig_cnt_dec  : std_logic_vector(LEVEL-1 downto 0);
  signal preTrig_cnt_set  : std_logic_vector(LEVEL-1 downto 0);
  signal preTrig_cnt_zero : std_logic_vector(LEVEL-1 downto 0);

  signal trc_enable_i : std_logic_vector(LEVEL-1 downto 0);

  signal trigger_activ : std_logic_vector(EVENTS*LEVEL-1 downto 0);
  signal trigger_or    : std_logic_vector(LEVEL-1 downto 0);

begin

  assert EVENTS <= 256
    report "ERROR: Too many trigger-events per trigger."
    severity error;

  -- trace enable

  trc_enable <= trc_enable_i;

  -- activ and inactiv triggers
  activ_gen : for i in 0 to EVENTS-1 generate
    trigger_activ((i+1)*LEVEL-1 downto i*LEVEL) <= trigger_in((i+1)*LEVEL-1 downto i*LEVEL) and
                                                   (LEVEL-1 downto 0 => activ_r(i));
  end generate activ_gen;

  -- or-connection
  or_gen : for i in 0 to LEVEL-1 generate
    signal selected_values : std_logic_vector(EVENTS-1 downto 0);
  begin
    sel_gen : for j in 0 to EVENTS-1 generate
      selected_values(j) <= trigger_activ((j*LEVEL)+i);
    end generate sel_gen;
    trigger_or(i) <= '1' when unsigned(selected_values) /= 0 else '0';
  end generate or_gen;

  trc_enable_i     <= (others => '1') when (mode_r = PostTrigger or mode_r = CenterTrigger) and type_r /= Stop else
                      (others => '0');

  send_start       <= trigger_or when type_r = Start else
                      (others => '0');

  send_stop        <= trigger_or when type_r = Stop else
                      (others => '0');

  send_do          <= not preTrig_cnt_zero or trigger_or when type_r = Normal else
                      (others => '0');

  preTrig_cnt_set <= trigger_or when (type_r = Normal)
                                and (mode_r = CenterTrigger or mode_r = PreTrigger) else
                     (others => '0');

  -- pre-trigger

  preTrig_cnt_dec  <= not preTrig_cnt_zero and not preTrig_cnt_set;

  preTrig_zero_gen : for i in 0 to LEVEL-1 generate
    preTrig_cnt_zero(i) <= '1' when preTrig_cnt_r(i) = 0 else '0';
  end generate preTrig_zero_gen;

  -- set registers

  set_regs_gen : for i in 0 to EVENTS-1 generate
    activ_nxt(i) <= not activ_r(i) when setActivSel = to_unsigned(i, setActivSel'length)
                                    and setActiv = '1'
                                   else activ_r(i);
  end generate set_regs_gen;

  mode_nxt  <= setModeValue when setMode = '1' else mode_r;
  type_nxt  <= setTypeValue when setType = '1' else type_r;

  clk_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        activ_r <= ACTIV_INIT;
        mode_r  <= MODE_INIT;
        type_r  <= TYPE_INIT;
        preTrig_cnt_r <= (others => (others => '0'));
      else
        activ_r <= activ_nxt;
        mode_r <= mode_nxt;
        type_r <= type_nxt;

        for i in 0 to LEVEL-1 loop

          if preTrig_cnt_set(i) = '1' then
            preTrig_cnt_r(i) <= to_unsigned(PRETRIGGER_INT, log2ceil(PRETRIGGER_INT+1));
          elsif preTrig_cnt_dec(i) = '1' then -- after set
            preTrig_cnt_r(i) <= preTrig_cnt_r(i) - 1;
          end if;

        end loop;

      end if;
    end if;
  end process clk_proc;

end rtl;
