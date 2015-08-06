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
-- Entity: trace_top
-- Author(s): Stefan Alex, Martin Zabel
-- 
------------------------------------------------------
-- Top-Level-Component                              --
--
-- Comments/Changes by MZ:
-- -----------------------
-- trace_running is associated with clk_trc
--
-- tracer control (trigger) and data signals are pipelined in this
-- component again, to shorten critical path when complex trigger
-- must be calculated.
--
-- Indices into inst_*, mem_* message_* and statistic_* ports can be calculated
-- by the public function getPortValueIndex(...) and getPortStbIndex(...)
-- defined in trace.vhdl.
------------------------------------------------------
--
-- Revision:    $Revision: 1.14 $
-- Last change: $Date: 2010-04-30 14:39:12 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_config.all;
use poc.trace_functions.all;
use poc.trace_types.all;
use poc.trace_internals.all;
use poc.trace.all;

entity trace_top is
  port(
    -- global signals
    clk_trc       : in  std_logic;
    rst_trc       : in  std_logic;
    clk_sys       : in  std_logic;
    rst_sys       : in  std_logic;
    trace_running : out std_logic;

    -- instruction-trace
    inst_values        : in std_logic_vector(INST_ADR_BITS-1 downto 0);
    inst_stbs          : in std_logic_vector(INST_STB_BITS-1 downto 0);
    inst_branch_values : in std_logic_vector(INST_BRANCH_BITS-1 downto 0);
    inst_branch_stbs   : in std_logic_vector(INST_BRANCH_STB_BITS-1 downto 0);

    -- mem-trace
    mem_adr_values    : in std_logic_vector(MEM_ADR_BITS-1 downto 0);
    mem_adr_stbs      : in std_logic_vector(MEM_ADR_STB_BITS-1 downto 0);
    mem_data_values   : in std_logic_vector(MEM_DAT_BITS-1 downto 0);
    mem_data_stbs     : in std_logic_vector(MEM_DAT_STB_BITS-1 downto 0);
    mem_source_values : in std_logic_vector(MEM_SOURCE_BITS-1 downto 0);
    mem_source_stbs   : in std_logic_vector(MEM_SOURCE_STB_BITS-1 downto 0);
    mem_rw_values     : in std_logic_vector(MEM_RW_BITS-1 downto 0);
    mem_rw_stbs       : in std_logic_vector(MEM_RW_STB_BITS-1 downto 0);

    -- message-trace
    message_values : in std_logic_vector(MESSAGE_BITS-1 downto 0);
    message_stbs   : in std_logic_vector(MESSAGE_STB_BITS-1 downto 0);

    -- statistic-trace
    statistic_incs : in std_logic_vector(STAT_BITS-1 downto 0);
    statistic_rsts : in std_logic_vector(STAT_BITS-1 downto 0);

    -- trigger-output
    trigger_out : out std_logic_vector(TRIGGER_BITS-1 downto 0);

    -- ICE interface
    system_stall : out std_logic;
    regs_in      : in  std_logic_vector(ICE_REG_BITS-1 downto 0);
    regs_out     : out std_logic_vector(ICE_REG_BITS-1 downto 0);
    store        : out std_logic_vector(ICE_REG_CNT_NZ-1 downto 0);

    -- incoming messegas
    eth_full : out std_logic;
    eth_din  : in  std_logic_vector(7 downto 0);
    eth_put  : in  std_logic;

    -- outgoing messages
    eth_valid   : out std_logic;
    eth_last    : out std_logic;
    eth_dout    : out std_logic_vector(7 downto 0);
    eth_got     : in  std_logic;
    header      : out std_logic;
    eth_finish  : in  std_logic
  );
end trace_top;

