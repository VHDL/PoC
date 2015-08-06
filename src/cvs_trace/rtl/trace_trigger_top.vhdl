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
-- Entity: trace_trigger_top
-- Author(s): Stefan Alex
-- 
------------------------------------------------------
-- Top-Level-Component for Trigger                  --
------------------------------------------------------
--
-- Revision:    $Revision: 1.3 $
-- Last change: $Date: 2010-04-24 18:25:26 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_types.all;
use poc.trace_functions.all;
use poc.trace_config.all;
use poc.trace_internals.all;

entity trace_trigger_top is
  generic (
    SINGLE_EVENTS           : tSingleEvent_array;
    TRIGGER_ARRAY           : tTrigger_array;
    SINGLE_EVENTS_PORT_BITS : positive;
    TRIGGER_OUT_BITS        : positive;
    TRIG_REG_INDEX_BITS     : positive;
    TRIG_REG_MAX_BITS       : positive;
    TRIGGER_CNT             : positive;
    TRIGGER_MAX_EVENTS      : positive
    );
  port (
    -- globals
    clk : in  std_logic;
    rst : in  std_logic;
    err : out std_logic;
    rsp : out std_logic;

    -- data-values from ports
    ports_in : in std_logic_vector(SINGLE_EVENTS_PORT_BITS-1 downto 0);

    -- output to tracer
    trc_enables_out : out std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
    send_starts_out : out std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
    send_stops_out  : out std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
    send_dos_out    : out std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);

    -- controller
    setReg       : in std_logic;
    setRegIndex  : in unsigned(TRIG_REG_INDEX_BITS-1 downto 0);
    setRegValue  : in std_logic_vector(TRIG_REG_MAX_BITS-1 downto 0);
    setCmp       : in std_logic;
    set1CmpValue : in tTriggerCmp1;
    set2CmpValue : in tTriggerCmp2;
    setTrigIndex : in unsigned(log2ceilnz(TRIGGER_CNT)-1 downto 0);
    setActiv     : in std_logic;
    setActivSel  : in unsigned(log2ceilnz(notZero(TRIGGER_MAX_EVENTS))-1 downto 0);
    setMode      : in std_logic;
    setModeValue : in tTriggerMode;
    setType      : in std_logic;
    setTypeValue : in tTriggerType;

    fired     : out std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
    fired_stb : out std_logic
  );
end trace_trigger_top;

architecture rtl of trace_trigger_top is

  constant SINGLE_EVENT_CNT        : natural := countSingleEvents(SINGLE_EVENTS);
  constant SINGLE_EVENT_LEVEL_CNT  : positive := sumSingleEventsLevel(SINGLE_EVENTS);
  constant COMPLEX_EVENTS          : tComplexEvent_array
                                   := getComplexEventsNoDoublings(TRIGGER_ARRAY);
  constant COMPLEX_EVENT_CNT       : natural  := countComplexEvents(COMPLEX_EVENTS);
  constant COMPLEX_EVENT_LEVEL_CNT : natural  := sumComplexEventsLevel(COMPLEX_EVENTS, SINGLE_EVENTS);

  signal single_events_all  : std_logic_vector(notZero(SINGLE_EVENT_LEVEL_CNT)-1 downto 0);
  signal complex_events_all : std_logic_vector(notZero(COMPLEX_EVENT_LEVEL_CNT)-1 downto 0);

  signal reg_sel_err : std_logic_vector(SINGLE_EVENT_CNT-1 downto 0);

  signal trc_enables_out_i : std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
  signal send_starts_out_i : std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
  signal send_stops_out_i  : std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
  signal send_dos_out_i    : std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);

