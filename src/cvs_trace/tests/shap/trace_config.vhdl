------------------------------------------------------
-- trace_config.vhdl                                --
-- Configuration file                               --
--                                                  --
-- Stefan Alex                                      --
-- Technische Universitaet Dresden                  --
------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library common;
use common.config.all;

library poc;
use poc.functions.all;
use poc.trace_functions.all;
use poc.trace_types.all;

package trace_config is

  -- see shap.vhdl
  constant RWTAG_BITS    : positive := log2ceil(CORE_CNT+1)+1;

  -----------------------------------------------------------------------------
  -- Ports
  --
  -- Compression COMP is deactivated until it is fixed.
  -----------------------------------------------------------------------------

  -- make sure, that all port, that are used in the same tracer have the same
  -- amount of inputs

  constant BYTECODE_PORT         : tPort := (ID     => 1,
                                             WIDTH  => 32,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);--diffC);

  constant BYTECODE_BRANCH_PORT  : tPort := (ID     => 3,
                                             WIDTH  => 3,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);

  constant BYTECODE_LENGTH_PORT  : tPort := (ID     => 4,
                                             WIDTH  => 4,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);--diffC);

  constant MICROCODE_PORT        : tPort := (ID     => 5,
                                             WIDTH  => 11,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);

  constant MICROCODE_BRANCH_PORT : tPort := (ID     => 7,
                                             WIDTH  => 3,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);

  constant MMCDP_ADR_1_PORT     : tPort := (ID     => 8,
                                             WIDTH  => REF_BITS,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);--trimC);

  constant MMCDP_ADR_2_PORT     : tPort := (ID     => 9,
                                             WIDTH  => OFFS_BITS,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);--trimC);

  constant MMCDP_DATA_PORT       : tPort := (ID     => 10,
                                             WIDTH  => 32,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);--xorC);

  constant MMCDP_SOURCE_PORT    : tPort := (ID     => 11,
                                             WIDTH  => RWTAG_BITS,
                                             INPUTS => 1,
                                             COMP   => noneC);

  constant MMCDP_RW_PORT        : tPort := (ID     => 12,
                                             WIDTH  => 1,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);

  constant WISHBONE_ADR_PORT     : tPort := (ID     => 13,
                                             WIDTH  => 32,
                                             INPUTS => 1,
                                             COMP   => noneC);--trimC);

  constant WISHBONE_DATA_PORT     : tPort := (ID     => 14,
                                             WIDTH  => 32,
                                             INPUTS => 1,
                                             COMP   => noneC);

  constant WISHBONE_SOURCE_PORT  : tPort := (ID     => 15,
                                             WIDTH  => log2ceilnz(CORE_CNT),
                                             INPUTS => 1,
                                             COMP   => noneC);--diffC);

  constant WISHBONE_RW_PORT      : tPort := (ID     => 16,
                                             WIDTH  => 1,
                                             INPUTS => 1,
                                             COMP   => noneC);

  constant THREAD_PORT           : tPort := (ID     => 17,
                                             WIDTH  => REF_BITS,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);--diffC);

  constant GC_REF_PORT           : tPort := (ID     => 18,
                                             WIDTH  => REF_BITS,
                                             INPUTS => 1,
                                             COMP   => noneC);--diffC);

  constant MM_MOV_REF_PORT       : tPort := (ID     => 19,
                                             WIDTH  => REF_BITS,
                                             INPUTS => 1,
                                             COMP   => noneC);--diffC);

  constant MM_MOV_BASE_PORT      : tPort := (ID     => 20,
                                             WIDTH  => BASE_BITS,
                                             INPUTS => 1,
                                             COMP   => noneC);--diffC);

  constant MM_MOV_CMD_PORT       : tPort := (ID     => 21,
                                             WIDTH  => 2,
                                             INPUTS => 1,
                                             COMP   => noneC);--diffC);

  constant METHOD_PORT           : tPort := (ID     => 22,
                                             WIDTH  => 32,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);

  constant MC_PORT               : tPort := (ID     => 23,
                                             WIDTH  => 32,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);

  constant MMU_PORT              : tPort := (ID     => 24,
                                             WIDTH  => 32,
                                             INPUTS => 1,
                                             COMP   => noneC);

  constant MC_METRIC_PORT        : tPort := (ID     => 25,
                                             WIDTH  => 32,
                                             INPUTS => CORE_CNT,
                                             COMP   => noneC);

  constant ENABLE_PORT           : tPort := (ID     => 26,
                                             WIDTH  => 1,
                                             INPUTS => 1,
                                             COMP   => noneC);

  -- List all ports by type
  constant INST_PORTS        : tPorts := (BYTECODE_PORT, MICROCODE_PORT);
  constant INST_BRANCH_PORTS : tPorts := (BYTECODE_BRANCH_PORT,
                                          MICROCODE_BRANCH_PORT);

  constant MEM_ADR_PORTS     : tPorts := (MMCDP_ADR_1_PORT, MMCDP_ADR_2_PORT,
                                          WISHBONE_ADR_PORT);
  constant MEM_DATA_PORTS    : tPorts := (MMCDP_DATA_PORT, WISHBONE_DATA_PORT);

  constant MEM_SOURCE_PORTS  : tPorts := (WISHBONE_SOURCE_PORT, NULL_PORT);
  constant MEM_RW_PORTS      : tPorts := (MMCDP_RW_PORT, WISHBONE_RW_PORT);

  constant MESSAGE_PORTS     : tPorts := (THREAD_PORT, MMU_PORT, MC_PORT,
                                          METHOD_PORT, GC_REF_PORT,
                                          MM_MOV_REF_PORT, MM_MOV_BASE_PORT,
                                          MM_MOV_CMD_PORT, ENABLE_PORT);

  constant STATISTIC_PORTS   : tPorts := (BYTECODE_LENGTH_PORT, MC_METRIC_PORT);
  
  -----------------------------------------------------------------------------
  -- Events
  -----------------------------------------------------------------------------

  constant SE_ENABLE : tSingleEvent := (ID        => 1,
                                        PORT_IN   => ENABLE_PORT,
                                        TWO_REGS  => false,
                                        LEVEL_OR  => true,
                                        REG1_INIT => (others => '1'),
                                        REG2_INIT => (others => '0'),
                                        CMP1_INIT => equal,
                                        CMP2_INIT => betweenEqualRange);

  -- Example for a method match. Compare values are start and end address of
  -- method
  constant SE_METHOD : tSingleEvent := (ID        => 2,
                                        PORT_IN   => METHOD_PORT,
                                        TWO_REGS  => true,
                                        LEVEL_OR  => true,
                                        REG1_INIT => (MAX_PORT_WIDTH-1 downto 32 => '0') & X"1fd4000a",
                                        REG2_INIT => (MAX_PORT_WIDTH-1 downto 32 => '0') & X"1fd40049",
                                        CMP1_INIT => equal,
                                        CMP2_INIT => betweenEqualRange);

  -- Example for a complex event.
  constant CE_METHOD   : tNat_array := (SE_METHOD.ID, SE_ENABLE.ID, 0, 0, 0);

  -- List all single events.
  constant SINGLE_EVENT_RECORDS : tSingleEvent_array := (SE_ENABLE, SE_METHOD);
  
  -----------------------------------------------------------------------------
  -- Trigger
  -----------------------------------------------------------------------------
  
  constant TRIG_ENABLE : tTrigger := (ID               => 1,
                                      SINGLE_EVENT_IDS => (SE_ENABLE.ID, 0, 0, 0, 0),
                                      COMPLEX_EVENTS   => NULL_COMPLEX_EVENTS,
                                      TYPE_INIT        => Normal,
                                      MODE_INIT        => PointTrigger);

  -- Example usage of complex event
  constant TRIG_METHOD    : tTrigger := (ID               => 2,
                                         SINGLE_EVENT_IDS => (0, 0, 0, 0, 0),
                                         COMPLEX_EVENTS   => (CE_METHOD, NULL_SINGLE_EVENT_IDS),
                                         TYPE_INIT        => Normal,
                                         MODE_INIT        => PostTrigger);

  -- List all trigger
  constant TRIGGER_RECORDS : tTrigger_array := (TRIG_ENABLE, TRIG_METHOD);
  
  -----------------------------------------------------------------------------
  -- Tracer
  --
  -- Instantiation configured by flavor.
  -----------------------------------------------------------------------------

  -- For definition of instruction counter see trace_instrTracer.vhdl
  -- LS_ENCODING has not been verified yet
  -- Use no history for easier manual decoding
  -- Only bytecode instructions are strobed, not immediates (see core_top.vhdl).
  -- Thus, instruction counter denotes the nummber of bytecode instructions
  -- instead of bytecode bytes.
  constant SHAP_BYTECODE            : tInstGen      := (ADR_PORT      => BYTECODE_PORT,
                                                        BRANCH_PORT   => BYTECODE_BRANCH_PORT,
                                                        COUNTER_BITS  => 8,
                                                        HISTORY_BYTES => 0,
                                                        LS_ENCODING   => false,
                                                        FIFO_DEPTH    => 1023,
                                                        FIFO_SDS      => 15,
                                                        PRIORITY      => 7,
                                                        TRIGGER       => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE   => TRC_BYTECODE);

  constant SHAP_BYTECODE_LENGTH     : tMessageGen :=   (MSG_PORTS   => (BYTECODE_LENGTH_PORT, NULL_PORT, NULL_PORT),
                                                        FIFO_DEPTH  => 127,
                                                        FIFO_SDS    => 1,
                                                        RESYNC      => true,
                                                        PRIORITY    => 5,
                                                        TRIGGER     => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE => TRC_BYTECODE_LENGTH);

  -- For definition of instruction counter see trace_instrTracer.vhdl
  -- LS_ENCODING has not been verified yet
  -- Use no history for easier manual decoding
  constant SHAP_MICROCODE           : tInstGen      := (ADR_PORT      => MICROCODE_PORT,
                                                        BRANCH_PORT   => MICROCODE_BRANCH_PORT,
                                                        COUNTER_BITS  => 4,
                                                        HISTORY_BYTES => 0,
                                                        LS_ENCODING   => false,
                                                        FIFO_DEPTH    => 1023,
                                                        FIFO_SDS      => 15,
                                                        PRIORITY      => 7,
                                                        TRIGGER       => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE   => TRC_MICROCODE);

  constant SHAP_MMCDP                : tMemGen       := (ADR_PORTS   => (MMCDP_ADR_1_PORT, MMCDP_ADR_2_PORT),
                                                        DATA_PORT   => MMCDP_DATA_PORT,
                                                        SOURCE_PORT => MMCDP_SOURCE_PORT,
                                                        RW_PORT     => MMCDP_RW_PORT,
                                                        COLLECT_VAL => false,
                                                        FIFO_DEPTH  => 1023,
                                                        FIFO_SDS    => 15,
                                                        PRIORITY    => 1,
                                                        TRIGGER       => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE => TRC_MEM);

  constant SHAP_WISHBONE            : tMemGen       := (ADR_PORTS   => (WISHBONE_ADR_PORT, NULL_PORT),
                                                        DATA_PORT   => WISHBONE_DATA_PORT,
                                                        SOURCE_PORT => WISHBONE_SOURCE_PORT,
                                                        RW_PORT     => WISHBONE_RW_PORT,
                                                        COLLECT_VAL => false,
                                                        FIFO_DEPTH  => 1023,
                                                        FIFO_SDS    => 15,
                                                        PRIORITY    => 1,
                                                        TRIGGER     => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE => TRC_WISHBONE);

  constant SHAP_THREAD              : tMessageGen   := (MSG_PORTS   => (THREAD_PORT, NULL_PORT, NULL_PORT),
                                                        FIFO_DEPTH  => 127,
                                                        FIFO_SDS    => 3,
                                                        RESYNC      => true,
                                                        PRIORITY    => 5,
                                                        TRIGGER     => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE => TRC_THREAD);

  constant SHAP_MMU                 : tMessageGen   := (MSG_PORTS   => (MMU_PORT, NULL_PORT, NULL_PORT),
                                                        FIFO_DEPTH  => 127,
                                                        FIFO_SDS    => 3,
                                                        RESYNC      => false,
                                                        PRIORITY    => 1,
                                                        TRIGGER     => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE => TRC_MMU);

  constant SHAP_MC                  : tMessageGen   := (MSG_PORTS   => (MC_PORT, NULL_PORT, NULL_PORT),
                                                        FIFO_DEPTH  => 127,
                                                        FIFO_SDS    => 7,
                                                        RESYNC      => false,
                                                        PRIORITY    => 1,
                                                        TRIGGER     => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE => TRC_MC);

  constant SHAP_METHOD_CACHE_METRIC : tMessageGen   := (MSG_PORTS   => (MC_METRIC_PORT, NULL_PORT, NULL_PORT),
                                                        FIFO_DEPTH  => 127,
                                                        FIFO_SDS    => 15,
                                                        RESYNC      => true,
                                                        PRIORITY    => 5,
                                                        TRIGGER     => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE => TRC_METHOD_CACHE_METRIC);

  constant SHAP_METHOD              : tMessageGen   := (MSG_PORTS   => (METHOD_PORT, NULL_PORT, NULL_PORT),
                                                        FIFO_DEPTH  => 511,
                                                        FIFO_SDS    => 15,
                                                        RESYNC      => true,
                                                        PRIORITY    => 10,
                                                        TRIGGER     => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE => TRC_METHOD);

  constant SHAP_GC_REF              : tMessageGen   := (MSG_PORTS   => (GC_REF_PORT, NULL_PORT, NULL_PORT),
                                                        FIFO_DEPTH  => 127,
                                                        FIFO_SDS    => 63,
                                                        RESYNC      => false,
                                                        PRIORITY    => 10,
                                                        TRIGGER     => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE => TRC_GC_REF);

  constant SHAP_MM_MOV              : tMessageGen   := (MSG_PORTS   => (MM_MOV_REF_PORT, MM_MOV_CMD_PORT, MM_MOV_BASE_PORT),
                                                        FIFO_DEPTH  => 63,
                                                        FIFO_SDS    => 31,
                                                        RESYNC      => false,
                                                        PRIORITY    => 1,
                                                        TRIGGER     => (TRIG_ENABLE.ID, 0),
                                                        INSTANTIATE => TRC_MM_MOV);

  -- List all tracer by type
  
  constant INST_TRACER_GENS    : tInstGens    := (SHAP_BYTECODE,
                                                  SHAP_MICROCODE);
  constant MEM_TRACER_GENS     : tMemGens     := (SHAP_MMCDP, SHAP_WISHBONE);
  constant MESSAGE_TRACER_GENS : tMessageGens := (SHAP_THREAD, SHAP_MMU,
                                                  SHAP_MC, SHAP_METHOD,
                                                  SHAP_GC_REF, SHAP_MM_MOV,
                                                  SHAP_BYTECODE_LENGTH,
                                                  SHAP_METHOD_CACHE_METRIC);

  -----------------------------------------------------------------------------
  -- In-Circuit-Emulator config
  -----------------------------------------------------------------------------

  constant ICE_REGISTERS  : tNat_array := (13, 8);
  constant ICE_TRIGGER    : tNat_array(0 to MAX_TRIGGER-1) := NULL_TRIGGER_IDs;
  constant ICE_REG_CNT_NZ : positive := 2; --notZero(countValuesGreaterThan(ICE_REGISTERS, 0));


  -----------------------------------------------------------------------------
  -- Global Configuration
  -----------------------------------------------------------------------------

  -- Cycle-Accurate Trace
  constant CYCLE_ACCURATE     : boolean           := false;

  -- Overflow reaction
  constant OV_DANGER_REACTION : tOvDangerReaction := None;
  constant FILTER_INTERVAL    : positive          := 12;

  -- Trigger
  constant TRIGGER_INFORM : boolean  := false;
  constant PRETRIGGER_INT : positive := 8000; -- cycles

  -- global_time and tracer_time config
  constant TIME_CMP_LEVELS           : positive := 2;
  constant TIME_BITS                 : positive := 4;
  constant GLOBAL_TIME_SAFE_DISTANCE : positive := 7;
  constant GLOBAL_TIME_FIFO_DEPTH    : positive := 127;
  constant TRACER_TIME_SAFE_DISTANCE : positive := 15;
  constant TRACER_TIME_FIFO_DEPTH    : positive := 127;

  -- Required to collect enough trace data bytes inside trace_ctrl to fill
  -- the ethernet packet with the minimum count of bytes (46-1).
  -- Cannot be included in trace_eth because there is a packet multiplexer
  -- after that FIFO.
  constant MIN_DATA_PACKET_SIZE : positive := 46;

  -----------------------------------------------------------------------------
  -- Interface-Calculations
  -----------------------------------------------------------------------------

  constant INST_ADR_BITS        : positive := calculateValueBits(INST_PORTS);
  constant INST_STB_BITS        : positive := calculateStbBits(INST_PORTS);
  constant INST_BRANCH_BITS     : positive := calculateValueBits(INST_BRANCH_PORTS);
  constant INST_BRANCH_STB_BITS : positive := calculateStbBits(INST_BRANCH_PORTS);
  constant MEM_ADR_BITS         : positive := calculateValueBits(MEM_ADR_PORTS);
  constant MEM_ADR_STB_BITS     : positive := calculateStbBits(MEM_ADR_PORTS);
  constant MEM_DAT_BITS         : positive := calculateValueBits(MEM_DATA_PORTS);
  constant MEM_DAT_STB_BITS     : positive := calculateStbBits(MEM_DATA_PORTS);
  constant MEM_SOURCE_BITS      : positive := calculateValueBits(MEM_SOURCE_PORTS);
  constant MEM_SOURCE_STB_BITS  : positive := calculateStbBits(MEM_SOURCE_PORTS);
  constant MEM_RW_BITS          : positive := calculateValueBits(MEM_RW_PORTS);
  constant MEM_RW_STB_BITS      : positive := calculateValueBits(MEM_RW_PORTS);
  constant MESSAGE_BITS         : positive := calculateValueBits(MESSAGE_PORTS);
  constant MESSAGE_STB_BITS     : positive := calculateStbBits(MESSAGE_PORTS);
  constant STAT_BITS            : positive := calculateStbBits(STATISTIC_PORTS);
  constant ICE_REG_BITS         : positive := notZero(sum(ICE_REGISTERS));
  constant TRIGGER_BITS         : positive := notZero(sumTriggerOutBits(removeNullValues(TRIGGER_RECORDS),
                                                                        removeNullValues(SINGLE_EVENT_RECORDS)));

end trace_config;

package body trace_config is
end trace_config;