architecture Behavioral of trace_top is

  -----------------------------------------------------------------------------
  -- CONSTANTS derived from trace_config
  -----------------------------------------------------------------------------

  -- process input-data
  -- sort all arrays, so that null-values are placed at the end
  -- For ports: this does not affect ValueIndex and StbIndex as returned by
  -- getPortvalueIndex() and getPortStbIndex()

  constant INST_TRACER_GENS_I    : tInstGens    := removeNullValues(INST_TRACER_GENS);
  constant MEM_TRACER_GENS_I     : tMemGens     := removeNullValues(MEM_TRACER_GENS);
  constant MESSAGE_TRACER_GENS_I : tMessageGens := removeNullValues(MESSAGE_TRACER_GENS);

  constant INST_PORTS_I        : tPorts := removeNullValues(INST_PORTS);
  constant INST_BRANCH_PORTS_I : tPorts := removeNullValues(INST_BRANCH_PORTS);
  constant MEM_ADR_PORTS_I     : tPorts := removeNullValues(MEM_ADR_PORTS);
  constant MEM_DATA_PORTS_I    : tPorts := removeNullValues(MEM_DATA_PORTS);
  constant MEM_SOURCE_PORTS_I  : tPorts := removeNullValues(MEM_SOURCE_PORTS);
  constant MEM_RW_PORTS_I      : tPorts := removeNullValues(MEM_RW_PORTS);
  constant MESSAGE_PORTS_I     : tPorts := removeNullValues(MESSAGE_PORTS);
  constant STATISTIC_PORTS_I   : tPorts := removeNullValues(STATISTIC_PORTS);

  constant TRIGGER_RECORDS_ALL : tTrigger_array
                               := removeNullValues(TRIGGER_RECORDS);
  constant SINGLE_EVENTS_ALL   : tSingleEvent_array
                               := removeNullValues(SINGLE_EVENT_RECORDS);

  -- Tracer

  constant TRACER_CNT_TMP     : positive := countTracer(INST_TRACER_GENS_I, MEM_TRACER_GENS_I, MESSAGE_TRACER_GENS_I);
  constant TRACER_GEN_CNT_TMP : positive := countTracerGens(INST_TRACER_GENS_I, MEM_TRACER_GENS_I, MESSAGE_TRACER_GENS_I);

  constant DO_RESYNC : boolean := haveMessageResync(MESSAGE_TRACER_GENS_I);

  -- Trigger

  constant ICE_TRIGGER_IDS_I      : tNat_array
                                  := getValuesNoDoublings(getValuesGreaterThan(ICE_TRIGGER, 0));
  constant ICE_TRIGGER_IDS_CNT    : natural := countValuesGreaterThan(ICE_TRIGGER_IDS_I, 0);

  constant TRACER_TRIGGER_IDS_I   : tNat_array
                                  := getTriggerIds(INST_TRACER_GENS_I, MEM_TRACER_GENS_I, MESSAGE_TRACER_GENS_I);

  constant TRIGGER_CNT            : natural := countValuesGreaterThanNoDoublings((ICE_TRIGGER_IDS_I & TRACER_TRIGGER_IDS_I), 0);
  constant TRIGGER_IDS            : tNat_array
                                  := removeValue(getValuesNoDoublings(ICE_TRIGGER_IDS_I & TRACER_TRIGGER_IDS_I), 0);

  constant TRIGGER_ARRAY          : tTrigger_array
                                  := getTrigger(TRIGGER_RECORDS_ALL, TRIGGER_IDS);


  constant TRIGGER_MAX_EVENTS      : natural := getTriggerMaxEvents(TRIGGER_ARRAY);

  constant SINGLE_EVENT_IDS        : tNat_array := getValuesNoDoublings(getSingleEventIds(TRIGGER_ARRAY));

  constant SINGLE_EVENTS           : tSingleEvent_array
                                   := getSingleEvents(SINGLE_EVENTS_ALL, SINGLE_EVENT_IDS);
  constant SINGLE_EVENT_CNT        : natural := countSingleEvents(SINGLE_EVENTS);

  constant SINGLE_EVENTS_PORT_BITS : natural
                                   := sumSingleEventsPortBits(SINGLE_EVENTS);


  constant HAVE_TRIGGER        : boolean    := TRIGGER_CNT > 0;
  constant HAVE_ICE_TRIGGER    : boolean    := ICE_TRIGGER_IDS_CNT > 0;
  constant TRIG_REG_INDEX_BITS : positive   := log2ceilnz(notZero(SINGLE_EVENT_CNT))+1;
  constant TRIG_REG_BITS       : tNat_array := getSingleEventsRegBits(SINGLE_EVENTS);
  constant TRIG_REG_MAX_BITS   : natural    := getSingleEventsRegMaxBits(SINGLE_EVENTS);
  constant TRIGGER_INFORM_I    : boolean    := TRIGGER_INFORM and TRIGGER_CNT > 0;

  constant TRIG_CMP1_BITS  : positive := log2ceilnz(getEnumIndex(tTriggerCmp1'right)+1);
  constant TRIG_CMP2_BITS  : positive := log2ceilnz(getEnumIndex(tTriggerCmp2'right)+1);
  constant TRIG_TYPE_BITS  : positive := log2ceilnz(getEnumIndex(tTriggerType'right)+1);
  constant TRIG_MODE_BITS  : positive := log2ceilnz(getEnumIndex(tTriggerMode'right)+1);
  constant TRIG_ACTIV_BITS : positive := log2ceilnz(notZero(getTriggerMaxEvents(TRIGGER_ARRAY)));

  constant TRIGGER_OUT_BITS : natural := sumTriggerOutBits(TRIGGER_ARRAY, SINGLE_EVENTS);

  -- User-defined Ports

  constant PORTS_ALL        : tPorts := merge(INST_PORTS_I, INST_BRANCH_PORTS_I,
                                              MEM_ADR_PORTS_I, MEM_DATA_PORTS_I, MEM_SOURCE_PORTS_I,
                                              MEM_RW_PORTS_I, MESSAGE_PORTS_I, STATISTIC_PORTS_I);

  constant TRIGGER_PORTS    : tPorts := getSingleEventsPorts(SINGLE_EVENTS);

  constant TRACER_PORTS_TMP : tPorts := getPorts(INST_TRACER_GENS_I, MEM_TRACER_GENS_I, MESSAGE_TRACER_GENS_I);

  constant PORTS_TMP        : tPorts := mergeNoDoublings(TRACER_PORTS_TMP, TRIGGER_PORTS);

  -- Controller

  constant CTRL_MESSAGE_WIDTH  : positive    := (TRACER_CNT_TMP+1)*2+2+ifThenElse(CYCLE_ACCURATE,1, 0)+ifThenElse(TRIGGER_INFORM_I, TRIGGER_OUT_BITS, 0);

  constant CTRL_MESSAGE_PORT   : tPort       := (ID     => getNewId(PORTS_ALL),
                                                 WIDTH  => CTRL_MESSAGE_WIDTH,
                                                 INPUTS => 1,
                                                 COMP   => noneC);

  constant CTRL_MESSAGE_PORTS  : tPorts      := appendFirst((0 to MESSAGE_PORTS_PER_INSTANCE-2 => NULL_PORT), CTRL_MESSAGE_PORT);

  constant CTRL_MESSAGE_TRACER : tMessageGen := (MSG_PORTS   => CTRL_MESSAGE_PORTS,
                                                 FIFO_DEPTH  => 31,  -- 2^n-1
                                                 FIFO_SDS    => 1,
                                                 RESYNC      => false,
                                                 PRIORITY    => 5,
                                                 TRIGGER     => NULL_TRIGGER_IDS,
                                                 INSTANTIATE => true);

  constant INST_TRACER_ALL    : tInstGens    := INST_TRACER_GENS_I;
  constant MEM_TRACER_ALL     : tMemGens     := MEM_TRACER_GENS_I;
  constant MESSAGE_TRACER_ALL : tMessageGens := removeNullValues(append(MESSAGE_TRACER_GENS_I, CTRL_MESSAGE_TRACER));

  constant TRACER_CNT : positive := TRACER_CNT_TMP+1;

  constant INST_TRACER_GEN_CNT    : natural := countTracerGens(INST_TRACER_ALL);
  constant MEM_TRACER_GEN_CNT     : natural := countTracerGens(MEM_TRACER_ALL);
  constant MESSAGE_TRACER_GEN_CNT : natural := countTracerGens(MESSAGE_TRACER_ALL);

  constant TRACER_GEN_CNT   : natural := INST_TRACER_GEN_CNT + MEM_TRACER_GEN_CNT + MESSAGE_TRACER_GEN_CNT;

  constant PRIORITIES       : tPrio_array
                            := getPriorities(INST_TRACER_ALL, MEM_TRACER_ALL, MESSAGE_TRACER_ALL);

  constant TRACER_DATA_BITS : tNat_array := getTracerDataOutBits(INST_TRACER_ALL, MEM_TRACER_ALL,
                                                                 MESSAGE_TRACER_ALL, ifThenElse(CYCLE_ACCURATE, TIME_BITS, 0), PRIORITIES);


  -- Ports

  constant PORTS           : tPorts  := merge(PORTS_TMP, CTRL_MESSAGE_PORTS);
  constant PORT_CNT        : natural := countPorts(PORTS);

  constant PORT_VALUE_BITS : positive := notZero(calculateValueBits(PORTS));
  constant PORT_STB_BITS   : positive := notZero(calculateStbBits(PORTS));

  -----------------------------------------------------------------------------
  -- SIGNALS
  -----------------------------------------------------------------------------
  -- Ports

  signal port_values : std_logic_vector(PORT_VALUE_BITS-1 downto 0);
  signal port_stbs   : std_logic_vector(PORT_STB_BITS-1 downto 0);

  -- Trigger

  signal trig_reg_set   : std_logic;
  signal trig_reg_index : unsigned(TRIG_REG_INDEX_BITS-1 downto 0);
  signal trig_reg_val   : std_logic_vector(notZero(TRIG_REG_MAX_BITS)-1 downto 0);
  signal trig_cmp_set   : std_logic;
  signal trig_cmp1_val  : tTriggerCmp1;
  signal trig_cmp2_val  : tTriggerCmp2;
  signal trig_index     : unsigned(log2ceilnz(notZero(TRIGGER_CNT))-1 downto 0);
  signal trig_mode_set  : std_logic;
  signal trig_mode_val  : tTriggerMode;
  signal trig_type_set  : std_logic;
  signal trig_type_val  : tTriggerType;
  signal trig_activ_set : std_logic;
  signal trig_activ_sel : unsigned(TRIG_ACTIV_BITS-1 downto 0);
  signal trig_fired     : std_logic_vector(notZero(TRIGGER_OUT_BITS)-1 downto 0);
  signal trig_fired_stb : std_logic;
  signal trig_err       : std_logic;
  signal trig_rsp       : std_logic;

   -- Tracer

  signal trigger_trc_enables : std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
  signal trigger_send_starts : std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
  signal trigger_send_stops  : std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
  signal trigger_send_dos    : std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);

  signal resync  : std_logic;
  signal adr_en  : std_logic;
  signal data_en : std_logic;

  signal tracer_data        : std_logic_vector(sum(TRACER_DATA_BITS)-1 downto 0);
  signal tracer_data_fill   : std_logic_vector(sum(log2ceilnz(TRACER_DATA_BITS))-1 downto 0);
  signal tracer_data_last   : std_logic_vector(TRACER_CNT-1 downto 0);
  signal tracer_data_got    : std_logic_vector(TRACER_CNT-1 downto 0);
  signal tracer_data_se     : std_logic_vector(TRACER_CNT-1 downto 0);
  signal tracer_data_valid  : std_logic_vector(TRACER_CNT-1 downto 0);
  signal tracer_sel         : std_logic_vector(TRACER_CNT-1 downto 0);
  signal tracer_ovs         : std_logic_vector(TRACER_CNT-1 downto 0);
  signal tracer_ov_starts   : std_logic_vector(TRACER_CNT-1 downto 0);
  signal tracer_ov_stops    : std_logic_vector(TRACER_CNT-1 downto 0);
  signal tracer_ov_dangers  : std_logic_vector(TRACER_CNT-1 downto 0);
  signal tracer_stb_en      : std_logic;
  signal tracer_stbs        : std_logic_vector(TRACER_CNT-1 downto 0);

  signal trace_running_i : std_logic;
  
  signal trc_enable_trig  : std_logic_vector(TRACER_CNT-1 downto 0);
  signal send_enable_trig : std_logic_vector(TRACER_CNT-1 downto 0);

  signal ctrl_message_stbs   : std_logic_vector(0 downto 0);
  signal ctrl_message_values : std_logic_vector(CTRL_MESSAGE_WIDTH-1 downto 0);

  signal filter_data : std_logic;
  signal filter_adr  : std_logic;

  -- Statistics
  signal statistic_values : std_logic_vector(calculateValueBits(STATISTIC_PORTS)-1 downto 0);
  signal statistic_stbs   : std_logic_vector(calculateStbBits(STATISTIC_PORTS)-1 downto 0);

begin

  -------------
  -- General --
  -------------

  -- not more than 255 ice-register
  assert countValuesGreaterThan(ICE_REGISTERS, 0) < 256
    report "ERROR: Too many ice-registers defined."
    severity error;

  -- ice-register should not be greater than 256
  assert countValuesGreaterThan(ICE_REGISTERS, 256) = 0
    report "ERROR: ICE-Register too large."
    severity error;

  -----------------------------------
  -- Generate Statistic-Components --
  -----------------------------------

  stat_gen : for i in 0 to countPorts(STATISTIC_PORTS_I)-1 generate
    cond_gen : if containsPort(PORTS, STATISTIC_PORTS_I(i).ID) generate
      constant WIDTH  : positive := STATISTIC_PORTS_I(i).WIDTH;
      constant INPUTS : positive := STATISTIC_PORTS_I(i).INPUTS;
    begin

      inputs_gen : for j in 0 to INPUTS-1 generate
        constant SRC_INDEX   : natural := calculateStbBits(STATISTIC_PORTS_I, i)+j;
        constant VALUE_INDEX : natural := getPortValueIndex(STATISTIC_PORTS_I, STATISTIC_PORTS_I(i).ID) + j*WIDTH;
        constant STB_INDEX   : natural := getPortStbIndex(STATISTIC_PORTS_I, STATISTIC_PORTS_I(i).ID)+j;
      begin

        statistic_inst : trace_statistic
          generic map (
            COUNTER_BITS => WIDTH
          )
          port map (
            clk_trc       => clk_trc,
            rst_trc       => rst_trc,
            inc           => statistic_incs(SRC_INDEX),
            rst           => statistic_rsts(SRC_INDEX),
            counter_value => statistic_values(VALUE_INDEX+WIDTH-1 downto VALUE_INDEX),
            counter_stb   => statistic_stbs(STB_INDEX)
          );

      end generate inputs_gen;
    end generate cond_gen;
  end generate stat_gen;

  -----------
  -- Ports --
  -----------

  -- only 127 port allowed
  assert PORT_CNT < 128
    report "ERROR: Too many ports defined."
    severity error;

  -- there must be ports available
  assert PORT_CNT > 0
    report "ERROR: No ports defined."
    severity error;

  -- no doubling in port-ids
  assert noDoubleId(PORTS)
    report "ERROR: There is an ID-Doubling in the port-declaration."
    severity error;

  assert getMaxPortInputs(PORTS) < 64
    report "ERROR: Too many inputs defined."
    severity error;

  assert getMaxPortWidth(PORTS) <= 256
    report "ERROR: Invalid port-width occured."
    severity error;

  assert getMaxPortId(PORTS) < 256
    report "ERROR: Invalid port-width occured."
    severity error;

  -----------
  -- Ports --
  -----------

  ports_blk : block
  begin

    -- assert all incoming port-messages to a main-vector. a simple assigment is not possible.

    ports_gen : for i in 0 to PORT_CNT-1 generate

      constant ID              : natural  := PORTS(i).ID;
      constant DST_VALUE_INDEX : natural  := getPortValueIndex(PORTS, ID);
      constant DST_STB_INDEX   : natural  := getPortStbIndex(PORTS, ID);
      constant WIDTH           : positive := PORTS(i).WIDTH;
      constant VALUE_BITS      : natural  := PORTS(i).INPUTS*WIDTH;
      constant STB_BITS        : natural  := PORTS(i).INPUTS;

      constant IS_INST_PORT         : boolean := containsPort(INST_PORTS_I, ID);
      constant IS_INST_BRANCH_PORT  : boolean := containsPort(INST_BRANCH_PORTS_I, ID)  and not (IS_INST_PORT);
      constant IS_MEM_ADR_PORT      : boolean := containsPort(MEM_ADR_PORTS_I, ID)      and not (IS_INST_PORT or
                                                                                                 IS_INST_BRANCH_PORT);
      constant IS_MEM_DATA_PORT     : boolean := containsPort(MEM_DATA_PORTS_I, ID)     and not (IS_INST_PORT or
                                                                                                 IS_INST_BRANCH_PORT or IS_MEM_ADR_PORT);
      constant IS_MEM_RW_PORT       : boolean := containsPort(MEM_RW_PORTS_I, ID)       and not (IS_INST_PORT or
                                                                                                 IS_INST_BRANCH_PORT or IS_MEM_ADR_PORT or
                                                                                                 IS_MEM_DATA_PORT);
      constant IS_MEM_SOURCE_PORT   : boolean := containsPort(MEM_SOURCE_PORTS_I, ID)   and not (IS_INST_PORT or
                                                                                                 IS_INST_BRANCH_PORT or IS_MEM_ADR_PORT or
                                                                                                 IS_MEM_DATA_PORT or IS_MEM_RW_PORT);
      constant IS_MESSAGE_PORT      : boolean := containsPort(MESSAGE_PORTS_I, ID)      and not (IS_INST_PORT or
                                                                                                 IS_INST_BRANCH_PORT or IS_MEM_ADR_PORT or
                                                                                                 IS_MEM_DATA_PORT or IS_MEM_RW_PORT or
                                                                                                 IS_MEM_SOURCE_PORT);
      constant IS_CTRL_MESSAGE_PORT : boolean := containsPort(CTRL_MESSAGE_PORTS, ID)   and not (IS_INST_PORT or
                                                                                                 IS_INST_BRANCH_PORT or IS_MEM_ADR_PORT or
                                                                                                 IS_MEM_DATA_PORT or IS_MEM_RW_PORT or
                                                                                                 IS_MEM_SOURCE_PORT or IS_MESSAGE_PORT);
      constant IS_STATISTIC_PORT    : boolean := containsPort(STATISTIC_PORTS_I, ID)    and not (IS_INST_PORT or
                                                                                                 IS_INST_BRANCH_PORT or IS_MEM_ADR_PORT or
                                                                                                 IS_MEM_DATA_PORT or IS_MEM_RW_PORT or
                                                                                                 IS_MEM_SOURCE_PORT or IS_MESSAGE_PORT or
                                                                                                 IS_CTRL_MESSAGE_PORT);

      signal port_values_i : std_logic_vector(VALUE_BITS-1 downto 0);
      signal port_stbs_i   : std_logic_vector(STB_BITS-1 downto 0);
      signal port_values_r : std_logic_vector(VALUE_BITS-1 downto 0);
      signal port_stbs_r   : std_logic_vector(STB_BITS-1 downto 0);

      -- when one port is present in several arrays, so take the first one
    begin

      --assert false report "ports_gen ID "&integer'image(ID) severity note;
      --assert false report "ports_gen DST_VALUE_INDEX "&integer'image(DST_VALUE_INDEX) severity note;
      --assert false report "ports_gen DST_STB_INDEX "&integer'image(DST_STB_INDEX) severity note;


      port_stbs(DST_STB_INDEX+STB_BITS-1 downto DST_STB_INDEX)         <= port_stbs_r;
      port_values(DST_VALUE_INDEX+VALUE_BITS-1 downto DST_VALUE_INDEX) <= port_values_r;

      -- Instruction-Ports

      inst_port_gen : if IS_INST_PORT generate
        constant SRC_VALUE_INDEX : natural := getPortValueIndex(INST_PORTS_I, ID);
        constant SRC_STB_INDEX   : natural := getPortStbIndex(INST_PORTS_I, ID);
      begin
        port_values_i <= inst_values(SRC_VALUE_INDEX+VALUE_BITS-1 downto SRC_VALUE_INDEX);
        port_stbs_i   <= inst_stbs(SRC_STB_INDEX+STB_BITS-1 downto SRC_STB_INDEX);
      end generate inst_port_gen;

      -- Instruction-Branch-Ports

      inst_branch_port_gen : if IS_INST_BRANCH_PORT generate
        constant SRC_VALUE_INDEX : natural := getPortValueIndex(INST_BRANCH_PORTS_I, ID);
        constant SRC_STB_INDEX   : natural := getPortStbIndex(INST_BRANCH_PORTS_I, ID);
      begin
        port_values_i <= inst_branch_values(SRC_VALUE_INDEX+VALUE_BITS-1 downto SRC_VALUE_INDEX);
        port_stbs_i   <= inst_branch_stbs(SRC_STB_INDEX+STB_BITS-1 downto SRC_STB_INDEX);
      end generate inst_branch_port_gen;

      -- Memory-Adress-Ports

      mem_adr_port_gen : if IS_MEM_ADR_PORT generate
        constant SRC_VALUE_INDEX : natural := getPortValueIndex(MEM_ADR_PORTS_I, ID);
        constant SRC_STB_INDEX   : natural := getPortStbIndex(MEM_ADR_PORTS_I, ID);
      begin
        --assert false report "mem_adr_port_gen SRC_VALUE_INDEX "&integer'image(SRC_VALUE_INDEX) severity note;
        --assert false report "mem_adr_port_gen SRC_STB_INDEX "&integer'image(SRC_STB_INDEX) severity note;
        port_values_i <= mem_adr_values(SRC_VALUE_INDEX+VALUE_BITS-1 downto SRC_VALUE_INDEX);
        port_stbs_i   <= mem_adr_stbs(SRC_STB_INDEX+STB_BITS-1 downto SRC_STB_INDEX);
      end generate mem_adr_port_gen;

      -- Memory-Data-Ports

      mem_data_port_gen : if IS_MEM_DATA_PORT generate
        constant SRC_VALUE_INDEX : natural := getPortValueIndex(MEM_DATA_PORTS_I, ID);
        constant SRC_STB_INDEX   : natural := getPortStbIndex(MEM_DATA_PORTS_I, ID);
      begin
        --assert false report "mem_data_port_gen SRC_VALUE_INDEX "&integer'image(SRC_VALUE_INDEX) severity note;
        --assert false report "mem_data_port_gen SRC_STB_INDEX "&integer'image(SRC_STB_INDEX) severity note;
        port_values_i <= mem_data_values(SRC_VALUE_INDEX+VALUE_BITS-1 downto SRC_VALUE_INDEX);
        port_stbs_i   <= mem_data_stbs(SRC_STB_INDEX+STB_BITS-1 downto SRC_STB_INDEX);
      end generate mem_data_port_gen;

      -- Memory-RW-Ports

      mem_rw_port_gen : if IS_MEM_RW_PORT generate
        constant SRC_VALUE_INDEX : natural := getPortValueIndex(MEM_RW_PORTS_I, ID);
        constant SRC_STB_INDEX   : natural := getPortStbIndex(MEM_RW_PORTS_I, ID);
      begin
        --assert false report "mem_rw_port_gen SRC_VALUE_INDEX "&integer'image(SRC_VALUE_INDEX) severity note;
        --assert false report "mem_rw_port_gen SRC_STB_INDEX "&integer'image(SRC_STB_INDEX) severity note;
        port_values_i <= mem_rw_values(SRC_VALUE_INDEX+VALUE_BITS-1 downto SRC_VALUE_INDEX);
        port_stbs_i   <= mem_rw_stbs(SRC_STB_INDEX+STB_BITS-1 downto SRC_STB_INDEX);
      end generate mem_rw_port_gen;

      -- Memory-Source-Ports

      mem_source_port_gen : if IS_MEM_SOURCE_PORT generate
        constant SRC_VALUE_INDEX : natural := getPortValueIndex(MEM_SOURCE_PORTS_I, ID);
        constant SRC_STB_INDEX   : natural := getPortStbIndex(MEM_SOURCE_PORTS_I, ID);
      begin
        --assert false report "mem_source_port_gen SRC_VALUE_INDEX "&integer'image(SRC_VALUE_INDEX) severity note;
        --assert false report "mem_source_port_gen SRC_STB_INDEX "&integer'image(SRC_STB_INDEX) severity note;
        port_values_i <= mem_source_values(SRC_VALUE_INDEX+VALUE_BITS-1 downto SRC_VALUE_INDEX);
        port_stbs_i   <= mem_source_stbs(SRC_STB_INDEX+STB_BITS-1 downto SRC_STB_INDEX);
      end generate mem_source_port_gen;

      -- Message-Ports

      message_port_gen : if IS_MESSAGE_PORT generate
        constant SRC_VALUE_INDEX : natural := getPortValueIndex(MESSAGE_PORTS_I, ID);
        constant SRC_STB_INDEX   : natural := getPortStbIndex(MESSAGE_PORTS_I, ID);
      begin
        --assert false report "message_port_gen SRC_VALUE_INDEX "&integer'image(SRC_VALUE_INDEX) severity note;
        --assert false report "message_port_gen SRC_STB_INDEX "&integer'image(SRC_STB_INDEX) severity note;
        port_values_i <= message_values(SRC_VALUE_INDEX+VALUE_BITS-1 downto SRC_VALUE_INDEX);
        port_stbs_i   <= message_stbs(SRC_STB_INDEX+STB_BITS-1 downto SRC_STB_INDEX);
      end generate message_port_gen;

      -- Controller-Message-Ports

      ctrl_message_port_gen : if IS_CTRL_MESSAGE_PORT generate
        constant SRC_VALUE_INDEX : natural := getPortValueIndex(CTRL_MESSAGE_PORTS, ID);
        constant SRC_STB_INDEX   : natural := getPortStbIndex(CTRL_MESSAGE_PORTS, ID);
      begin
        -- Do not register ctrl-messages, otherwise trigger-inform messages will
        -- be inserted to late.
        port_values_r <= ctrl_message_values(SRC_VALUE_INDEX+VALUE_BITS-1 downto SRC_VALUE_INDEX);
        port_stbs_r   <= ctrl_message_stbs(SRC_STB_INDEX+STB_BITS-1 downto SRC_STB_INDEX);
      end generate ctrl_message_port_gen;

      -- Statistic-Ports

      statistic_port_gen : if IS_STATISTIC_PORT generate
        constant SRC_VALUE_INDEX : natural := getPortValueIndex(STATISTIC_PORTS_I, ID);
        constant SRC_STB_INDEX   : natural := getPortStbIndex(STATISTIC_PORTS_I, ID);
      begin
        port_values_i <= statistic_values(SRC_VALUE_INDEX+VALUE_BITS-1 downto SRC_VALUE_INDEX);
        port_stbs_i   <= statistic_stbs(SRC_STB_INDEX+STB_BITS-1 downto SRC_STB_INDEX);
      end generate statistic_port_gen;


      -- put values in register, if stb is acitv
      -- Do not register ctrl-messages, otherwise trigger-inform messages will
      -- be inserted to late. port*_r assigned above.

      gRegs: if not IS_CTRL_MESSAGE_PORT generate
      clk_proc : process(clk_trc)
      begin
        if rising_edge(clk_trc) then
          if rst_trc = '1' then
            port_stbs_r   <= (others => '0');
          else
            port_stbs_r <= port_stbs_i;
          end if;

          -- no reset for port_values_r required
            for j in 0 to port_stbs_i'length-1 loop
              if port_stbs_i(j) = '1' then
                port_values_r((j+1)*WIDTH-1 downto j*WIDTH) <= port_values_i((j+1)*WIDTH-1 downto j*WIDTH);
              end if;
            end loop;

        end if;
      end process clk_proc;
      end generate gRegs;

    end generate ports_gen;

  end block ports_blk;

  --------------------------------
  -- Instantiate the controller --
  --------------------------------

  ctrl_blk : block
    constant OV_DANGER_REACTION_I : tOvDangerReaction := ifThenElse(MEM_TRACER_GEN_CNT > 0, OV_DANGER_REACTION, none);
    signal ice_trig  : std_logic;
  begin

    assert countTracer(INST_TRACER_ALL, MEM_TRACER_ALL, MESSAGE_TRACER_ALL) < 256
      report "ERROR: More than 255 Tracer found."
      severity error;

    adr_en  <= not filter_adr;
    data_en <= not filter_data;

    ctrl_inst : trace_ctrl
      generic map (
        CONFIG                    => getConfig(PORTS, INST_TRACER_ALL, MEM_TRACER_ALL, MESSAGE_TRACER_ALL,
                                               SINGLE_EVENTS, TRIGGER_ARRAY,ICE_REGISTERS, TIME_BITS,
                                               TRIGGER_INFORM, CYCLE_ACCURATE),
        ICE_REGISTERS             => ICE_REGISTERS,
        TRIGGER_INFORM            => TRIGGER_INFORM_I,
        TRIGGER_CNT               => TRIGGER_CNT,
        TRIGGER_OUT_BITS          => TRIGGER_OUT_BITS,
        TRIG_REG_INDEX_BITS       => TRIG_REG_INDEX_BITS,
        TRIG_REG_BITS             => TRIG_REG_BITS,
        TRIG_ACTIV_BITS           => TRIG_ACTIV_BITS,
        HAVE_ICE_TRIGGER          => HAVE_ICE_TRIGGER,
        TRIG_CMP1_BITS            => TRIG_CMP1_BITS,
        TRIG_CMP2_BITS            => TRIG_CMP2_BITS,           
        TRIG_MODE_BITS            => TRIG_MODE_BITS,           
        TRIG_TYPE_BITS            => TRIG_TYPE_BITS,        
        TRACER_CNT                => TRACER_CNT,
        CYCLE_ACCURATE            => CYCLE_ACCURATE,
        OV_DANGER_REACTION        => OV_DANGER_REACTION_I,
        FILTER_INTERVAL           => FILTER_INTERVAL,
        MIN_DATA_PACKET_SIZE      => MIN_DATA_PACKET_SIZE,
        TIME_BITS                 => TIME_BITS,
        TIME_CMP_LEVELS           => TIME_CMP_LEVELS,
        GLOBAL_TIME_SAFE_DISTANCE => GLOBAL_TIME_SAFE_DISTANCE,
        GLOBAL_TIME_FIFO_DEPTH    => GLOBAL_TIME_FIFO_DEPTH,
        TRACER_TIME_SAFE_DISTANCE => TRACER_TIME_SAFE_DISTANCE,
        TRACER_TIME_FIFO_DEPTH    => TRACER_TIME_FIFO_DEPTH,
        TRACER_DATA_BITS          => TRACER_DATA_BITS,
        DO_RESYNC                 => DO_RESYNC
      )
      port map (
        clk_trc           => clk_trc,
        rst_trc           => rst_trc,
        clk_sys           => clk_sys,
        rst_sys           => rst_sys,
        trace_running     => trace_running_i,
        resync            => resync,
        ice_trig          => ice_trig,
        cpu_stall         => system_stall,
        ice_regs_in       => regs_in,
        ice_regs_out      => regs_out,
        ice_store         => store,
        eth_full          => eth_full,
        eth_din           => eth_din,
        eth_put           => eth_put,
        eth_valid         => eth_valid,
        eth_last          => eth_last,
        eth_dout          => eth_dout,
        eth_got           => eth_got,
        eth_finish        => eth_finish,
        header            => header,
        trig_err          => trig_err,
        trig_rsp          => trig_rsp,
        filter_data       => filter_data,
        filter_adr        => filter_adr,
        st_stb            => ctrl_message_stbs(0),
        st_msg            => ctrl_message_values,
        tracer_stbs       => tracer_stbs,
        tracer_stb_en     => tracer_stb_en,
        tracer_data       => tracer_data,
        tracer_data_fill  => tracer_data_fill,
        tracer_data_last  => tracer_data_last,
        tracer_data_got   => tracer_data_got,
        tracer_data_se    => tracer_data_se,
        tracer_data_valid => tracer_data_valid,
        tracer_sel        => tracer_sel,
        tracer_ovs        => tracer_ovs,
        tracer_ov_starts  => tracer_ov_starts,
        tracer_ov_stops   => tracer_ov_stops,
        tracer_ov_dangers => tracer_ov_dangers,
        trig_reg_set      => trig_reg_set,
        trig_reg_index    => trig_reg_index,
        trig_reg_val      => trig_reg_val,
        trig_cmp_set      => trig_cmp_set,
        trig_cmp1_val     => trig_cmp1_val,
        trig_cmp2_val     => trig_cmp2_val,
        trig_index        => trig_index,
        trig_mode_set     => trig_mode_set,
        trig_mode_val     => trig_mode_val,
        trig_type_set     => trig_type_set,
        trig_type_val     => trig_type_val,
        trig_activ_set    => trig_activ_set,
        trig_activ_sel    => trig_activ_sel,
        trig_fired        => trig_fired,
        trig_fired_stb    => trig_fired_stb
      );

    trace_running <= trace_running_i;
    
    -- ice-trigger

    no_trigger_gen : if not HAVE_ICE_TRIGGER generate
      ice_trig <= '1';
    end generate no_trigger_gen;

    trigger_gen : if HAVE_ICE_TRIGGER generate
      constant ICE_TRIGGER : tTrigger_array := getTrigger(TRIGGER_RECORDS_ALL, ICE_TRIGGER_IDS_I);
      signal trig : std_logic_vector(ICE_TRIGGER_IDS_CNT-1 downto 0);
    begin

      trigger_sel : for i in 0 to ICE_TRIGGER_IDS_CNT-1 generate
        constant TRIGGER_INDEX : natural := sumTriggerOutBits(TRIGGER_ARRAY, SINGLE_EVENTS,
                                            getTriggerIndex(TRIGGER_ARRAY, ICE_TRIGGER_IDS_I(i)));
      begin

        assert getTriggerLevel(getTrigger(TRIGGER_ARRAY, ICE_TRIGGER_IDS_I(i)), SINGLE_EVENTS) = 1
          report "ERROR: Ice-Trigger must have level 1."
          severity error;

        trig(i) <= (trigger_send_starts(TRIGGER_INDEX) and
                not trigger_send_stops(TRIGGER_INDEX)) or
                    trigger_send_dos(TRIGGER_INDEX);
      end generate trigger_sel;

      ice_trig <= '1' when unsigned(trig) /= 0 else '0';

    end generate trigger_gen;

  end block ctrl_blk;

  ------------------------
  -- Instantiate tracer --
  ------------------------

  ------------------------------------
  -- combine all trigger for tracer --
  ------------------------------------

  tracer_gen : for i in 0 to TRACER_GEN_CNT-1 generate

    constant TRIGGER_ARRAY_I : tTrigger_array
                             := getTrigger(TRIGGER_ARRAY, getTriggerIds(INST_TRACER_ALL, MEM_TRACER_ALL,
                                                                        MESSAGE_TRACER_ALL, i));
    constant TRIGGER_CNT_I   : natural  := countTrigger(TRIGGER_ARRAY_I);
    constant INPUTS          : positive := getInputs(INST_TRACER_ALL, MEM_TRACER_ALL,
                                                     MESSAGE_TRACER_ALL, i);
  begin

    tracer_inputs_gen : for j in 0 to INPUTS-1 generate
      constant GLOBAL_INDEX : natural := getTracerGlobalIndex(INST_TRACER_ALL, MEM_TRACER_ALL,
                                                              MESSAGE_TRACER_ALL, i, j);
    begin

      -- get trc and send-enable
      trigger_gen : if TRIGGER_CNT_I > 0 generate
        signal trc_enable     : std_logic_vector(TRIGGER_CNT_I-1 downto 0);
        signal send_start     : std_logic_vector(TRIGGER_CNT_I-1 downto 0);
        signal send_stop      : std_logic_vector(TRIGGER_CNT_I-1 downto 0);
        signal send_do        : std_logic_vector(TRIGGER_CNT_I-1 downto 0);
        signal trc_enable_bit : std_logic;
        signal send_start_bit : std_logic;
        signal send_stop_bit  : std_logic;
        signal send_do_bit    : std_logic;
        signal send_enable_r  : std_logic := '0';
      begin

        trigger_sel : for k in 0 to TRIGGER_CNT_I-1 generate
          constant TRIGGER_INDEX   : natural  := sumTriggerOutBits(TRIGGER_ARRAY, SINGLE_EVENTS, TRIGGER_ARRAY_I(k));
          constant TRIGGER_LEVEL_K : positive := getTriggerLevel(TRIGGER_ARRAY_I(k), SINGLE_EVENTS);
        begin

          assert not ((TRIGGER_LEVEL_K > 1) and (INPUTS > 1) and (TRIGGER_LEVEL_K /= INPUTS))
            report "ERROR: Invalid Trigger-Level for tracer."
            severity error;

          -- or-connect levels, if tracer has only one input

          level_or_gen : if TRIGGER_LEVEL_K > 1 and INPUTS = 1 generate
            trc_enable(k) <= '1' when unsigned(trigger_trc_enables(TRIGGER_INDEX+TRIGGER_LEVEL_K-1 downto TRIGGER_INDEX)) /= 0 else '0';
            send_start(k) <= '1' when unsigned(trigger_send_starts(TRIGGER_INDEX+TRIGGER_LEVEL_K-1 downto TRIGGER_INDEX)) /= 0 else '0';
            send_stop(k)  <= '1' when unsigned(trigger_send_stops(TRIGGER_INDEX+TRIGGER_LEVEL_K-1 downto TRIGGER_INDEX)) /= 0 else '0';
            send_do(k)    <= '1' when unsigned(trigger_send_dos(TRIGGER_INDEX+TRIGGER_LEVEL_K-1 downto TRIGGER_INDEX)) /= 0 else '0';
          end generate level_or_gen;

          -- don't or-connect levels, if tracer has input for every level or level is one

          no_level_or_gen : if TRIGGER_LEVEL_K = 1 or INPUTS > 1 generate
            trc_enable(k) <= trigger_trc_enables(ifThenElse(TRIGGER_LEVEL_K = 1, TRIGGER_INDEX, TRIGGER_INDEX+j));
            send_start(k) <= trigger_send_starts(ifThenElse(TRIGGER_LEVEL_K = 1, TRIGGER_INDEX, TRIGGER_INDEX+j));
            send_stop(k)  <= trigger_send_stops(ifThenElse(TRIGGER_LEVEL_K = 1, TRIGGER_INDEX, TRIGGER_INDEX+j));
            send_do(k)    <= trigger_send_dos(ifThenElse(TRIGGER_LEVEL_K = 1, TRIGGER_INDEX, TRIGGER_INDEX+j));
          end generate no_level_or_gen;

        end generate trigger_sel;

        trc_enable_bit <= '1' when unsigned(trc_enable) /= 0 else '0';
        send_start_bit <= '1' when unsigned(send_start) /= 0 else '0';
        send_stop_bit  <= '1' when unsigned(send_stop) /= 0 else '0';
        send_do_bit    <= '1' when unsigned(send_do) /= 0 else '0';

        clk_proc : process(clk_trc)
        begin
          if rising_edge(clk_trc) then
            if rst_trc = '1' then
              send_enable_r <= '0';
            elsif send_start_bit = '1' and send_stop_bit = '0' then
              send_enable_r <= '1';
            elsif send_start_bit = '0' and send_stop_bit = '1' then
              send_enable_r <= '0';
            end if;
          end if;
        end process clk_proc;

        trc_enable_trig(GLOBAL_INDEX)  <= trc_enable_bit;
        send_enable_trig(GLOBAL_INDEX) <= ((send_start_bit or send_enable_r) and not send_stop_bit) or send_do_bit;

      end generate trigger_gen;

      no_trigger_gen : if TRIGGER_CNT_I = 0 generate
        trc_enable_trig(GLOBAL_INDEX)  <= '1';
        send_enable_trig(GLOBAL_INDEX) <= '1';
      end generate no_trigger_gen;

    end generate tracer_inputs_gen;

  end generate tracer_gen;

  ------------------------
  -- Instruction-Tracer --
  ------------------------

  inst_tracer_gen : for i in 0 to INST_TRACER_GEN_CNT-1 generate
    constant INPUTS        : positive := getInputs(INST_TRACER_ALL(i));
    constant INST_TRACER   : tInstGen := INST_TRACER_ALL(i);
    constant ADR_BITS      : positive := INST_TRACER.ADR_PORT.WIDTH;
    constant BRANCH_INFO   : boolean  := not isNullPort(INST_TRACER.BRANCH_PORT);
    constant ADR_INDEX     : natural  := getPortValueIndex(PORTS, INST_TRACER.ADR_PORT.ID);
    constant ADR_STB_INDEX : natural  := getPortStbIndex(PORTS, INST_TRACER.ADR_PORT.ID);
    constant TIME_BITS_I   : natural  := ifThenElse(CYCLE_ACCURATE, TIME_BITS, 0);
  begin

    assert equalInputs(getPorts(INST_TRACER))
      report "ERROR: All ports associated to the same tracer should have the same width."
      severity error;

    assert (BRANCH_INFO and INST_TRACER.BRANCH_PORT.WIDTH = 3) or not BRANCH_INFO
      report "ERROR: Branch-port needs 3-bit-width."
      severity error;

    assert INST_TRACER.HISTORY_BYTES < 4
      report "ERROR: Decrease history-bytes in instruction-tracer."
      severity error;

    assert INST_TRACER.COUNTER_BITS < 256
      report "ERROR: Decrease counter-bits in instruction-tracer."
      severity error;

    inst_tracer_inputs_gen : for j in 0 to INPUTS-1 generate

      constant GLOBAL_INDEX     : natural  := countTracer(INST_TRACER_ALL, i) + j;
      constant CODING           : boolean  := TRACER_CNT > 1;
      constant CODING_VAL       : std_logic_vector := ifThenElse(CODING, getCodeCoding(PRIORITIES,
                                                               GLOBAL_INDEX), "-");
      constant ADR_INDEX_J      : natural  := ADR_INDEX+j*ADR_BITS;
      constant ADR_STB_INDEX_J  : natural  := ADR_STB_INDEX+j;

      constant OUT_BITS         : positive := getInstDataOutBits(INST_TRACER.ADR_PORT, BRANCH_INFO,
                                              INST_TRACER.COUNTER_BITS, INST_TRACER.HISTORY_BYTES,
                                              ifThenElse(CODING, CODING_VAL'length, 0), TIME_BITS_I);
      constant OUT_INDEX      : natural  := sum(TRACER_DATA_BITS, GLOBAL_INDEX);
      constant FILL_BITS      : positive := log2ceilnz(OUT_BITS);
      constant FILL_INDEX     : natural  := sum(log2ceilnz(TRACER_DATA_BITS), GLOBAL_INDEX);
      constant BRANCH_INDEX   : natural := getPortValueIndex(PORTS, INST_TRACER.BRANCH_PORT.ID)+j*3;
      
      -- Pipeline registers
      signal adr_stb : std_logic;
      signal adr     : std_logic_vector(INST_TRACER.ADR_PORT.WIDTH-1 downto 0);
      signal branch  : std_logic_vector(ifThenElse(BRANCH_INFO, 2, 0) downto 0);
      signal trc_enable  : std_logic;
      signal send_enable : std_logic;

      -- Outputs
      signal data_out    : std_logic_vector(OUT_BITS-1 downto 0);
      signal data_fill   : unsigned(FILL_BITS-1 downto 0);
    begin

      -- Pipeline tracer control and data signals
      clk_proc : process (clk_trc)
      begin  -- process clk_proc
        if rising_edge(clk_trc) then
          if rst_trc = '1' then
            trc_enable  <= '0';
            send_enable <= '0';
            adr_stb     <= '0';
          else
            trc_enable  <= trace_running_i and (trc_enable_trig(GLOBAL_INDEX) or send_enable);
            send_enable <= trace_running_i and send_enable_trig(GLOBAL_INDEX);
            adr_stb     <= port_stbs(ADR_STB_INDEX_J);
          end if;

          adr    <= port_values(ADR_INDEX_J+ADR_BITS-1 downto ADR_INDEX_J);
          
          if BRANCH_INFO then
            branch <= port_values(BRANCH_INDEX+2 downto BRANCH_INDEX);
          end if;
        end if;
      end process clk_proc;

      no_branch_info_gen: if not BRANCH_INFO generate
        branch <= (others => '-');
      end generate no_branch_info_gen;
      
      inst_tracer_inst : trace_instTracer
        generic map (
          ADR_PORT      => INST_TRACER.ADR_PORT,
          BRANCH_INFO   => BRANCH_INFO,
          COUNTER_BITS  => INST_TRACER.COUNTER_BITS,
          HISTORY_BYTES => INST_TRACER.HISTORY_BYTES,
          LS_ENCODING   => INST_TRACER.LS_ENCODING,
          FIFO_DEPTH    => INST_TRACER.FIFO_DEPTH,
          FIFO_SDS      => INST_TRACER.FIFO_SDS,
          CODING        => CODING,
          CODING_VAL    => CODING_VAL,
          TIME_BITS     => TIME_BITS_I
        )
        port map (
          clk_trc     => clk_trc,
          rst_trc     => rst_trc,
          clk_sys     => clk_sys,
          rst_sys     => rst_sys,
          adr         => adr,
          adr_stb     => adr_stb,
          branch      => branch,
          stb_out     => tracer_stbs(GLOBAL_INDEX),
          data_out    => data_out,
          data_fill   => data_fill,
          data_got    => tracer_data_got(GLOBAL_INDEX),
          data_last   => tracer_data_last(GLOBAL_INDEX),
          data_se     => tracer_data_se(GLOBAL_INDEX),
          data_valid  => tracer_data_valid(GLOBAL_INDEX),
          sel         => tracer_sel(GLOBAL_INDEX),
          trc_enable  => trc_enable,
          stb_enable  => tracer_stb_en,
          send_enable => send_enable,
          ov          => tracer_ovs(GLOBAL_INDEX),
          ov_start    => tracer_ov_starts(GLOBAL_INDEX),
          ov_stop     => tracer_ov_stops(GLOBAL_INDEX),
          ov_danger   => tracer_ov_dangers(GLOBAL_INDEX)
        );

      tracer_data(OUT_INDEX+OUT_BITS-1 downto OUT_INDEX)         <= data_out;
      tracer_data_fill(FILL_INDEX+FILL_BITS-1 downto FILL_INDEX) <= std_logic_vector(data_fill);

    end generate inst_tracer_inputs_gen;
  end generate inst_tracer_gen;

  -------------------
  -- Memory-Tracer --
  -------------------

  mem_tracer_gen : for i in 0 to MEM_TRACER_GEN_CNT-1 generate
    constant INPUTS         : positive := getInputs(MEM_TRACER_ALL(i));
    constant MEM_TRACER     : tMemGen  := MEM_TRACER_ALL(i);
    constant SOURCE         : boolean  := not isNullPort(MEM_TRACER.SOURCE_PORT);
    constant SOURCE_BITS    : natural  := ifThenElse(SOURCE, MEM_TRACER.SOURCE_PORT.WIDTH, 0);
    constant SOURCE_INDEX   : natural  := getPortValueIndex(PORTS, MEM_TRACER.SOURCE_PORT.ID);
    constant ADR_PORTS      : tPorts   := MEM_TRACER.ADR_PORTS;
    constant ADR_PORT_CNT   : positive := countPorts(ADR_PORTS);
    constant ADR_BITS       : positive := sumWidths(ADR_PORTS);
    constant RW_INDEX       : natural  := getPortValueIndex(PORTS, MEM_TRACER.RW_PORT.ID);
    constant DATA_PORT      : tPort    := MEM_TRACER.DATA_PORT;
    constant DATA_BITS      : positive := DATA_PORT.WIDTH;
    constant DATA_INDEX     : natural  := getPortValueIndex(PORTS, MEM_TRACER.DATA_PORT.ID);
    constant DATA_STB_INDEX : natural  := getPortStbIndex(PORTS, MEM_TRACER.DATA_PORT.ID);
    constant TIME_BITS_I    : natural  := ifThenElse(CYCLE_ACCURATE, TIME_BITS, 0);
  begin

    assert equalInputs(getPorts(MEM_TRACER))
      report "ERROR: All ports associated to the same tracer should have the same width."
      severity error;

    assert MEM_TRACER.RW_PORT.WIDTH = 1
      report "ERROR: The RW-Port should have the width 1."
      severity error;

    mem_tracer_inputs_gen : for j in 0 to INPUTS-1 generate

      constant GLOBAL_INDEX     : natural   := countTracer(INST_TRACER_ALL)+countTracer(MEM_TRACER_ALL, i) + j;
      constant CODING           : boolean   := TRACER_CNT > 1;
      constant CODING_VAL       : std_logic_vector := ifThenElse(CODING, getCodeCoding(PRIORITIES,
                                                                 GLOBAL_INDEX), "-");
      constant SOURCE_INDEX_J   : natural   := SOURCE_INDEX+j*SOURCE_BITS;
      constant RW_INDEX_J       : natural   := RW_INDEX+j;
      constant DATA_INDEX_J     : natural   := DATA_INDEX+j*DATA_BITS;
      constant DATA_STB_INDEX_J : natural   := DATA_STB_INDEX+j;
      constant OUT_BITS         : positive  := getMemDataOutBits(MEM_TRACER.ADR_PORTS,
                                               MEM_TRACER.DATA_PORT, SOURCE_BITS,
                                               ifThenElse(CODING, CODING_VAL'length, 0), TIME_BITS_I);
      constant OUT_INDEX        : natural   := sum(TRACER_DATA_BITS, GLOBAL_INDEX);
      constant FILL_BITS        : positive  := log2ceilnz(OUT_BITS);
      constant FILL_INDEX       : natural   := sum(log2ceilnz(TRACER_DATA_BITS), GLOBAL_INDEX);

      -- pipeline registers
      signal trc_enable  : std_logic;
      signal send_enable : std_logic;
      signal adr         : std_logic_vector(ADR_BITS-1 downto 0);
      signal adr_stbs    : std_logic_vector(countPorts(MEM_TRACER.ADR_PORTS)-1 downto 0);
      signal data        : std_logic_vector(DATA_BITS-1 downto 0);
      signal data_stb    : std_logic;
      signal rw          : std_logic;
      signal src         : std_logic_vector(notZero(SOURCE_BITS)-1 downto 0);

      -- outputs
      signal data_out    : std_logic_vector(OUT_BITS-1 downto 0);
      signal data_fill   : unsigned(FILL_BITS-1 downto 0);
    begin

      adr_gen : for k in 0 to ADR_PORT_CNT-1 generate
        constant ADR_BITS      : natural := MEM_TRACER.ADR_PORTS(k).WIDTH;
        constant ADR_INDEX     : natural := getPortValueIndex(PORTS, MEM_TRACER.ADR_PORTS(k).ID)+j*ADR_BITS;
        constant ADR_STB_INDEX : natural := getPortStbIndex(PORTS, MEM_TRACER.ADR_PORTS(k).ID)+j;
        constant DST_INDEX     : natural := sumWidths(MEM_TRACER.ADR_PORTS, k);
        constant DST_STB_INDEX : natural := k;
      begin

        -- Pipeline tracer control and data signals
        process (clk_trc)
        begin  -- process
          if rising_edge(clk_trc) then
            if rst_trc = '1' then
              adr_stbs(DST_STB_INDEX) <= '0';
              data_stb                <= '0';
            else
              adr_stbs(DST_STB_INDEX) <= port_stbs(ADR_STB_INDEX);
              data_stb                <= port_stbs(DATA_STB_INDEX_J);
            end if;

            adr(DST_INDEX+ADR_BITS-1 downto DST_INDEX) <=
              port_values(ADR_INDEX+ADR_BITS-1 downto ADR_INDEX);
            data <= port_values(DATA_INDEX_J+DATA_BITS-1 downto DATA_INDEX_J);
            rw   <= port_values(RW_INDEX);
          end if;
        end process;

      end generate adr_gen;

      -- Pipeline tracer control and data signals
      process (clk_trc)
      begin  -- process
        if rising_edge(clk_trc) then
          if rst_trc = '1' then
            trc_enable  <= '0';
            send_enable <= '0';
          else
            trc_enable  <= trace_running_i and (trc_enable_trig(GLOBAL_INDEX) or send_enable);
            send_enable <= trace_running_i and send_enable_trig(GLOBAL_INDEX);
          end if;

          if SOURCE_BITS > 0 then
            src <= port_values(SOURCE_INDEX_J+SOURCE_BITS-1 downto SOURCE_INDEX_J);
          end if;
        end if;
      end process;
      
      no_src_gen : if SOURCE_BITS = 0 generate
        src <= "-";
      end generate no_src_gen;

      memTracer_inst : trace_memTracer
        generic map (
          ADR_PORTS   => ADR_PORTS,
          DATA_PORT   => DATA_PORT,
          SOURCE_BITS => SOURCE_BITS,
          COLLECT_VAL => MEM_TRACER.COLLECT_VAL,
          FIFO_DEPTH  => MEM_TRACER.FIFO_DEPTH,
          FIFO_SDS    => MEM_TRACER.FIFO_SDS,
          CODING      => CODING,
          CODING_VAL  => CODING_VAL,
          TIME_BITS   => TIME_BITS_I
        )
        port map (
          clk_trc     => clk_trc,
          rst_trc     => rst_trc,
          clk_sys     => clk_sys,
          rst_sys     => rst_sys,
          adr         => adr,
          adr_stbs    => adr_stbs,
          data        => data,
          data_stb    => data_stb,
          src         => src,
          rw          => rw,
          stb_out     => tracer_stbs(GLOBAL_INDEX),
          data_out    => data_out,
          data_fill   => data_fill,
          data_got    => tracer_data_got(GLOBAL_INDEX),
          data_last   => tracer_data_last(GLOBAL_INDEX),
          data_se     => tracer_data_se(GLOBAL_INDEX),
          data_valid  => tracer_data_valid(GLOBAL_INDEX),
          sel         => tracer_sel(GLOBAL_INDEX),
          trc_enable  => trc_enable,
          stb_enable  => tracer_stb_en,
          send_enable => send_enable,
          ov          => tracer_ovs(GLOBAL_INDEX),
          ov_start    => tracer_ov_starts(GLOBAL_INDEX),
          ov_stop     => tracer_ov_stops(GLOBAL_INDEX),
          ov_danger   => tracer_ov_dangers(GLOBAL_INDEX),
          adr_en      => adr_en,
          data_en     => data_en
        );

      tracer_data(OUT_INDEX+OUT_BITS-1 downto OUT_INDEX)         <= data_out;
      tracer_data_fill(FILL_INDEX+FILL_BITS-1 downto FILL_INDEX) <= std_logic_vector(data_fill);

    end generate mem_tracer_inputs_gen;
  end generate mem_tracer_gen;

  --------------------
  -- Message-Tracer --
  --------------------

  message_tracer_gen : for i in 0 to MESSAGE_TRACER_GEN_CNT-1 generate
    constant INPUTS         : positive    := getInputs(MESSAGE_TRACER_ALL(i));
    constant MESSAGE_TRACER : tMessageGen := MESSAGE_TRACER_ALL(i);
    constant PORT_CNT       : positive    := countPorts(MESSAGE_TRACER.MSG_PORTS);
    constant TIME_BITS_I    : natural     := ifThenElse(CYCLE_ACCURATE, TIME_BITS, 0);
  begin

    assert equalInputs(MESSAGE_TRACER.MSG_PORTS)
      report "ERROR: All ports associated to the same tracer should have the same width."
      severity error;

    message_tracer_inputs_gen : for j in 0 to INPUTS-1 generate

      constant GLOBAL_INDEX : natural  := countTracer(INST_TRACER_ALL)+countTracer(MEM_TRACER_ALL)+
                                          countTracer(MESSAGE_TRACER_ALL, i) + j;
      constant CODING       : boolean  := TRACER_CNT > 1;
      constant CODING_VAL   : std_logic_vector := ifThenElse(CODING, getCodeCoding(PRIORITIES,
                                                             GLOBAL_INDEX), "0");
      constant MSG_BITS_SUM : positive := sumWidths(MESSAGE_TRACER.MSG_PORTS);
      constant OUT_BITS     : positive := getMessageDataOutBits(MESSAGE_TRACER.MSG_PORTS, ifThenElse(CODING, CODING_VAL'length, 0),
                                                                  TIME_BITS_I);
      constant OUT_INDEX    : natural  := sum(TRACER_DATA_BITS, GLOBAL_INDEX);
      constant FILL_BITS    : positive := log2ceilnz(OUT_BITS);
      constant FILL_INDEX   : natural  := sum(log2ceilnz(TRACER_DATA_BITS), GLOBAL_INDEX);

      -- Pipeline register
      signal trc_enable  : std_logic;
      signal send_enable : std_logic;
      signal msgs        : std_logic_vector(MSG_BITS_SUM-1 downto 0);
      signal msg_stbs    : std_logic_vector(countPorts(MESSAGE_TRACER.MSG_PORTS)-1 downto 0);

      -- Resync control
      signal stb         : std_logic;

      -- Outputs
      signal data_out    : std_logic_vector(OUT_BITS-1 downto 0);
      signal data_fill   : unsigned(FILL_BITS-1 downto 0);

    begin

      g1: if MESSAGE_TRACER.MSG_PORTS(0).ID = CTRL_MESSAGE_PORT.ID generate
        -- Ctrl-Message-Tracer is always enabled
        trc_enable  <= '1';
        send_enable <= '1';
      end generate g1;

      g2: if MESSAGE_TRACER.MSG_PORTS(0).ID /= CTRL_MESSAGE_PORT.ID generate
        -- Normal logic for all other message tracer

        -- Pipeline tracer control and data signals
        process (clk_trc)
        begin  -- process
          if rising_edge(clk_trc) then
            if rst_trc = '1' then
              trc_enable <= '0';
              send_enable <= '0';
            else
              trc_enable  <= trace_running_i and (trc_enable_trig(GLOBAL_INDEX) or send_enable);
              send_enable <= trace_running_i and send_enable_trig(GLOBAL_INDEX);
            end if;
          end if;
        end process;
      end generate g2;

      msg_gen : for k in 0 to PORT_CNT-1 generate
        constant MSG_BITS      : natural := MESSAGE_TRACER.MSG_PORTS(k).WIDTH;
        constant MSG_INDEX     : natural := getPortValueIndex(PORTS, MESSAGE_TRACER.MSG_PORTS(k).ID)+j*MSG_BITS;
        constant MSG_STB_INDEX : natural := getPortStbIndex(PORTS, MESSAGE_TRACER.MSG_PORTS(k).ID)+j;
        constant DST_INDEX     : natural := sumWidths(MESSAGE_TRACER.MSG_PORTS, k);
        constant DST_STB_INDEX : natural := k;
      begin

        -- Pipeline tracer control and data signals
        process (clk_trc)
        begin  -- process
          if rising_edge(clk_trc) then
            if rst_trc = '1' then
              msg_stbs(DST_STB_INDEX) <= '0';
            else
              msg_stbs(DST_STB_INDEX) <= port_stbs(MSG_STB_INDEX);
            end if;
            msgs(DST_INDEX+MSG_BITS-1 downto DST_INDEX) <=
              port_values(MSG_INDEX+MSG_BITS-1 downto MSG_INDEX);
          end if;
        end process;
      end generate msg_gen;

      -- MZ: Should resync be included in pipelining?
      resync_gen : if MESSAGE_TRACER.RESYNC generate
        stb <= '1' when resync = '1' or msg_stbs /= (PORT_CNT-1 downto 0 => '0') else '0';
      end generate resync_gen;

      no_resync_gen : if not MESSAGE_TRACER.RESYNC generate
        stb <= '1' when msg_stbs /= (PORT_CNT-1 downto 0 => '0') else '0';
      end generate no_resync_gen;

      messageTracer_inst : trace_messageTracer
        generic map (
          MSG_PORTS  => MESSAGE_TRACER.MSG_PORTS,
          FIFO_DEPTH => MESSAGE_TRACER.FIFO_DEPTH,
          FIFO_SDS   => MESSAGE_TRACER.FIFO_SDS,
          CODING     => CODING,
          CODING_VAL => CODING_VAL,
          TIME_BITS  => TIME_BITS_I
        )
        port map (
          clk_trc     => clk_trc,
          rst_trc     => rst_trc,
          clk_sys     => clk_sys,
          rst_sys     => rst_sys,
          stb_out     => tracer_stbs(GLOBAL_INDEX),
          msgs        => msgs,
          stb         => stb,
          data_out    => data_out,
          data_fill   => data_fill,
          data_got    => tracer_data_got(GLOBAL_INDEX),
          data_last   => tracer_data_last(GLOBAL_INDEX),
          data_se     => tracer_data_se(GLOBAL_INDEX),
          data_valid  => tracer_data_valid(GLOBAL_INDEX),
          sel         => tracer_sel(GLOBAL_INDEX),
          trc_enable  => trc_enable,
          stb_enable  => tracer_stb_en,
          send_enable => send_enable,
          ov          => tracer_ovs(GLOBAL_INDEX),
          ov_start    => tracer_ov_starts(GLOBAL_INDEX),
          ov_stop     => tracer_ov_stops(GLOBAL_INDEX),
          ov_danger   => tracer_ov_dangers(GLOBAL_INDEX)
        );

      tracer_data(OUT_INDEX+OUT_BITS-1 downto OUT_INDEX)         <= data_out;
      tracer_data_fill(FILL_INDEX+FILL_BITS-1 downto FILL_INDEX) <= std_logic_vector(data_fill);

    end generate message_tracer_inputs_gen;
  end generate message_tracer_gen;

  -------------------------------
  -- Instantiate trigger-logic --
  -------------------------------

  no_trigger_gen : if not HAVE_TRIGGER generate
    trig_err    <= '0';
    trig_rsp    <= '0';
    trigger_out <= (others => '0');
  end generate no_trigger_gen;

  trigger_gen : if HAVE_TRIGGER generate
    signal ports_in : std_logic_vector(SINGLE_EVENTS_PORT_BITS-1 downto 0);
  begin

    -- generate the port-inputs

    ports_in_gen : for i in 0 to SINGLE_EVENT_CNT-1 generate
      constant PORT_INDEX : natural := sumSingleEventsPortBits(SINGLE_EVENTS, i);
      constant BITS       : natural := SINGLE_EVENTS(i).PORT_IN.INPUTS*SINGLE_EVENTS(i).PORT_IN.WIDTH;
      constant SRC_INDEX  : natural := getPortValueIndex(PORTS, SINGLE_EVENTS(i).PORT_IN.ID);
    begin

      ports_in(PORT_INDEX+BITS-1 downto PORT_INDEX) <= port_values(SRC_INDEX+BITS-1 downto SRC_INDEX);

    end generate ports_in_gen;

    -- tracer-instantiation

    trigger_top_inst : trace_trigger_top
      generic map (
        SINGLE_EVENTS           => SINGLE_EVENTS,          
        TRIGGER_ARRAY           => TRIGGER_ARRAY,
        SINGLE_EVENTS_PORT_BITS => SINGLE_EVENTS_PORT_BITS,
        TRIGGER_OUT_BITS        => TRIGGER_OUT_BITS,
        TRIG_REG_INDEX_BITS     => TRIG_REG_INDEX_BITS,
        TRIG_REG_MAX_BITS       => TRIG_REG_MAX_BITS,
        TRIGGER_CNT             => TRIGGER_CNT,
        TRIGGER_MAX_EVENTS      => TRIGGER_MAX_EVENTS
      )
      port map (
        clk             => clk_trc,
        rst             => rst_trc,
        err             => trig_err,
        rsp             => trig_rsp,
        ports_in        => ports_in,
        trc_enables_out => trigger_trc_enables,
        send_starts_out => trigger_send_starts,
        send_stops_out  => trigger_send_stops,
        send_dos_out    => trigger_send_dos,
        setReg          => trig_reg_set,
        setRegIndex     => trig_reg_index,
        setRegValue     => trig_reg_val,
        setCmp          => trig_cmp_set,
        set1CmpValue    => trig_cmp1_val,
        set2CmpValue    => trig_cmp2_val,
        setTrigIndex    => trig_index,
        setActiv        => trig_activ_set,
        setActivSel     => trig_activ_sel,
        setMode         => trig_mode_set,
        setModeValue    => trig_mode_val,
        setType         => trig_type_set,
        setTypeValue    => trig_type_val,
        fired           => trig_fired,
        fired_stb       => trig_fired_stb
      );

    -- generate trigger-out-signals
    -- (triggers in trigger_records, that are not instantiiated, are tied to zero)
    trigger_out_gen : for i in 0 to countTriggerNoDoublings(TRIGGER_RECORDS_ALL)-1 generate
      constant LEVEL       : positive := getTriggerLevel(TRIGGER_RECORDS_ALL(i), SINGLE_EVENTS_ALL);
      constant OUT_INDEX   : natural  := sumTriggerOutBits(TRIGGER_RECORDS_ALL, SINGLE_EVENTS_ALL, i);  
    begin  
    
      inst_gen : if containsTrigger(TRIGGER_ARRAY, TRIGGER_RECORDS_ALL(i).ID) generate
        constant ARRAY_INDEX : natural  := getTriggerIndex(TRIGGER_ARRAY, TRIGGER_RECORDS_ALL(i).ID);
        constant SIG_INDEX   : natural  := sumTriggerOutBits(TRIGGER_ARRAY, SINGLE_EVENTS, ARRAY_INDEX);
      begin
        trigger_out(OUT_INDEX+LEVEL-1 downto OUT_INDEX) <= trigger_send_starts(SIG_INDEX+LEVEL-1 downto SIG_INDEX) or 
                                                           trigger_send_stops(SIG_INDEX+LEVEL-1 downto SIG_INDEX) or 
                                                           trigger_send_dos(SIG_INDEX+LEVEL-1 downto SIG_INDEX);
      end generate inst_gen;
      
      no_inst_gen : if not containsTrigger(TRIGGER_ARRAY, TRIGGER_RECORDS_ALL(i).ID) generate
      begin
        trigger_out(OUT_INDEX+LEVEL-1 downto OUT_INDEX) <= (others => '0');
      end generate no_inst_gen;

    end generate trigger_out_gen;

  end generate trigger_gen;

end Behavioral;