begin

  assert noDoubleId(SINGLE_EVENTS)
    report "ERROR: Double-id in single-events."
    severity error;

  assert noDoubleId(TRIGGER_ARRAY)
    report "ERROR: Double-id in trigger."
    severity error;

  assert SINGLE_EVENT_CNT < 128
    report "ERROR: Too many trigger-single-events."
    severity error;

  assert TRIGGER_CNT < 256
    report "ERROR: Too many triggers."
    severity error;

  -----------
  -- error --
  -----------

  err <= '1' when (setTrigIndex > to_unsigned(TRIGGER_CNT-1, log2ceilnz(TRIGGER_CNT)) and (setActiv or setMode or setType) = '1')
               or (setRegIndex(setRegIndex'left-1 downto 0) > to_unsigned(SINGLE_EVENT_CNT-1, log2ceilnz(SINGLE_EVENT_CNT)) and (setCmp or setReg) = '1')
               or (not is_x(reg_sel_err) and (unsigned(reg_sel_err) /= 0) and setReg = '1')  else '0';
  rsp <= setActiv or setMode or setType or setCmp or setReg;

  --------------------------------------------------
  -- generate the trigger-registers/single-events --
  --------------------------------------------------

  single_event_gen : for i in 0 to SINGLE_EVENT_CNT-1 generate
    constant LEVEL       : positive := SINGLE_EVENTS(i).PORT_IN.INPUTS;
    constant WIDTH       : positive := SINGLE_EVENTS(i).PORT_IN.WIDTH;
    constant TWO_REGS    : boolean  := SINGLE_EVENTS(i).TWO_REGS;
    constant PORT_INDEX  : natural  := sumSingleEventsPortBits(SINGLE_EVENTS, i);
    constant EVENT_INDEX : natural  := sumSingleEventsLevel(SINGLE_EVENTS, i);

    signal index_matches : std_logic;
    signal values        : std_logic_vector(WIDTH*LEVEL-1 downto 0);
    signal events        : std_logic_vector(LEVEL-1 downto 0);

  begin

    index_matches <= '1' when setRegIndex(setRegIndex'left-1 downto 0) = to_unsigned(i, setRegIndex'length-1)
                         else '0';

    values <= ports_in(PORT_INDEX+WIDTH*LEVEL-1 downto PORT_INDEX);

    -- one register for comparision

    one_reg_gen : if not TWO_REGS generate
      constant REG_INIT : std_logic_vector(MAX_PORT_WIDTH-1 downto 0) := SINGLE_EVENTS(i).REG1_INIT;
      constant CMP_INIT : tTriggerCmp1                                := SINGLE_EVENTS(i).CMP1_INIT;
      signal setReg_i   : std_logic;
      signal setCmp_i   : std_logic;
    begin

      with index_matches select
        setReg_i <= setReg when '1',
                    '0'    when others;

      with index_matches select
        setCmp_i <= setCmp  when '1',
                    '0'     when others;

      reg_sel_err(i) <= setRegIndex(setRegIndex'left);

      singleRegister_inst : trace_triggerSingleRegister
        generic map (
          INPUTS     => LEVEL,
          WIDTH      => WIDTH,
          REG_INIT   => REG_INIT,
          CMP_INIT   => CMP_INIT
        )
        port map (
          clk         => clk,
          rst         => rst,
          values_in   => values,
          events      => events,
          setReg      => setReg_i,
          setRegValue => setRegValue(WIDTH-1 downto 0),
          setCmp      => setCmp_i,
          setCmpValue => set1CmpValue
        );

    end generate one_reg_gen;

    -- two registers for comparision

    two_regs_gen : if TWO_REGS generate
      constant REG1_INIT : std_logic_vector(MAX_PORT_WIDTH-1 downto 0) := SINGLE_EVENTS(i).REG1_INIT;
      constant REG2_INIT : std_logic_vector(MAX_PORT_WIDTH-1 downto 0) := SINGLE_EVENTS(i).REG2_INIT;
      constant CMP2_INIT : tTriggerCmp2                                := SINGLE_EVENTS(i).CMP2_INIT;
      signal setReg1_i   : std_logic;
      signal setReg2_i   : std_logic;
      signal setReg_i    : std_logic;
      signal setCmp_i    : std_logic;
    begin

      with index_matches select
        setReg_i <= setReg when '1',
                    '0'    when others;

      setReg1_i <= setReg_i and not setRegIndex(setRegIndex'left);
      setReg2_i <= setReg_i and setRegIndex(setRegIndex'left);

      with index_matches select
        setCmp_i <= setCmp  when '1',
                    '0'     when others;

      reg_sel_err(i) <= '0';

      doubleRegister_inst : trace_triggerDoubleRegister
        generic map (
          INPUTS     => LEVEL,
          WIDTH      => WIDTH,
          REG1_INIT  => REG1_INIT,
          REG2_INIT  => REG2_INIT,
          CMP_INIT   => CMP2_INIT
        )
        port map (
          clk          => clk,
          rst          => rst,
          values_in    => values,
          events       => events,
          setReg1      => setReg1_i,
          setReg1Value => setRegValue(WIDTH-1 downto 0),
          setReg2      => setReg2_i,
          setReg2Value => setRegValue(WIDTH-1 downto 0),
          setCmp       => setCmp_i,
          setCmpValue  => set2CmpValue
        );

    end generate two_regs_gen;

    -- or-connect level

    level_or_gen : if SINGLE_EVENTS(i).LEVEL_OR generate
      single_events_all(EVENT_INDEX) <= '1' when unsigned(events) /= 0 else '0';
    end generate level_or_gen;

    no_level_or_gen : if not SINGLE_EVENTS(i).LEVEL_OR generate
      single_events_all(EVENT_INDEX+LEVEL-1 downto EVENT_INDEX) <= events;
    end generate no_level_or_gen;

  end generate single_event_gen;

  ---------------------------------
  -- generate the complex events --
  ---------------------------------

  complex_events_gen : for i in 0 to COMPLEX_EVENT_CNT-1 generate
    constant SINGLE_EVENT_CNT_I  : natural  := countSingleEvents(COMPLEX_EVENTS(i));
    constant COMPLEX_EVENT_INDEX : natural  := sumComplexEventsLevel(COMPLEX_EVENTS, SINGLE_EVENTS, i);
    constant COMPLEX_EVENT_LEVEL : positive := getComplexEventLevel(COMPLEX_EVENTS(i), SINGLE_EVENTS);
  begin

    level_gen : for j in 0 to COMPLEX_EVENT_LEVEL-1 generate
      signal se : std_logic_vector(SINGLE_EVENT_CNT_I-1 downto 0);
    begin

      single_event_sel : for k in 0 to SINGLE_EVENT_CNT_I-1 generate
        constant SINGLE_EVENT_INDEX : natural := sumSingleEventsLevel(SINGLE_EVENTS,
                                                 getSingleEventIndex(SINGLE_EVENTS, COMPLEX_EVENTS(i)(k)));
        constant SINGLE_EVENT_LEVEL : natural := getSingleEventLevel(getSingleEvent(SINGLE_EVENTS, COMPLEX_EVENTS(i)(k)));
      begin
        se(k) <= single_events_all(SINGLE_EVENT_INDEX+ifThenElse(SINGLE_EVENT_LEVEL=1, 0, j));
      end generate single_event_sel;

      complex_events_all(COMPLEX_EVENT_INDEX+j) <= '1' when se = (se'left downto 0 => '1') else '0';

    end generate level_gen;

  end generate complex_events_gen;

  --------------------------------------
  -- generate the trigger and outputs --
  --------------------------------------

  trigger_gen : for i in 0 to TRIGGER_CNT-1 generate
    constant LEVEL     : positive := getTriggerLevel(TRIGGER_ARRAY(i), SINGLE_EVENTS);
    constant EVENTS    : positive := getTriggerEvents(TRIGGER_ARRAY(i));
    constant OUT_INDEX : natural  := sumTriggerOutBits(TRIGGER_ARRAY, SINGLE_EVENTS, i);
    signal trigger_in   : std_logic_vector(EVENTS*LEVEL-1 downto 0);
    signal trc_enable_i : std_logic_vector(LEVEL-1 downto 0);
    signal send_start_i : std_logic_vector(LEVEL-1 downto 0);
    signal send_stop_i  : std_logic_vector(LEVEL-1 downto 0);
    signal send_do_i    : std_logic_vector(LEVEL-1 downto 0);

    signal setActiv_i : std_logic;
    signal setType_i  : std_logic;
    signal setMode_i  : std_logic;
    signal index_matches : std_logic;
  begin

    -- multiplex incoming commands

    index_matches <= '1' when setTrigIndex = to_unsigned(i, setTrigIndex'length) else '0';

    with index_matches select
      setActiv_i <= setActiv when '1',
                    '0'      when others;

    with index_matches select
      setMode_i <= setMode when '1',
                   '0'     when others;

    with index_matches select
      setType_i <= setType when '1',
                   '0'     when others;

    -- 1. single events
    single_events_gen : for j in 0 to countSingleEvents(TRIGGER_ARRAY(i).SINGLE_EVENT_IDS)-1 generate
      constant SINGLE_EVENT       : tSingleEvent := getSingleEvent(SINGLE_EVENTS, TRIGGER_ARRAY(i).SINGLE_EVENT_IDS(j));
      constant SINGLE_EVENT_INDEX : natural      := sumSingleEventsLevel(SINGLE_EVENTS,
                                                                         getSingleEventIndex(SINGLE_EVENTS,
                                                                         SINGLE_EVENT.ID));
      constant TRIGGER_INDEX      : natural      := LEVEL*j;
    begin

      level_gen : if not SINGLE_EVENT.LEVEL_OR generate
        constant SINGLE_EVENT_LEVEL : positive := SINGLE_EVENT.PORT_IN.INPUTS;
      begin

        assert SINGLE_EVENT_LEVEL = LEVEL
          report "ERROR: Check level in single-event "&integer'image(SINGLE_EVENT.ID)& " and trigger "&integer'image(TRIGGER_ARRAY(i).ID)&"."
          severity error;

        trigger_in(TRIGGER_INDEX+LEVEL-1 downto TRIGGER_INDEX)
                                  <= single_events_all(SINGLE_EVENT_INDEX+LEVEL-1 downto SINGLE_EVENT_INDEX);
      end generate level_gen;

      no_level_gen : if SINGLE_EVENT.LEVEL_OR generate
        trigger_in(TRIGGER_INDEX+LEVEL-1 downto TRIGGER_INDEX)
                                  <= (others => single_events_all(SINGLE_EVENT_INDEX));
      end generate no_level_gen;

    end generate single_events_gen;

    -- 2. complex events

    complex_events_gen : for j in 0 to countComplexEvents(TRIGGER_ARRAY(i).COMPLEX_EVENTS)-1 generate
      constant COMPLEX_EVENT_INDEX : natural := sumComplexEventsLevel(COMPLEX_EVENTS, SINGLE_EVENTS,
                                                getComplexEventIndex(COMPLEX_EVENTS,
                                                TRIGGER_ARRAY(i).COMPLEX_EVENTS(j)));
      constant TRIGGER_INDEX       : natural := LEVEL*(j+countSingleEvents(TRIGGER_ARRAY(i).SINGLE_EVENT_IDS));
      constant COMPLEX_EVENT_LEVEL : natural := getComplexEventLevel(TRIGGER_ARRAY(i).COMPLEX_EVENTS(j), SINGLE_EVENTS);
    begin

      level_gen : if COMPLEX_EVENT_LEVEL > 1 generate
      begin

        assert COMPLEX_EVENT_LEVEL = LEVEL
          report "ERROR: Check level in complex-event and trigger "&integer'image(TRIGGER_ARRAY(i).ID)&"."
          severity error;

        trigger_in(TRIGGER_INDEX+LEVEL-1 downto TRIGGER_INDEX)
                                  <= complex_events_all(COMPLEX_EVENT_INDEX+LEVEL-1 downto 0);
      end generate level_gen;

      no_level_gen : if COMPLEX_EVENT_LEVEL = 1 generate
        trigger_in(TRIGGER_INDEX+LEVEL-1 downto TRIGGER_INDEX)
                                  <= (others => complex_events_all(COMPLEX_EVENT_INDEX));
      end generate no_level_gen;

    end generate complex_events_gen;

    -- instantiate trigger

    trigger_inst : trace_trigger
      generic map (
        EVENTS         => EVENTS,
        LEVEL          => LEVEL,
        MODE_INIT      => TRIGGER_ARRAY(i).MODE_INIT,
        TYPE_INIT      => TRIGGER_ARRAY(i).TYPE_INIT,
        ACTIV_INIT     => (EVENTS-1 downto 0 => '1'),
        PRETRIGGER_INT => PRETRIGGER_INT
      )
      port map (
        clk          => clk,
        rst          => rst,
        trigger_in   => trigger_in,
        trc_enable   => trc_enable_i,
        send_start   => send_start_i,
        send_stop    => send_stop_i,
        send_do      => send_do_i,
        setMode      => setMode_i,
        setModeValue => setModeValue,
        setType      => setType_i,
        setTypeValue => setTypeValue,
        setActiv     => setActiv_i,
        setActivSel  => setActivSel(log2ceilnz(EVENTS)-1 downto 0)
      );

    trc_enables_out_i(OUT_INDEX+LEVEL-1 downto OUT_INDEX) <= trc_enable_i;
    send_starts_out_i(OUT_INDEX+LEVEL-1 downto OUT_INDEX) <= send_start_i;
    send_stops_out_i(OUT_INDEX+LEVEL-1 downto OUT_INDEX)  <= send_stop_i;
    send_dos_out_i(OUT_INDEX+LEVEL-1 downto OUT_INDEX)    <= send_do_i;

  end generate trigger_gen;

  trc_enables_out <= trc_enables_out_i;
  send_starts_out <= send_starts_out_i;
  send_stops_out  <= send_stops_out_i;
  send_dos_out    <= send_dos_out_i;

  --------------------------
  -- trigger-inform-logic --
  --------------------------

  trigger_inform_gen : if TRIGGER_INFORM generate
    signal trigger_r     : std_logic_vector(TRIGGER_OUT_BITS-1 downto 0) := (others => '0');
    signal trigger_fires : std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
    signal trigger_fired : std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
  begin
    trigger_fires <= send_starts_out_i or send_stops_out_i or send_dos_out_i;
    trigger_fired <= not trigger_r and trigger_fires;

    clk_proc : process(clk)
    begin
      if rising_edge(clk) then
        if rst = '1' then
          trigger_r <= (others => '0');
        else
          trigger_r <= trigger_fires;
        end if;
      end if;
    end process clk_proc;

    fired     <= trigger_fired;
    fired_stb <= '1' when unsigned(trigger_fired) /= 0 else '0';

  end generate trigger_inform_gen;

  no_trigger_inform_gen : if not TRIGGER_INFORM generate
    fired     <= (others => '0');
    fired_stb <= '0';
  end generate no_trigger_inform_gen;
end rtl;
