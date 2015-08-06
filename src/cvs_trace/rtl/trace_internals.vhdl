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
-- Package: trace_internals
-- Author(s): Stefan Alex
-- 
-- Internal Components and Constants for Trace-Unit
--
-- Revision:    $Revision: 1.11 $
-- Last change: $Date: 2010-04-30 07:21:35 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library poc;
use poc.functions.all;

use poc.trace_types.all;
use poc.trace_functions.all;

package trace_internals is

  ---------------------------
  -- Component-Declaration --
  ---------------------------

  component trace_ctrl
    generic (
      CONFIG                    : tSlv8_array;
      ICE_REGISTERS             : tNat_array;
      TRIGGER_INFORM            : boolean;
      TRIGGER_CNT               : natural;
      TRIGGER_OUT_BITS          : natural;
      TRIG_ACTIV_BITS           : positive;
      TRIG_REG_INDEX_BITS       : positive;
      TRIG_REG_BITS             : tNat_array;
      HAVE_ICE_TRIGGER          : boolean;
      TRIG_CMP1_BITS            : positive;
      TRIG_CMP2_BITS            : positive;
      TRIG_MODE_BITS            : positive;
      TRIG_TYPE_BITS            : positive;
      CYCLE_ACCURATE            : boolean;
      OV_DANGER_REACTION        : tOvDangerReaction;
      FILTER_INTERVAL           : natural;
      MIN_DATA_PACKET_SIZE      : positive;
      TIME_BITS                 : t1To8Int;
      TIME_CMP_LEVELS           : t1To8Int;
      GLOBAL_TIME_SAFE_DISTANCE : positive;
      GLOBAL_TIME_FIFO_DEPTH    : positive;
      TRACER_TIME_SAFE_DISTANCE : positive;
      TRACER_TIME_FIFO_DEPTH    : positive;
      TRACER_CNT                : positive;
      TRACER_DATA_BITS          : tNat_array;
      DO_RESYNC                 : boolean
    );
    port (
      clk_trc           : in  std_logic;
      rst_trc           : in  std_logic;
      clk_sys           : in  std_logic;
      rst_sys           : in  std_logic;
      trace_running     : out std_logic;
      resync            : out std_logic;
      ice_trig          : in  std_logic;
      cpu_stall         : out std_logic;
      ice_regs_in       : in  std_logic_vector(notZero(sum(ICE_REGISTERS))-1 downto 0);
      ice_regs_out      : out std_logic_vector(notZero(sum(ICE_REGISTERS))-1 downto 0);
      ice_store         : out std_logic_vector(notZero(countValuesGreaterThan(ICE_REGISTERS, 0))-1 downto 0);
      eth_full          : out std_logic;
      eth_din           : in  std_logic_vector(7 downto 0);
      eth_put           : in  std_logic;
      eth_valid         : out std_logic;
      eth_last          : out std_logic;
      eth_dout          : out std_logic_vector(7 downto 0);
      eth_got           : in  std_logic;
      eth_finish        : in  std_logic;
      header            : out std_logic;
      trig_err          : in  std_logic;
      trig_rsp          : in  std_logic;
      filter_data       : out std_logic;
      filter_adr        : out std_logic;
      st_stb            : out std_logic;
      st_msg            : out std_logic_vector(TRACER_CNT*2+2+
                                               ifThenElse(CYCLE_ACCURATE, 1, 0)+
                                               ifThenElse(TRIGGER_INFORM, TRIGGER_OUT_BITS, 0)-1 downto 0);
      tracer_stbs       : in  std_logic_vector(TRACER_CNT-1 downto 0);
      tracer_stb_en     : out std_logic;
      tracer_data       : in  std_logic_vector(sum(TRACER_DATA_BITS)-1 downto 0);
      tracer_data_fill  : in  std_logic_vector(sum(log2ceilnz(TRACER_DATA_BITS))-1 downto 0);
      tracer_data_last  : in  std_logic_vector(TRACER_CNT-1 downto 0);
      tracer_data_got   : out std_logic_vector(TRACER_CNT-1 downto 0);
      tracer_data_se    : in  std_logic_vector(TRACER_CNT-1 downto 0);
      tracer_data_valid : in  std_logic_vector(TRACER_CNT-1 downto 0);
      tracer_sel        : out std_logic_vector(TRACER_CNT-1 downto 0);
      tracer_ovs        : in  std_logic_vector(TRACER_CNT-1 downto 0);
      tracer_ov_starts  : in  std_logic_vector(TRACER_CNT-1 downto 0);
      tracer_ov_stops   : in  std_logic_vector(TRACER_CNT-1 downto 0);
      tracer_ov_dangers : in  std_logic_vector(TRACER_CNT-1 downto 0);
      trig_reg_set      : out std_logic;
      trig_reg_index    : out unsigned(TRIG_REG_INDEX_BITS-1 downto 0);
      trig_reg_val      : out std_logic_vector(notZero(max(TRIG_REG_BITS))-1 downto 0);
      trig_cmp_set      : out std_logic;
      trig_cmp1_val     : out tTriggerCmp1;
      trig_cmp2_val     : out tTriggerCmp2;
      trig_index        : out unsigned(notZero(log2ceilnz(notZero(TRIGGER_CNT)))-1 downto 0);
      trig_mode_set     : out std_logic;
      trig_mode_val     : out tTriggerMode;
      trig_type_set     : out std_logic;
      trig_type_val     : out tTriggerType;
      trig_activ_set    : out std_logic;
      trig_activ_sel    : out unsigned(TRIG_ACTIV_BITS-1 downto 0);
      trig_fired        : in  std_logic_vector(notZero(TRIGGER_OUT_BITS)-1 downto 0);
      trig_fired_stb    : in  std_logic
    );
  end component;

  component trace_tracer_time
    generic (
      TRACER                    : positive;
      TRACER_TIME_SAFE_DISTANCE : positive;
      TRACER_TIME_FIFO_DEPTH    : positive
    );
    port (
      clk_trc               : in  std_logic;
      rst_trc               : in  std_logic;
      clk_sys               : in  std_logic;
      rst_sys               : in  std_logic;
      tracer_stbs           : in  std_logic_vector(TRACER-1 downto 0);
      tracer_data_se        : in  std_logic_vector(TRACER-1 downto 0);
      tracer_sel            : out std_logic_vector(TRACER-1 downto 0);
      stb_en_in             : in  std_logic;
      stb_en_out            : out std_logic;
      ov_stop               : out std_logic;
      ov_danger             : out std_logic;
      done_tracer           : in  std_logic;
      current_tracer        : out unsigned(log2ceilnz(TRACER)-1 downto 0);
      first_tracer_in_level : out std_logic;
      last_tracer_in_level  : out std_logic;
      valid_out             : out std_logic
    );
  end component;

  component trace_global_time
    generic (
      TIME_BITS                 : positive;
      TIME_CMP_LEVELS           : positive;
      GLOBAL_TIME_SAFE_DISTANCE : positive;
      GLOBAL_TIME_FIFO_DEPTH    : positive
    );
    port (
      clk_trc       : in  std_logic;
      rst_trc       : in  std_logic;
      clk_sys       : in  std_logic;
      rst_sys       : in  std_logic;
      enable        : in  std_logic;
      ov_stop       : out std_logic;
      ov_danger     : out std_logic;
      tracer_stb    : in  std_logic;
      stb_en        : out std_logic;
      current_level : out unsigned(log2ceilnz(TIME_CMP_LEVELS)-1 downto 0);
      current_time  : out std_logic_vector(TIME_BITS-1 downto 0);
      no_data       : out std_logic;
      done_level    : in  std_logic;
      valid_out     : out std_logic
      );
  end component;

  component trace_value_sel
    generic (
      CYCLE_ACCURATE   : boolean;
      TRACER_CNT       : positive;
      TRACER_DATA_BITS : tNat_array;
      TIME_CMP_LEVELS  : positive;
      TIME_BITS        : positive
      );
    port (
      clk_sys               : in  std_logic;
      rst_sys               : in  std_logic;
      valid_in              : in  std_logic;
      tracer_data           : in  std_logic_vector(sum(TRACER_DATA_BITS)-1 downto 0);
      tracer_data_fill      : in  std_logic_vector(sum(log2ceilnz(TRACER_DATA_BITS))-1 downto 0);
      tracer_data_last      : in  std_logic_vector(TRACER_CNT-1 downto 0);
      tracer_data_got       : out std_logic_vector(TRACER_CNT-1 downto 0);
      current_tracer        : in  unsigned(log2ceilnz(TRACER_CNT)-1 downto 0);
      first_tracer_in_level : in  std_logic;
      last_tracer_in_level  : in  std_logic;
      done_tracer           : out std_logic;
      current_level         : in  unsigned(log2ceilnz(TIME_CMP_LEVELS)-1 downto 0);
      current_time          : in  std_logic_vector(TIME_BITS-1 downto 0);
      no_data               : in  std_logic;
      done_level            : out std_logic;
      next_value            : out std_logic_vector(max(TRACER_DATA_BITS)+ifThenElse(CYCLE_ACCURATE, TIME_BITS*TIME_CMP_LEVELS, 0)-1 downto 0);
      next_value_fill       : out unsigned(log2ceilnz(max(TRACER_DATA_BITS)+ifThenElse(CYCLE_ACCURATE, TIME_BITS*TIME_CMP_LEVELS, 0))-1 downto 0);
      next_value_got        : in  std_logic;
      next_value_valid      : out std_logic
      );
  end component;

  component trace_value_2fifo
    generic (
      BLOCK_BITS : positive;
      IN_BLOCKS  : positive;
      OUT_BLOCKS : positive
      );
    port (
      clk : in  std_logic;
      rst : in  std_logic;
      -- input-values
      in_value_got   : out std_logic;
      in_value       : in  std_logic_vector(IN_BLOCKS*BLOCK_BITS-1 downto 0);
      in_value_fill  : in  unsigned(log2ceilnz(IN_BLOCKS)-1 downto 0);
      in_value_valid : in  std_logic;
      -- output-fifo-interface
      fifo_dat  : out std_logic_vector(OUT_BLOCKS*BLOCK_BITS-1 downto 0);
      fifo_put  : out std_logic;
      fifo_full : in  std_logic;
      fifo_ptr  : out unsigned(log2ceil(OUT_BLOCKS)-1 downto 0)
      );
  end component;

  component trace_value_collect
    generic (
      NUM_BYTES : positive
    );
    port (
      data_in   : in  std_logic_vector(NUM_BYTES*8-1 downto 0);
      data_mark : in  std_logic_vector(NUM_BYTES-1 downto 0);
      data_col  : out std_logic_vector(NUM_BYTES*8-1 downto 0);
      data_fill : out unsigned(log2ceilnz(NUM_BYTES+1)-1 downto 0)
    );
  end component;

  -- Tracer

  component trace_instTracer
    generic (
      ADR_PORT      : tPort;
      BRANCH_INFO   : boolean;
      COUNTER_BITS  : positive;
      HISTORY_BYTES : natural;
      LS_ENCODING   : boolean;
      FIFO_DEPTH    : positive;
      FIFO_SDS      : positive;
      CODING        : boolean;
      CODING_VAL    : std_logic_vector;
      TIME_BITS     : natural
    );
    port (
      clk_trc     : in  std_logic;
      rst_trc     : in  std_logic;
      clk_sys     : in  std_logic;
      rst_sys     : in  std_logic;
      adr         : in  std_logic_vector(ADR_PORT.WIDTH-1 downto 0);
      adr_stb     : in  std_logic;
      branch      : in  std_logic_vector(ifThenElse(BRANCH_INFO, 2, 0) downto 0);
      stb_out     : out std_logic;
      data_out    : out std_logic_vector(getInstDataOutBits(ADR_PORT, BRANCH_INFO, COUNTER_BITS, HISTORY_BYTES,
                                                            ifThenElse(CODING, CODING_VAL'length, 0),
                                                            TIME_BITS)-1 downto 0);
      data_got    : in  std_logic;
      data_fill   : out unsigned(log2ceilnz(getInstDataOutBits(ADR_PORT, BRANCH_INFO, COUNTER_BITS, HISTORY_BYTES,
                                                               ifThenElse(CODING, CODING_VAL'length, 0),
                                                               TIME_BITS))-1 downto 0);
      data_last   : out std_logic;
      data_se     : out std_logic;
      data_valid  : out std_logic;
      sel         : in  std_logic;
      trc_enable  : in  std_logic;
      stb_enable  : in  std_logic;
      send_enable : in  std_logic;
      ov          : out std_logic;
      ov_start    : out std_logic;
      ov_stop     : out std_logic;
      ov_danger   : out std_logic
      );
  end component;

  component trace_memTracer
    generic (
      ADR_PORTS   : tPorts;
      DATA_PORT   : tPort;
      SOURCE_BITS : natural;
      COLLECT_VAL : boolean;
      FIFO_DEPTH  : positive;
      FIFO_SDS    : positive;
      CODING      : boolean;
      CODING_VAL  : std_logic_vector;
      TIME_BITS   : natural
    );
    port (
      clk_trc     : in  std_logic;
      clk_sys     : in  std_logic;
      rst_trc     : in  std_logic;
      rst_sys     : in  std_logic;
      adr         : in  std_logic_vector(sumWidths(ADR_PORTS)-1 downto 0);
      adr_stbs    : in  std_logic_vector(countPorts(ADR_PORTS)-1 downto 0);
      data        : in  std_logic_vector(DATA_PORT.WIDTH-1 downto 0);
      data_stb    : in  std_logic;
      src         : in  std_logic_vector(notZero(SOURCE_BITS)-1 downto 0);
      rw          : in  std_logic;
      stb_out     : out std_logic;
      data_out    : out std_logic_vector(getMemDataOutBits(ADR_PORTS, DATA_PORT, SOURCE_BITS,
                                                           ifThenElse(CODING, CODING_VAL'length, 0),
                                                           TIME_BITS)-1 downto 0);
      data_got    : in  std_logic;
      data_fill   : out unsigned(log2ceilnz(getMemDataOutBits(ADR_PORTS, DATA_PORT, SOURCE_BITS,
                                                              ifThenElse(CODING, CODING_VAL'length, 0),
                                                              TIME_BITS))-1 downto 0);
      data_last   : out std_logic;
      data_se     : out std_logic;
      data_valid  : out std_logic;
      sel         : in  std_logic;
      trc_enable  : in  std_logic;
      stb_enable  : in  std_logic;
      send_enable : in  std_logic;
      ov          : out std_logic;
      ov_start    : out std_logic;
      ov_stop     : out std_logic;
      ov_danger   : out std_logic;
      adr_en      : in  std_logic;
      data_en     : in  std_logic
    );
  end component;

  component trace_messageTracer
    generic (
      MSG_PORTS  : tPorts;
      FIFO_DEPTH : positive;
      FIFO_SDS   : positive;
      CODING     : boolean;
      CODING_VAL : std_logic_vector;
      TIME_BITS  : natural
    );
    port (
      clk_trc     : in  std_logic;
      rst_trc     : in  std_logic;
      clk_sys     : in  std_logic;
      rst_sys     : in  std_logic;
      stb_out     : out std_logic;
      msgs        : in  std_logic_vector(sumWidths(MSG_PORTS)-1 downto 0);
      stb         : in  std_logic;
      data_out    : out std_logic_vector(getMessageDataOutBits(MSG_PORTS, ifThenElse(CODING, CODING_VAL'length, 0),
                                                               TIME_BITS)-1 downto 0);
      data_fill   : out unsigned(log2ceilnz(getMessageDataOutBits(MSG_PORTS, ifThenElse(CODING, CODING_VAL'length, 0),
                                                                  TIME_BITS))-1 downto 0);
      data_got    : in  std_logic;
      data_last   : out std_logic;
      data_se     : out std_logic;
      data_valid  : out std_logic;
      sel         : in  std_logic;
      trc_enable  : in  std_logic;
      stb_enable  : in  std_logic;
      send_enable : in  std_logic;
      ov          : out std_logic;
      ov_start    : out std_logic;
      ov_stop     : out std_logic;
      ov_danger   : out std_logic
      );
  end component;

  component trace_statistic
    generic (
      COUNTER_BITS : positive
    );
    port (
      clk_trc : in std_logic;
      rst_trc : in std_logic;
      -- prozessor-interface
      inc : in std_logic;
      rst : in std_logic;
      -- Data-Fifo
      counter_value : out std_logic_vector(COUNTER_BITS-1 downto 0);
      counter_stb   : out std_logic
    );
  end component;

  component trace_comp_to_fifo
    generic (
      NUM_BYTES : positive := 4;
      SIMPLE    : boolean  := true
    );
    port (
      clk_trc   : in  std_logic; -- Clock
      rst_trc   : in  std_logic; -- Reset
      data_in   : in  std_logic_vector(NUM_BYTES*8-1 downto 0);
      data_stb  : in  std_logic;
      data_mark : in  std_logic_vector(NUM_BYTES-1 downto 0);
      send      : in  std_logic;
      fifo_dat  : out std_logic_vector(NUM_BYTES*8+log2ceil(NUM_BYTES)-1 downto 0);
      fifo_put  : out std_logic;
      fifo_full : in  std_logic
    );
  end component;

  -- Compression-Components

  component trace_compression
    generic (
      NUM_BYTES   : positive := 8;
      COMPRESSION : tComp := XorC
    );
    port (
      clk      : in  std_logic;
      rst      : in  std_logic;
      data_in  : in  std_logic_vector(NUM_BYTES*8-1 downto 0);
      ie       : in  std_logic;
      compress : in  std_logic;
      len      : out unsigned(log2ceil(NUM_BYTES+1)-1 downto 0);
      len_mark : out std_logic_vector(NUM_BYTES-1 downto 0);
      data_out : out std_logic_vector(NUM_BYTES*8-1 downto 0)
    );
  end component;

  component trace_decompression
    generic (
      NUM_BYTES   : positive := 8;
      COMPRESSION : tComp := XorC
    );
    port (
      -- Globals --
      clk : in  std_logic; -- Clock
      rst : in  std_logic; -- Reset
      -- Inputs --
      len     : in unsigned(log2ceil(NUM_BYTES+1)-1 downto 0); -- Data Length
      data_in : in std_logic_vector(NUM_BYTES*8-1 downto 0);           -- Input Data
      ie      : in std_logic;                                          -- Decompress
      -- Output --
      data_out : out std_logic_vector(NUM_BYTES*8-1 downto 0) -- Output Data
    );
  end component;

  component trace_lsEncoder
    generic (
      MESSAGE_BYTES : positive := 1
    );
    port (
      -- Globals --
      clk : in  std_logic; -- Clock
      rst : in  std_logic; -- Reset
      -- Inputs --
      ie : in std_logic;
      ev : in std_logic;
      -- Outputs --
      message : out std_logic_vector(MESSAGE_BYTES*8-1 downto 0);
      oe      : out std_logic
    );
  end component;

  -- Trigger-Components

  component trace_trigger_top
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
      clk             : in  std_logic;
      rst             : in  std_logic;
      err             : out std_logic;
      rsp             : out std_logic;
      ports_in        : in  std_logic_vector(SINGLE_EVENTS_PORT_BITS-1 downto 0);
      trc_enables_out : out std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
      send_starts_out : out std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
      send_stops_out  : out std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
      send_dos_out    : out std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
      setReg          : in  std_logic;
      setRegIndex     : in  unsigned(TRIG_REG_INDEX_BITS-1 downto 0);
      setRegValue     : in  std_logic_vector(TRIG_REG_MAX_BITS-1 downto 0);
      setCmp          : in  std_logic;
      set1CmpValue    : in  tTriggerCmp1;
      set2CmpValue    : in  tTriggerCmp2;
      setTrigIndex    : in  unsigned(log2ceilnz(TRIGGER_CNT)-1 downto 0);
      setActiv        : in  std_logic;
      setActivSel     : in  unsigned(log2ceilnz(notZero(TRIGGER_MAX_EVENTS))-1 downto 0);
      setMode         : in  std_logic;
      setModeValue    : in  tTriggerMode;
      setType         : in  std_logic;
      setTypeValue    : in  tTriggerType;
      fired           : out std_logic_vector(TRIGGER_OUT_BITS-1 downto 0);
      fired_stb       : out std_logic
    );
  end component;

  component trace_trigger
    generic (
      EVENTS         : positive;
      LEVEL          : positive;
      MODE_INIT      : tTriggerMode;
      TYPE_INIT      : tTriggerType;
      ACTIV_INIT     : std_logic_vector;
      PRETRIGGER_INT : positive
    );
    port (
      clk          : in  std_logic;
      rst          : in  std_logic;
      trigger_in   : in  std_logic_vector(EVENTS*LEVEL-1 downto 0);
      trc_enable   : out std_logic_vector(LEVEL-1 downto 0);
      send_start   : out std_logic_vector(LEVEL-1 downto 0);
      send_stop    : out std_logic_vector(LEVEL-1 downto 0);
      send_do      : out std_logic_vector(LEVEL-1 downto 0);
      setMode      : in  std_logic;
      setModeValue : in  tTriggerMode;
      setType      : in  std_logic;
      setTypeValue : in  tTriggerType;
      setActiv     : in  std_logic;
      setActivSel  : in  unsigned(log2ceilnz(EVENTS)-1 downto 0)
    );
  end component;

  component trace_triggerSingleRegister
    generic (
      INPUTS     : positive;
      WIDTH      : positive;
      REG_INIT   : std_logic_vector;
      CMP_INIT   : tTriggerCmp1
    );
    port (
      clk         : in  std_logic;
      rst         : in  std_logic;
      values_in   : in  std_logic_vector(INPUTS*WIDTH-1 downto 0);
      events      : out std_logic_vector(INPUTS-1 downto 0);
      setReg      : in  std_logic;
      setRegValue : in  std_logic_vector(WIDTH-1 downto 0);
      setCmp      : in  std_logic;
      setCmpValue : in  tTriggerCmp1
    );
  end component;

  component trace_triggerDoubleRegister
    generic (
      INPUTS    : positive;
      WIDTH     : positive;
      REG1_INIT : std_logic_vector;
      REG2_INIT : std_logic_vector;
      CMP_INIT  : tTriggerCmp2
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
  end component;

  -- Utilities

  component trace_clk_sync is
    port (
      clk_dst   : in  std_logic;
      value_in  : in  std_logic;
      value_out : out std_logic
    );
  end component;

  component trace_clk_sync_2
    generic (
      SYNC_STAGES : positive := 1);
    port (
      clk_from       : in  std_logic;
      clk_to         : in  std_logic;
      signal_event   : in  std_logic;
      event_signaled : out std_logic);
  end component;

  component trace_multiplex
    generic (
      DATA_BITS : tNat_array;
      IMPL      : boolean
      );
    port (
      inputs : in  std_logic_vector(sum(DATA_BITS)-1 downto 0);
      sel    : in  unsigned(log2ceilnz(countValuesGreaterThan(DATA_BITS,0))-1 downto 0);
      output : out std_logic_vector(max(DATA_BITS)-1 downto 0)
      );
  end component;

  component trace_demultiplex
    generic (
      BITS : positive;
      CNT  : positive
      );
    port (
      input   : in  std_logic_vector(BITS-1 downto 0);
      sel     : in  unsigned(log2ceilnz(CNT)-1 downto 0);
      outputs : out std_logic_vector(CNT*BITS-1 downto 0)
      );
  end component;

  -- Fifos

  component trace_fifo_ic
    generic (
      D_BITS     : positive;
      MIN_DEPTH  : positive;
      THRESHOLD  : positive;
      OUTPUT_REG : boolean
    );
    port (
      -- Write Interface
      clk_wr    : in  std_logic;
      rst_wr    : in  std_logic;
      put       : in  std_logic;
      din       : in  std_logic_vector(D_BITS-1 downto 0);
      full      : out std_logic;
      thres     : out std_logic;
      -- Read Interface
      clk_rd    : in  std_logic;
      rst_rd    : in  std_logic;
      got       : in  std_logic;
      valid     : out std_logic;
      dout      : out std_logic_vector(D_BITS-1 downto 0)
    );
  end component;

  component trace_sendmux
    generic (
      MIN_DATA_PACKET_SIZE : integer range 2 to 128);
    port (
      clk             : in  std_logic;
      rst             : in  std_logic;
      data_fifo_clear : in  std_logic;
      data_fifo_put   : in  std_logic;
      data_fifo_din   : in  std_logic_vector(7 downto 0);
      data_fifo_full  : out std_logic;
      data_fifo_empty : out std_logic;
      ctrl_valid      : in  std_logic;
      ctrl_data       : in  std_logic_vector(7 downto 0);
      ctrl_last       : in  std_logic;
      ctrl_got        : out std_logic;
      eth_valid       : out std_logic;
      eth_last        : out std_logic;
      eth_dout        : out std_logic_vector(7 downto 0);
      eth_got         : in  std_logic;
      eth_finish      : in  std_logic;
      header          : out std_logic);
  end component;
end trace_internals;

package body trace_internals is

end trace_internals;
