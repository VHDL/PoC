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
-- Package: trace_functions
-- Author(s): Stefan Alex
--
------------------------------------------------------
-- all functions for generic trace-architecture     --
------------------------------------------------------
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2010-04-30 15:25:01 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use std.textio.all;

library poc;
use poc.functions.all;

use poc.trace_types.all;

package trace_functions is

  -- debug
  constant PRINT_NULL  : boolean := false;
  constant PRINT_INDEX : boolean := true;

  --------------------
  -- Port-Functions --
  --------------------

  function isNullPort(P : tPort) return boolean;
  function containsValidPort(PORTS : tPorts) return boolean;
  function containsPort(PORTS : tPorts; ID : natural) return boolean;
  function containsPort(PORTS : tPorts; ID : natural; INDEX : natural) return boolean;

  function countPorts(PORTS : tPorts) return natural;
  function countPortsNoDoublings(PORTS : tPorts) return natural;
  function countPorts(PORTS : tPort2_array) return natural;
  function countPorts(PORTS : tPort2_array; INDEX : natural) return natural;

  function getMaxPortWidth(PORTS : tPorts) return positive;
  function getMinPortInputs(PORTS : tPorts) return natural;
  function getMaxPortInputs(PORTS : tPorts) return natural;
  function getMaxPortId(PORTS : tPorts) return natural;
  function equalInputs(PORTS : tPorts) return boolean;
  function calculateValueBits(PORTS : tPorts) return natural;
  function calculateValueBits(PORTS : tPorts; INDEX : natural) return natural;
  function calculateStbBits(PORTS : tPorts) return natural;
  function calculateStbBits(PORTS : tPorts; INDEX : natural) return natural;
  function getMaxPortsPerTracerWithNp(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural;
  function noDoubleId(PORTS : tPorts) return boolean;

  function sumWidths(PORTS : tPorts) return natural;
  function sumWidths(PORTS : tPorts; INDEX : natural) return natural;
  function getNewId(PORTS : tPorts) return positive;

  function removeDoublings(PORTS : tPorts) return tPorts;
  function removeNullValues(PORTS : tPorts) return tPorts;

  ----------------------
  -- Tracer-Functions --
  ----------------------

  function isNullTracer(INST_TRACER : tInstGen) return boolean;
  function isNullTracer(MEM_TRACER : tMemGen) return boolean;
  function isNullTracer(MESSAGE_TRACER : tMessageGen) return boolean;

  function countTracer(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural;
  function countTracer(INST_TRACER_ALL : tInstGens) return natural;
  function countTracer(MEM_TRACER_ALL : tMemGens) return natural;
  function countTracer(MESSAGE_TRACER_ALL : tMessageGens) return natural;

  function countTracer(INST_TRACER_ALL : tInstGens; INDEX : natural) return natural;
  function countTracer(MEM_TRACER_ALL : tMemGens; INDEX : natural) return natural;
  function countTracer(MESSAGE_TRACER_ALL : tMessageGens; INDEX : natural) return natural;

  function countTracerGens(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural;
  function countTracerGens(INST_TRACER_ALL : tInstGens) return natural;
  function countTracerGens(MEM_TRACER_ALL : tMemGens) return natural;
  function countTracerGens(MESSAGE_TRACER_ALL : tMessageGens) return natural;

  function getInputs(INST_TRACER : tInstGen) return natural;
  function getInputs(MEM_TRACER : tMemGen) return natural;
  function getInputs(MESSAGE_TRACER : tMessageGen) return natural;
  function getInputs(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens;
                     MESSAGE_TRACER_ALL : tMessageGens; INDEX : natural) return natural;

  function getPorts(INST_TRACER : tInstGen) return tPorts;
  function getPorts(MEM_TRACER : tMemGen) return tPorts;
  function getPorts(MESSAGE_TRACER : tMessageGen) return tPorts;

  function getPorts(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tPorts;
  function getPortsNoDoublings(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tPorts;
  function getPorts(INST_TRACER_ALL : tInstGens) return tPorts;
  function getPorts(MEM_TRACER_ALL : tMemGens) return tPorts;
  function getPorts(MESSAGE_TRACER_ALL : tMessageGens) return tPorts;

  function getPorts2(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tPort2_array;
  function getPorts2(INST_TRACER_ALL : tInstGens) return tPort2_array;
  function getPorts2(MEM_TRACER_ALL : tMemGens) return tPort2_array;
  function getPorts2(MESSAGE_TRACER_ALL : tMessageGens) return tPort2_array;

  function countPorts(INST_TRACER : tInstGen) return natural;
  function countPorts(MEM_TRACER : tMemGen) return natural;
  function countPorts(MESSAGE_TRACER : tMessageGen) return natural;

  function countPorts(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural;
  function countPortsNoDoublings(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural;
  function countPortsNoDoublings(INST_TRACER_ALL : tInstGens) return natural;
  function countPortsNoDoublings(MEM_TRACER_ALL : tMemGens) return natural;
  function countPortsNoDoublings(MESSAGE_TRACER_ALL : tMessageGens) return natural;
  function countPorts(INST_TRACER_ALL : tInstGens) return natural;
  function countPorts(MEM_TRACER_ALL : tMemGens) return natural;
  function countPorts(MESSAGE_TRACER_ALL : tMessageGens) return natural;

  function removeNullValues(INST_TRACER_ALL : tInstGens) return tInstGens;
  function removeNullValues(MEM_TRACER_ALL : tMemGens) return tMemGens;
  function removeNullValues(MESSAGE_TRACER_ALL : tMessageGens) return tMessageGens;

  function countTrigger(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural;
  function countTrigger(INST_TRACER_ALL : tInstGens) return natural;
  function countTrigger(MEM_TRACER_ALL : tMemGens) return natural;
  function countTrigger(MESSAGE_TRACER_ALL : tMessageGens) return natural;

  function getTriggerIds(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tNat_array;
  function getTriggerIds(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens; INDEX : natural) return tNat_array;
  function getTriggerIdsNoDoublings(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tNat_array;
  function getTriggerIds(INST_TRACER_ALL : tInstGens) return tNat_array;
  function getTriggerIds(MEM_TRACER_ALL : tMemGens) return tNat_array;
  function getTriggerIds(MESSAGE_TRACER_ALL : tMessageGens) return tNat_array;

  function getPriorities(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tPrio_array;

  function getTracerDataOutBits(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens;
                                TIME_BITS : natural; PRIORITIES : tPrio_array) return tNat_array;
  function getTracerDataOutBits(OUT_BITS : positive; COMPRESSION : boolean; TIME_BITS : natural) return positive;

  function getTracerGlobalIndex(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens;
                                MESSAGE_TRACER_ALL : tMessageGens; GEN : natural; INPUTS : natural) return natural;

  --------------------------
  -- Controller-Functions --
  --------------------------
  function getConfig(PORTS : tPorts; INST_TRACER : tInstGens; MEM_TRACER : tMemGens; MESSAGE_TRACER : tMessageGens;
                     SINGLE_EVENTS : tSingleEvent_array; TRIGGER_ARRAY : tTrigger_array; ICE_REGISTERS : tNat_array;
                     TIME_BITS : positive; TRIGGER_INFORM : boolean; CYCLE_ACCURATE : boolean) return tSlv8_array;
  function getConfigCnt(PORTS : tPorts; INST_TRACER : tInstGens; MEM_TRACER : tMemGens; MESSAGE_TRACER : tMessageGens;
                        SINGLE_EVENTS : tSingleEvent_array; TRIGGER_ARRAY : tTrigger_array; ICE_REGISTERS : tNat_array;
                        TIME_BITS : positive; TRIGGER_INFORM : boolean; CYCLE_ACCURATE : boolean) return natural;

  ---------------------------------------
  -- General Tracer-Functions (intern) --
  ---------------------------------------

  function getTracerHeaderBits(MSG_PORT : tPort) return positive;
  function sumTracerHeaderBits(MSG_PORTS : tPorts) return positive;
  function sumTracerHeaderBytes(MSG_PORTS : tPorts) return positive;
  function getTracerHeaderLenBits(MSG_PORT : tPort) return natural;
  function sumTracerHeaderLenBits(MSG_PORTS : tPorts) return natural;
  function getTracerHeaderValBits(MSG_PORT : tPort) return natural;
  function sumTracerHeaderValBits(MSG_PORTS : tPorts) return natural;
  function getTracerVarValBytes(MSG_PORT : tPort) return natural;
  function sumTracerVarValBytes(MSG_PORTS : tPorts) return natural;
  function sumTracerVarValBytes(MSG_PORTS : tPorts; INDEX : natural) return natural;
  function haveCompression(MSG_PORT : tPort) return boolean;
  function haveCompression(MSG_PORTS : tPorts) return boolean;
  function getCompressionCnt(MSG_PORTS : tPorts) return natural;
  function getMaxBitsWithCompression(MSG_PORTS : tPorts) return natural;

  ------------------------------------
  -- Inst-Tracer-Functions (intern) --
  ------------------------------------

  function getInstDataOutBits(ADR_PORT : tPort; BRANCH_INFO : boolean; COUNTER_BITS : positive; HISTORY_BYTES : natural;
                              CODING_BITS : natural; TIME_BITS : natural) return positive;

  -----------------------------------
  -- Mem-Tracer-Functions (intern) --
  -----------------------------------

  function getMemDataOutBits(ADR_PORTS : tPorts; DATA_PORT : tPort; SOURCE_BITS : natural; CODING_BITS : natural;
                             TIME_BITS : natural) return positive;

  ---------------------------------------
  -- Message-Tracer-Functions (intern) --
  ---------------------------------------

  function getMessageMinMessages(MESSAGES : positive; AVG_COMP_RATIO : tRatio; MIN_MEMORY : boolean; VAR_VAL_BYTES : natural) return positive;
  function getMessageDataOutBits(MSG_PORTS : tPorts; CODING_BITS : natural; TIME_BITS : natural) return positive;
  function sumMessageCompLenBits(MSG_PORTS : tPorts; INDEX : natural) return natural;
  function sumMessageCompLenMarkBits(MSG_PORTS : tPorts; INDEX : natural) return natural;
  function sumMessageCompOutBits(MSG_PORTS : tPorts; INDEX : natural) return natural;
  function getMessageVarValValid(MSG_PORTS : tPorts; INDEX : natural; DATA_VALID_BITS : positive) return unsigned;
  function haveMessageResync(MESSAGE_TRACER_ALL : tMessageGens) return boolean;

  -----------------------
  -- Trigger-Functions --
  -----------------------

  function removeNullValues(TRIGGER_ARRAY : tTrigger_array) return tTrigger_array;
  function removeNullValues(SINGLE_EVENTS : tSingleEvent_array) return tSingleEvent_array;
  function removeNullValues(COMPLEX_EVENTS : tComplexEvent_array) return tComplexEvent_array;

  function noDoubleId(SINGLE_EVENTS : tSingleEvent_array) return boolean;
  function noDoubleId(TRIGGER_ARRAY : tTrigger_array) return boolean;
  function isNullSingleEvent(SINGLE_EVENT : tSingleEvent) return boolean;
  function isNullComplexEvent(COMPLEX_EVENT : tNat_array) return boolean;
  function isNullTrigger(TRIGGER : tTrigger) return boolean;
  function countSingleEvents(SINGLE_EVENTS : tSingleEvent_array) return natural;
  function countSingleEvents(SINGLE_EVENTS : tSingleEvent_array; INDEX : natural) return natural;
  function countSingleEvents(SINGLE_EVENT_IDS : tNat_array) return natural;
  function countSingleEvents(TRIGGER_ARRAY : tTrigger_array) return natural;
  function countSingleEvents(TRIGGER : tTrigger) return natural;
  function countSingleEventsNoDoublings(TRIGGER : tTrigger) return natural;
  function countComplexEvents(COMPLEX_EVENTS : tComplexEvent_array) return natural;
  function countComplexEventsNoDoublings(TRIGGER_ARRAY : tTrigger_array) return natural;
  function countTriggerNoDoublings(TRIGGER_ARRAY : tTrigger_array) return natural;
  function countTrigger(TRIGGER_ARRAY : tTrigger_array) return natural;
  function containsSingleEvent(SINGLE_EVENTS : tSingleEvent_array; ID : natural) return boolean;
  function containsSingleEvent(SINGLE_EVENTS : tSingleEvent_array; ID : natural; INDEX : natural) return boolean;
  function containsSingleEvent(TRIGGER_ARRAY : tTrigger_array; ID : natural; INDEX : natural) return boolean;
  function containsSingleEvent(COMPLEX_EVENTS : tComplexEvent_array; ID : natural; INDEX : natural) return boolean;
  function containsSingleEvent(COMPLEX_EVENTS : tComplexEvent_array; ID : natural) return boolean;
  function containsComplexEvent(COMPLEX_EVENTS : tComplexEvent_array; COMPLEX_EVENT : tNat_array) return boolean;
  function containsComplexEvent(COMPLEX_EVENTS : tComplexEvent_array; COMPLEX_EVENT : tNat_array; INDEX : natural) return boolean;
  function containsComplexEvent(TRIGGER_ARRAY : tTrigger_array; COMPLEX_EVENT : tNat_array; INDEX : natural) return boolean;
  function containsPort(SINGLE_EVENTS : tSingleEvent_array; ID : natural) return boolean;
  function containsPort(SINGLE_EVENTS : tSingleEvent_array; ID : natural; INDEX : natural) return boolean;
  function containsTrigger(TRIGGER_ARRAY : tTrigger_array; ID : natural) return boolean;
  function containsTrigger(TRIGGER_ARRAY : tTrigger_array; ID : natural; INDEX : natural) return boolean;
  function getSingleEventIds(TRIGGER_ARRAY : tTrigger_array) return tNat_array;
  function getSingleEventIdsNoDoublings(TRIGGER_ARRAY : tTrigger_array) return tNat_array;
  function getSingleEventIds(TRIGGER : tTrigger) return tNat_array;
  function getSingleEventIdsNoDoublings(TRIGGER : tTrigger) return tNat_array;
  function getSingleEvent(SINGLE_EVENTS : tSingleEvent_array; ID : natural) return tSingleEvent;
  function getSingleEvents(SINGLE_EVENTS : tSingleEvent_array; IDS : tNat_array) return tSingleEvent_array;
  function getSingleEventsInitialRegs(SINGLE_EVENTS : tSingleEvent_array) return std_logic_vector;
  function sumSingleEventsRegWidths(SINGLE_EVENTS : tSingleEvent_array) return natural;
  function sumSingleEventsPortBits(SINGLE_EVENTS : tSingleEvent_array) return natural;
  function sumSingleEventsPortBits(SINGLE_EVENTS : tSingleEvent_array; INDEX : natural) return natural;
  function getSingleEventLevel(SINGLE_EVENT : tSingleEvent) return natural;
  function sumSingleEventsLevel(SINGLE_EVENTS : tSingleEvent_array) return natural;
  function sumSingleEventsLevel(SINGLE_EVENTS : tSingleEvent_array; INDEX : natural) return natural;
  function getSingleEventIndex(SINGLE_EVENTS : tSingleEvent_array; ID : natural) return natural;
  function getSingleEventsPorts(SINGLE_EVENTS : tSingleEvent_array) return tPorts;
  function getSingleEventsRegBits(SINGLE_EVENTS : tSingleEvent_array) return tNat_array;
  function getSingleEventsRegMaxBits(SINGLE_EVENTS : tSingleEvent_array) return natural;
  function getMaxSingleEventOutputWidth(SINGLE_EVENTS : tSingleEvent_array) return natural;
  function getComplexEventsNoDoublings(TRIGGER_ARRAY : tTrigger_array) return tComplexEvent_array;
  function getComplexEventLevel(COMPLEX_EVENT : tNat_array; SINGLE_EVENTS : tSingleEvent_array) return natural;
  function sumComplexEventsLevel(COMPLEX_EVENTS : tComplexEvent_array; SINGLE_EVENTS : tSingleEvent_array) return natural;
  function sumComplexEventsLevel(COMPLEX_EVENTS : tComplexEvent_array; SINGLE_EVENTS : tSingleEvent_array; INDEX : natural) return natural;
  function getComplexEventIndex(COMPLEX_EVENTS : tComplexEvent_array; COMPLEX_EVENT : tNat_array) return natural;
  function complexEventsEqual(V1 : tNat_array; V2 : tNat_array) return boolean;
  function getTrigger(TRIGGER_ARRAY : tTrigger_array; ID : natural) return tTrigger;
  function getTrigger(TRIGGER_ARRAY : tTrigger_array; IDS : tNat_array) return tTrigger_array;
  function getTriggerIndex(TRIGGER_ARRAY : tTrigger_array; ID : natural) return natural;
  function getTriggerEvents(TRIGGER : tTrigger) return natural;
  function getTriggerMaxEvents(TRIGGER_ARRAY : tTrigger_array) return natural;
  function getTriggerLevel(TRIGGER : tTrigger; SINGLE_EVENTS : tSingleEvent_array) return natural;
  function sumTriggerOutBits(TRIGGER_ARRAY : tTrigger_array; SINGLE_EVENTS : tSingleEvent_array) return natural;
  function sumTriggerOutBits(TRIGGER_ARRAY : tTrigger_array; SINGLE_EVENTS : tSingleEvent_array; INDEX : natural) return natural;
  function sumTriggerOutBits(TRIGGER_ARRAY : tTrigger_array; SINGLE_EVENTS : tSingleEvent_array; TRIGGER : tTrigger) return natural;

  ----------------------
  -- Coding-Functions --
  ----------------------

  function getCodeCoding(PRIOARRAY : tPrio_array; I : natural) return std_logic_vector;
  function getCodeStartCodingLength(PRIOARRAY : tPrio_array; I : natural) return natural;
  function getCodeSingleCodingLength(PRIOARRAY : tPrio_array; I : natural) return positive;
  function getCodeAllPrioEqual(PRIOARRAY : tPrio_array) return boolean;
  function getCodeEqualPriorityCnt(PRIOARRAY : tPrio_array; I : tPrio) return natural;
  function getCodeHigherPriorityGroupCnt(PRIOARRAY : tPrio_array; PRIO : tPrio) return natural;
  function getCodeHaveEqualCoding(PRIOARRAY : tPrio_array; I : tPrio) return boolean;
  function getCodeLowestPriority(PRIOARRAY : tPrio_array) return natural;
  function getCodeEqualPriorityLowerInListCnt(PRIOARRAY : tPrio_array; INDEX : natural) return natural;

  ---------------------
  -- Other Functions --
  ---------------------

  function notZero(V : natural) return positive;

  function getByte(INPUT : std_logic_vector; INDEX : natural) return std_logic_vector;
  function getBytesUp(BITS : natural) return natural;  -- get Bytes with last incomplete bits
  function getBytesUp(BITS : tNat_array) return tNat_array;
  function getBytesDown(BITS : natural) return natural; -- get Bytes without last-one

  function minValue(V1 : positive; V2 : positive) return positive;
  function max(NATARRAY : tNat_array) return natural;
  function max(POSARRAY : tPos_array) return positive;
  function max(V1 : natural; V2 : natural) return natural;
  function max(V1 : natural; V2 : natural; V3 : natural) return natural;
  function max(V1 : natural; V2 : natural; V3 : natural; V4 : natural) return natural;

  function sum(POSARRAY : tPos_array) return positive;
  function sum(NATARRAY : tNat_array) return natural;
  function sum(POSARRAY : tPos_array; I : natural) return positive;
  function sum(NATARRAY : tNat_array; I : natural) return natural;
  function sumSubsequent(LEFT : natural; RIGHT : natural) return natural;
  function sumLog2CeilPlusOne(POSARRAY : tPos_array) return positive;

  function concat(V1 : tNat_array; V2 : tNat_array) return tNat_array;

  function divideValuesReturnNZ(V1 : natural; V2 : positive) return positive;
  function divideRoundUp(V1 : natural; V2 : positive) return natural;
  function containsValue(NATARRAY : tNat_array; VAL : natural) return boolean;
  function containsValue(NATARRAY : tNat_array; VAL : natural; INDEX: natural) return boolean;
  function countValues(NATARRAY : tNat_array; VAL : natural) return natural;
  function countValuesGreaterThan(NATARRAY : tNat_array; VAL : natural) return natural;
  function countValuesGreaterThan(NATARRAY : tNat_array; INDEX : natural; VAL : natural) return natural;
  function countValuesGreaterThanNoDoublings(NATARRAY : tNat_array; VAL : natural) return natural;
  function countValuesExclude(NATARRAY : tNat_array; VAL : natural) return natural;
  function getValueFilterNotZero(NATARRAY : tNat_array; INDEX : natural) return positive;
  function getValuesGreaterThan(NATARRAY : tNat_array; VAL : natural) return tNat_array;
  function getValuesNoDoublings(NATARRAY : tNat_array) return tNat_array;
  function removeValue(NATARRAY : tNat_array; VAL : natural) return tNat_array;
  function sort(NATARRAY : tNat_array) return tNat_array;
  function countGroups(NATARRAY : tNat_array) return natural;
  function getGroup(NATARRAY : tNat_array; INDEX : natural) return natural;
  function sumGroups(NATARRAY : tNat_array; INDEX : natural) return natural;
  function indexOf(NATARRAY : tNat_array; VALUE : natural) return natural;
  function indexOf(NATARRAY : tNat_array; VALUE : natural; I : natural) return natural;

  function ifThenElse(COND : boolean; V1 : boolean; V2 : boolean) return boolean;
  function ifThenElse(COND : boolean; V1 : integer; V2 : integer) return integer;
  function ifThenElse(COND : boolean; V1 : std_logic_vector; V2 : std_logic_vector) return std_logic_vector;
  function ifThenElse(COND : boolean; V1 : std_logic; V2 : std_logic) return std_logic;
  function ifThenElse(COND : boolean; V1 : unsigned; V2 : unsigned) return unsigned;
  function ifThenElse(COND : boolean; V1 : tNat_array; V2 : tNat_array) return tNat_array;
  function ifThenElse(COND : boolean; V1 : tPort; V2 : tPort) return tPort;
  function ifThenElse(COND : boolean; V1 : tPort2_array; V2 : tPort2_array) return tPort2_array;
  function ifThenElse(COND : boolean; V1 : tTriggerMode_array; V2 : tTriggerMode_array) return tTriggerMode_array;
  function ifThenElse(COND : boolean; V1 : tTriggerType_array; V2 : tTriggerType_array) return tTriggerType_array;
  function ifThenElse(COND : boolean; V1 : tOvDangerReaction; V2 : tOvDangerReaction) return tOvDangerReaction;

  function log2ceilnz(arg : tNat_array) return tNat_array;

  function getFirstBitSet(INPUT : std_logic_vector) return natural;
  function getLastBitSet(INPUT : std_logic_vector) return natural;

  function countBlocksSet(INPUT : std_logic_vector; BLOCKSIZE : positive) return natural;
  function countBitsSet(INPUT : std_logic_vector) return natural;

  function fillOrCut(INPUT : unsigned; SIZE : positive) return unsigned;
  function fillOrCut(INPUT : std_logic_vector; SIZE : positive) return std_logic_vector;
  function fill(INPUT : unsigned; SIZE : positive) return unsigned;
  function fill(INPUT : std_logic_vector; SIZE : positive) return std_logic_vector;
  function fillLSB(INPUT : std_logic_vector; SIZE : positive) return std_logic_vector;
  function fill(INPUT : tPorts; SIZE : positive) return tPorts;
  function fill(INPUT : tTrigger_array; SIZE : positive) return tTrigger_array;
  function fill(INPUT : tSingleEvent_array; SIZE : positive) return tSingleEvent_array;
  function fill(INPUT : tSingleEvent; SIZE : positive) return tSingleEvent_array;
  function fill(INPUT : tComplexEvent_array; SIZE : positive) return tComplexEvent_array;
  function fill(INPUT : tNat_array; SIZE : positive) return tNat_array;

  function cut(INPUT : unsigned; SIZE : positive) return unsigned;
  function cut(INPUT : std_logic_vector; SIZE : positive) return std_logic_vector;

  function merge(V1 : tPorts; V2 : tPorts) return tPorts;
  function mergeNoDoublings(V1 : tPorts; V2 : tPorts) return tPorts;
  function merge(V1 : tPorts; V2 : tPorts; V3 : tPorts; V4 : tPorts; V5 : tPorts; V6 : tPorts; V7 : tPorts;
                  V8 : tPorts) return tPorts;
  function merge(V1 : tTrigger_array; V2 : tTrigger_array) return tTrigger_array;

  function append(A : tMessageGens; V : tMessageGen ) return tMessageGens;
  function append(A : tPorts; V : tPort) return tPorts;
  function append(A : tTrigger_array; V : tTrigger) return tTrigger_array;

  function appendFirst(A : tPorts; V : tPort) return tPorts;
  function appendFirst(A : tMessageGens; V : tMessageGen) return tMessageGens;

  function slv8ToSlv16(INPUT : tSlv8_array) return tSlv16_array;

  --------------------
  -- Enum-Functions --
  --------------------

  function getEnumIndex(V : tComp) return natural;
  function getEnumIndex(V : tTriggerCmp1) return natural;
  function getEnumIndex(V : tTriggerCmp2) return natural;
  function getEnumIndex(V : tTriggerType) return natural;
  function getEnumIndex(V : tTriggerMode) return natural;

  function getTriggerCmp1Value(INDEX : natural) return tTriggerCmp1;
  function getTriggerCmp2Value(INDEX : natural) return tTriggerCmp2;
  function getTriggerTypeValue(INDEX : natural) return tTriggerType;
  function getTriggerModeValue(INDEX : natural) return tTriggerMode;

  ----------------------
  -- Print-procedures --
  ----------------------

  procedure print(P : in tPort);
  procedure print(PORTS : in tPorts);
  procedure print(PORTS : in tPort2_array);
  procedure print(INST_TRACER : in tInstGen);
  procedure print(INST_TRACER_ALL : in tInstGens);
  procedure print(MEM_TRACER : in tMemGen);
  procedure print(MEM_TRACER_ALL : in tMemGens);
  procedure print(MESSAGE_TRACER : in tMessageGen);
  procedure print(MESSAGE_TRACER_ALL : in tMessageGens);
  procedure print(NAT_ARRAY : in tNat_array);
  procedure print(PRIO_ARRAY : in tPrio_array);
  procedure print(INPUT : in tSlv8_array);
  procedure print(INPUT : in tSlv16_array);
  procedure print(TRIGGER_ARRAY : in tTrigger_array);
  procedure print(TRIGGER : in tTrigger);
  procedure print(COMPLEX_EVENTS : in tComplexEvent_array);
  procedure print(SINGLE_EVENTS : in tSingleEvent_array);
  procedure print(SINGLE_EVENT : in tSingleEvent);


end trace_functions;

package body trace_functions is

  --------------------
  -- Port-Functions --
  --------------------

  function isNullPort(P : tPort) return boolean is
  begin
    return (P.ID = NULL_PORT.ID);
  end function isNullPort;

  function containsValidPort(PORTS : tPorts) return boolean is
    variable result : boolean := false;
  begin
    for i in 0 to PORTS'length-1 loop
      if not isNullPort(PORTS(i)) then
        result := true;
      end if;
    end loop;
    return result;
  end function containsValidPort;

  function containsPort(PORTS : tPorts; ID : natural) return boolean is
  begin
    for i in 0 to PORTS'length-1 loop
      if not isNullPort(PORTS(i)) then
        if PORTS(i).ID = ID then
          return true;
        end if;
      end if;
    end loop;
    return false;
  end function containsPort;

  function containsPort(PORTS : tPorts; ID : natural; INDEX : natural) return boolean is
    variable result : boolean := false;
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        if not isNullPort(PORTS(i)) then
          if PORTS(i).ID = ID then
            return true;
          end if;
        end if;
      end loop;
    end if;
    return false;
  end function containsPort;

  function countPorts(PORTS : tPorts) return natural is
    variable result : natural := 0;
  begin
    --report "countPorts tPorts parameter";
    --print(PORTS);
    for i in 0 to PORTS'length-1 loop
      if not isNullPort(PORTS(i)) then
        result := result + 1;
      end if;
    end loop;

    --report "countPorts result "&integer'image(result);
    return result;
  end function countPorts;

  function countPortsNoDoublings(PORTS : tPorts) return natural is
    variable result : natural := 0;
  begin

    --report "countPortsNoDoublings tPorts parameter";
    --print (PORTS);

    for i in 0 to PORTS'length-1 loop
      if not isNullPort(PORTS(i)) then
        if not containsPort(PORTS, PORTS(i).ID, i) then
          result := result + 1;
        end if;
      end if;
    end loop;

    --report "countPortsNoDoublings result "&integer'image(result);

    return result;
  end function countPortsNoDoublings;

  function countPorts(PORTS : tPort2_array) return natural is
    variable result : natural := 0;
  begin

    --report "countPorts tPort2_array parameter";
    --print(PORTS);

    for i in 0 to PORTS'length-1 loop
      result := result + countPorts(PORTS(i));
    end loop;

    --report "countPorts tPort2_array result "&integer'image(result);

    return result;
  end function countPorts;

  function countPorts(PORTS : tPort2_array; INDEX : natural) return natural is
    variable result : natural := 0;
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        result := result + countPorts(PORTS(i));
      end loop;
    end if;
    return result;
  end function countPorts;

  function getMaxPortWidth(PORTS : tPorts) return positive is
    variable result : natural := 0;
  begin
    for i in 0 to countPorts(PORTS)-1 loop
      if PORTS(i).WIDTH > result then
        result := PORTS(i).WIDTH;
      end if;
    end loop;
    return notZero(result);
  end function getMaxPortWidth;

  function getMinPortInputs(PORTS : tPorts) return natural is
    variable result : natural := positive'high;
  begin
    if not containsValidPort(PORTS) then
      return 0;
    end if;

    for i in 0 to countPorts(PORTS)-1 loop
      if PORTS(i).INPUTS < result then
        result := PORTS(i).INPUTS;
      end if;
    end loop;
    return result;
  end function getMinPortInputs;

  function getMaxPortInputs(PORTS : tPorts) return natural is
    variable result : natural := 0;
  begin
    for i in 0 to countPorts(PORTS)-1 loop
      if PORTS(i).INPUTS > result then
        result := PORTS(i).INPUTS;
      end if;
    end loop;
    return result;
  end function getMaxPortInputs;

  function getMaxPortId(PORTS : tPorts) return natural is
    variable result : natural := 0;
  begin
    for i in 0 to countPorts(PORTS)-1 loop
      if PORTS(i).ID > result then
        result := PORTS(i).ID;
      end if;
    end loop;
    return result;
  end function getMaxPortId;

  function equalInputs(PORTS : tPorts) return boolean is
    variable val : natural;
  begin
    assert containsValidPort(PORTS) severity error;

    val := getMinPortInputs(PORTS);
    for i in 0 to countPorts(PORTS)-1 loop
      if PORTS(i).INPUTS /= val then
        return false;
      end if;
    end loop;
    return true;
  end function equalInputs;

  function calculateValueBits(PORTS : tPorts) return natural is
  begin
    return calculateValueBits(PORTS, countPorts(PORTS));
  end function calculateValueBits;

  function calculateValueBits(PORTS : tPorts; INDEX : natural) return natural is
    variable cnt : natural := 0;
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        cnt := cnt + PORTS(i).INPUTS*PORTS(i).WIDTH;
      end loop;
    end if;
    return cnt;
  end function calculateValueBits;

  function calculateStbBits(PORTS : tPorts) return natural is
  begin
    return calculateStbBits(PORTS, countPorts(PORTS));
  end function calculateStbBits;

  function calculateStbBits(PORTS : tPorts; INDEX : natural) return natural is
    variable cnt : natural := 0;
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        cnt := cnt + PORTS(i).INPUTS;
      end loop;
    end if;
    return cnt;
  end function calculateStbBits;

  function getMaxPortsPerTracerWithNp(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural is
    variable result : natural := 0;
    variable cnt_tmp : natural := 0;
  begin
    for i in 0 to countTracer(INST_TRACER_ALL)-1 loop
      cnt_tmp := 3;
      if cnt_tmp > result then
        result := cnt_tmp;
      end if;
    end loop;
    for i in 0 to countTracer(MEM_TRACER_ALL)-1 loop
      cnt_tmp := MEM_TRACER_ALL(i).ADR_PORTS'length+3;
      if cnt_tmp > result then
        result := cnt_tmp;
      end if;
    end loop;
    for i in 0 to countTracer(MESSAGE_TRACER_ALL)-1 loop
      cnt_tmp := MESSAGE_TRACER_ALL(i).MSG_PORTS'length;
      if cnt_tmp > result then
        result := cnt_tmp;
      end if;
    end loop;
    return result;
  end function getMaxPortsPerTracerWithNp;

  function noDoubleId(PORTS : tPorts) return boolean is
  begin
    --report "noDoubleId tPorts parameter";
    --print(PORTS);
    for i in 0 to countPorts(PORTS)-1 loop
      if containsPort(PORTS, PORTS(i).ID, i) then
        return false;
      end if;
    end loop;
    return true;
  end function noDoubleId;

  function sumWidths(PORTS : tPorts) return natural is
  begin
    return sumWidths(PORTS, countPorts(PORTS));
  end function sumWidths;

  function sumWidths(PORTS : tPorts; INDEX : natural) return natural is
    variable cnt : natural := 0;
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        cnt := cnt + PORTS(i).WIDTH;
      end loop;
    end if;
    return cnt;
  end function sumWidths;

  function getNewId(PORTS : tPorts) return positive is
    variable maxId : natural := 0;
  begin

    --report "getNewId parameter";
    --print(PORTS);

    for i in 0 to countPorts(PORTS)-1 loop
      maxId := max(maxId, PORTS(i).ID);
    end loop;
    return maxId+1;
  end function getNewId;

  function removeDoublings(PORTS : tPorts) return tPorts is
    variable result : tPorts(0 to max(countPortsNoDoublings(PORTS),2)-1) := (others => NULL_PORT);
    variable index  : natural := 0;
  begin

    --report "removeDoublings tPorts parameter";
    --print(PORTS);

    -- remove doubling

    for i in 0 to PORTS'length-1 loop
      if not isNullPort(PORTS(i)) then
        if not containsPort(result, PORTS(i).ID) then
          result(index) := PORTS(i);
          index         := index + 1;
        end if;
      end if;
    end loop;

    --report "removeDoublings tPorts result";
    --print(result);

    return result;

  end function removeDoublings;

  function removeNullValues(PORTS : tPorts) return tPorts is
    variable result : tPorts(0 to max(countPorts(PORTS),2)-1) := (others => NULL_PORT);
    variable index  : natural := 0;
  begin

    --report "removeNullValues tPorts parameter";
    --print(PORTS);

    -- when there's only one valid port, the array is filled with null-ports, but they are stored at the end

    for i in 0 to PORTS'length-1 loop
      if not isNullPort(PORTS(i)) then
        result(index) := PORTS(i);
        index         := index + 1;
      end if;
    end loop;

    --report "removeNullValues tPorts result";
    --print(result);

    return result;

  end function removeNullValues;

  ----------------------
  -- Tracer-Functions --
  ----------------------

  function isNullTracer(INST_TRACER : tInstGen) return boolean is
  begin
    return isNullPort(INST_TRACER.ADR_PORT) or not INST_TRACER.INSTANTIATE;
  end function isNullTracer;

  function isNullTracer(MEM_TRACER : tMemGen) return boolean is
    variable result : boolean := false;
  begin
    if not MEM_TRACER.INSTANTIATE then
      result := true;
    end if;
    if not containsValidPort(MEM_TRACER.ADR_PORTS) then
      result := true;
    end if;
    if isNullPort(MEM_TRACER.DATA_PORT) then
      result := true;
    end if;
    if isNullPort(MEM_TRACER.RW_PORT) then
      result := true;
    end if;
    return result;
  end function isNullTracer;

  function isNullTracer(MESSAGE_TRACER : tMessageGen) return boolean is
  begin
    return not containsValidPort(MESSAGE_TRACER.MSG_PORTS) or not MESSAGE_TRACER.INSTANTIATE;
  end function isNullTracer;

  -- Count tracer

  function countTracer(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural is
    variable cnt : natural := 0;
  begin

    --report "countTracer tInstGens tMemGens tMessageGens paramter";
    --print(INST_TRACER_ALL);
    --print(MEM_TRACER_ALL);
    --print(MESSAGE_TRACER_ALL);

    cnt := cnt + countTracer(INST_TRACER_ALL);
    cnt := cnt + countTracer(MEM_TRACER_ALL);
    cnt := cnt + countTracer(MESSAGE_TRACER_ALL);

    --report "countTracer result "&integer'image(cnt);

    return cnt;
  end function countTracer;

  function countTracer(INST_TRACER_ALL : tInstGens) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to INST_TRACER_ALL'length-1 loop
      if not isNullTracer(INST_TRACER_ALL(i)) then
        cnt := cnt + getInputs(INST_TRACER_ALL(i));
      end if;
    end loop;
    return cnt;
  end function countTracer;

  function countTracer(INST_TRACER_ALL : tInstGens; INDEX : natural) return natural is
    variable cnt : natural := 0;
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        if not isNullTracer(INST_TRACER_ALL(i)) then
          cnt := cnt + getInputs(INST_TRACER_ALL(i));
        end if;
      end loop;
    end if;
    return cnt;
  end function countTracer;

  function countTracerGens(INST_TRACER_ALL : tInstGens) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to INST_TRACER_ALL'length-1 loop
      if not isNullTracer(INST_TRACER_ALL(i)) then
        cnt := cnt + 1;
      end if;
    end loop;

    --report "countTracerGens tInstGens result "&integer'image(cnt);

    return cnt;
  end function countTracerGens;

  function countTracer(MEM_TRACER_ALL : tMemGens) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to MEM_TRACER_ALL'length-1 loop
      if not isNullTracer(MEM_TRACER_ALL(i)) then
        cnt := cnt + getInputs(MEM_TRACER_ALL(i));
      end if;
    end loop;
    return cnt;
  end function countTracer;

  function countTracer(MEM_TRACER_ALL : tMemGens; INDEX : natural) return natural is
    variable cnt : natural := 0;
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        if not isNullTracer(MEM_TRACER_ALL(i)) then
          cnt := cnt +getInputs(MEM_TRACER_ALL(i));
        end if;
      end loop;
    end if;
    return cnt;
  end function countTracer;

  function countTracerGens(MEM_TRACER_ALL : tMemGens) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to MEM_TRACER_ALL'length-1 loop
      if not isNullTracer(MEM_TRACER_ALL(i)) then
        cnt := cnt + 1;
      end if;
    end loop;
    return cnt;
  end function countTracerGens;

  function countTracer(MESSAGE_TRACER_ALL : tMessageGens) return natural is
    variable cnt : natural := 0;
  begin

    --report "countTracer tMessageGens parameter";
    --print(MESSAGE_TRACER_ALL);

    for i in 0 to MESSAGE_TRACER_ALL'length-1 loop
      if not isNullTracer(MESSAGE_TRACER_ALL(i)) then
        cnt := cnt + getInputs(MESSAGE_TRACER_ALL(i));
      end if;
    end loop;

    --report "countTracer tMessageGens result " & integer'image(cnt);

    return cnt;

  end function countTracer;

  function countTracer(MESSAGE_TRACER_ALL : tMessageGens; INDEX : natural) return natural is
    variable cnt : natural := 0;
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        if not isNullTracer(MESSAGE_TRACER_ALL(i)) then
          cnt := cnt + getInputs(MESSAGE_TRACER_ALL(i));
        end if;
      end loop;
    end if;
    return cnt;
  end function countTracer;

  function countTracerGens(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural is
    variable cnt : natural := 0;
  begin

    --report "countTracerGens tInstGens tMemGens tMessageGens parameter";
    --print(INST_TRACER_ALL);
    --print(MEM_TRACER_ALL);
    --print(MESSAGE_TRACER_ALL);

    cnt := cnt + countTracerGens(INST_TRACER_ALL);
    cnt := cnt + countTracerGens(MEM_TRACER_ALL);
    cnt := cnt + countTracerGens(MESSAGE_TRACER_ALL);

    --report "countTracerGens result "&integer'image(cnt);

    return cnt;
  end function countTracerGens;

  function countTracerGens(MESSAGE_TRACER_ALL : tMessageGens) return natural is
    variable cnt : natural := 0;
  begin

    --report "countTracerGens tMessageGens parameter";
    --print(MESSAGE_TRACER_ALL);

    for i in 0 to MESSAGE_TRACER_ALL'length-1 loop
      if not isNullTracer(MESSAGE_TRACER_ALL(i)) then
        cnt := cnt + 1;
      end if;
    end loop;

    --report "countTracerGens result "&integer'image(cnt);

    return cnt;
  end function countTracerGens;

  -- get inputs per single tracer

  function getInputs(INST_TRACER : tInstGen) return natural is
    variable result : natural;
  begin
    result := INST_TRACER.ADR_PORT.INPUTS;
    --report "getInputs tInstGen result "&integer'image(result);
    return result;
  end function getInputs;

  function getInputs(MEM_TRACER : tMemGen) return natural is
    variable result : natural;
  begin
    result := MEM_TRACER.DATA_PORT.INPUTS;
    --report "getInputs tInstGen result "&integer'image(result);
    return result;
  end function getInputs;

  function getInputs(MESSAGE_TRACER : tMessageGen) return natural is
    variable result : natural;
  begin
    result := MESSAGE_TRACER.MSG_PORTS(0).INPUTS;
    --report "getInputs tInstGen result "&integer'image(result);
    return result;
  end function getInputs;

  function getInputs(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens;
                     MESSAGE_TRACER_ALL : tMessageGens; INDEX : natural) return natural is
    constant INST_TRACER_GEN_CNT    : natural := countTracerGens(INST_TRACER_ALL);
    constant MEM_TRACER_GEN_CNT     : natural := countTracerGens(MEM_TRACER_ALL);
    constant MESSAGE_TRACER_GEN_CNT : natural := countTracerGens(MESSAGE_TRACER_ALL);
  begin
    --report "getInputs tInstGens tMemGens tMessageGens parameter";
    --report "INDEX "&integer'image(INDEX);
    if INDEX < INST_TRACER_GEN_CNT then
      return getInputs(INST_TRACER_ALL(INDEX));
    end if;

    if INDEX < INST_TRACER_GEN_CNT+MEM_TRACER_GEN_CNT then
      return getInputs(MEM_TRACER_ALL(INDEX-INST_TRACER_GEN_CNT));
    end if;

    if INDEX < INST_TRACER_GEN_CNT+MEM_TRACER_GEN_CNT+MESSAGE_TRACER_GEN_CNT then
      return getInputs(MESSAGE_TRACER_ALL(INDEX-INST_TRACER_GEN_CNT-MEM_TRACER_GEN_CNT));
    end if;

    assert false severity error;
    return 0;
  end function getInputs;

  -- get ports per single tracer

  function getPorts(INST_TRACER : tInstGen) return tPorts is
    variable result : tPorts(0 to MAX_PORTS_PER_TRACER-1) := (others => NULL_PORT);
    variable index  : natural := 0;
  begin

    --report "getPorts tInstGen parameter";
    --print(INST_TRACER);

    if isNullTracer(INST_TRACER) then
      return result;
    end if;

    result(index) := INST_TRACER.ADR_PORT;
    index         := index + 1;

    if not isNullPort(INST_TRACER.BRANCH_PORT) then
      result(index) := INST_TRACER.BRANCH_PORT;
    end if;

    --report "getPorts result";
    --print(result);

    return result;

  end function getPorts;

  function getPorts(MEM_TRACER : tMemGen) return tPorts is
    variable result : tPorts(0 to MAX_PORTS_PER_TRACER-1) := (others => NULL_PORT);
    variable index  : natural := 0;
  begin

    if isNullTracer(MEM_TRACER) then
      return result;
    end if;

    for j in 0 to countPorts(MEM_TRACER.ADR_PORTS)-1 loop
      result(index) := MEM_TRACER.ADR_PORTS(j);
      index         := index + 1;
    end loop;
    result(index)   := MEM_TRACER.DATA_PORT;
    result(index+1) := MEM_TRACER.RW_PORT;
    result(index+2) := MEM_TRACER.SOURCE_PORT;

    return result;

  end function getPorts;

  function getPorts(MESSAGE_TRACER : tMessageGen) return tPorts is
    variable result : tPorts(0 to MAX_PORTS_PER_TRACER-1) := (others => NULL_PORT);
    variable index  : natural := 0;
  begin

    --report "getPorts tMessageGen parameter";
    --print(MESSAGE_TRACER);

    if isNullTracer(MESSAGE_TRACER) then
      return result;
    end if;

    for j in 0 to countPorts(MESSAGE_TRACER.MSG_PORTS)-1 loop
      result(index) := MESSAGE_TRACER.MSG_PORTS(j);
      index         := index + 1;
    end loop;

    --report "getPorts result";
    --print(result);

    return result;

  end function getPorts;

  -- get ports per tracer (with doubling)

  function getPorts(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tPorts is
    constant INST_PORTS    : natural := countPorts(INST_TRACER_ALL);
    constant MEM_PORTS     : natural := countPorts(MEM_TRACER_ALL);
    constant MESSAGE_PORTS : natural := countPorts(MESSAGE_TRACER_ALL);
    constant PORTS         : natural := INST_PORTS + MEM_PORTS + MESSAGE_PORTS;
    variable result   : tPorts(0 to max(2, PORTS)-1) := (others => NULL_PORT);
    variable index    : natural := 0;
  begin

    --report "getPorts tInstGens tMemGens tMessageGens parameter";
    --print(INST_TRACER_ALL);
    --print(MEM_TRACER_ALL);
    --print(MESSAGE_TRACER_ALL);

    if INST_PORTS > 0 then
      result(index to index+INST_PORTS-1) := getPorts(INST_TRACER_ALL)(0 to INST_PORTS-1);
      index := index + INST_PORTS;
    end if;

    if MEM_PORTS > 0 then
      result(index to index+MEM_PORTS-1) := getPorts(MEM_TRACER_ALL)(0 to MEM_PORTS-1);
      index := index + MEM_PORTS;
    end if;

    if MESSAGE_PORTS > 0 then
      result(index to index+MESSAGE_PORTS-1) := getPorts(MESSAGE_TRACER_ALL)(0 to MESSAGE_PORTS-1);
      index := index + MESSAGE_PORTS;
    end if;

    --report "getPorts result";
    --print(result);

    return result;

  end function getPorts;

  function getPortsNoDoublings(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tPorts is
    constant INST_PORT_CNT    : natural := countPorts(INST_TRACER_ALL);
    constant MEM_PORT_CNT     : natural := countPorts(MEM_TRACER_ALL);
    constant MESSAGE_PORT_CNT : natural := countPorts(MESSAGE_TRACER_ALL);
    constant INST_PORTS       : tPorts(0 to max(2, INST_PORT_CNT))    := getPorts(INST_TRACER_ALL);
    constant MEM_PORTS        : tPorts(0 to max(2, MEM_PORT_CNT))     := getPorts(MEM_TRACER_ALL);
    constant MESSAGE_PORTS    : tPorts(0 to max(2, MESSAGE_PORT_CNT)) := getPorts(MESSAGE_TRACER_ALL);
    constant PORTS            : natural := INST_PORT_CNT + MEM_PORT_CNT + MESSAGE_PORT_CNT;
    variable result : tPorts(0 to max(2, PORTS)-1) := (others => NULL_PORT);
    variable index  : natural := 0;
  begin

    --report "getPortsNoDoublings tInstGens tMemGens tMessageGens parameter";
    --print(INST_TRACER_ALL);
    --print(MEM_TRACER_ALL);
    --print(MESSAGE_TRACER_ALL);

    if INST_PORT_CNT > 0 then
      for i in 0 to INST_PORT_CNT-1 loop
        if not containsPort(result, INST_PORTS(i).ID, index) then
          result(index) := INST_PORTS(i);
          index         := index + 1;
        end if;
      end loop;
    end if;

    if MEM_PORT_CNT > 0 then
      for i in 0 to MEM_PORT_CNT-1 loop
        if not containsPort(result, MEM_PORTS(i).ID, index) then
          result(index) := MEM_PORTS(i);
          index         := index + 1;
        end if;
      end loop;
    end if;

    if MESSAGE_PORT_CNT > 0 then
      for i in 0 to MESSAGE_PORT_CNT-1 loop
        if not containsPort(result, MESSAGE_PORTS(i).ID, index) then
          result(index) := MESSAGE_PORTS(i);
          index         := index + 1;
        end if;
      end loop;
    end if;

    --report "getPortsNoDoublings result";
    --print(result);

    return result(0 to max(index, 2)-1);

  end function getPortsNoDoublings;

  function getPorts(INST_TRACER_ALL : tInstGens) return tPorts is
    variable result   : tPorts(0 to max(countPorts(INST_TRACER_ALL),2)-1) := (others => NULL_PORT);
    variable index    : natural := 0;
    variable cntPorts : natural;
  begin

    --report "getPorts tInstGens parameter";
    --print(INST_TRACER_ALL);

    for i in 0 to countTracerGens(INST_TRACER_ALL)-1 loop
      cntPorts := countPorts(INST_TRACER_ALL(i));
      result(index to index+cntPorts-1) := getPorts(INST_TRACER_ALL(i))(0 to cntPorts-1);
      index := index + cntPorts;
    end loop;

    --report "getPorts result";
    --print(result);

    return result;

  end function getPorts;

  function getPorts(MEM_TRACER_ALL : tMemGens) return tPorts is
    variable result   : tPorts(0 to max(countPorts(MEM_TRACER_ALL),2)-1) := (others => NULL_PORT);
    variable index    : natural := 0;
    variable cntPorts : natural;
  begin

    for i in 0 to countTracerGens(MEM_TRACER_ALL)-1 loop
      cntPorts := countPorts(MEM_TRACER_ALL(i));
      result(index to index+cntPorts-1) := getPorts(MEM_TRACER_ALL(i))(0 to cntPorts-1);
      index := index + cntPorts;
    end loop;

    return result;

  end function getPorts;

  function getPorts(MESSAGE_TRACER_ALL : tMessageGens) return tPorts is
    variable result   : tPorts(0 to max(countPorts(MESSAGE_TRACER_ALL),2)-1) := (others => NULL_PORT);
    variable index    : natural := 0;
    variable cntPorts : natural;
  begin

    --report "getPorts tMessageGens parameter";
    --print(MESSAGE_TRACER_ALL);

    for i in 0 to countTracerGens(MESSAGE_TRACER_ALL)-1 loop
      cntPorts := countPorts(MESSAGE_TRACER_ALL(i));
      result(index to index+cntPorts-1) := getPorts(MESSAGE_TRACER_ALL(i))(0 to cntPorts-1);
      index := index + cntPorts;
    end loop;

    --report "getPorts result";
    --print(result);

    return result;

  end function getPorts;

  -- get ports per tracer sorted in array or array

  function getPorts2(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tPort2_array is
    constant INST_TRACER_GENS_CNT    : natural := countTracerGens(INST_TRACER_ALL);
    constant MEM_TRACER_GENS_CNT     : natural := countTracerGens(MEM_TRACER_ALL);
    constant MESSAGE_TRACER_GENS_CNT : natural := countTracerGens(MESSAGE_TRACER_ALL);
    constant CNT    : natural := INST_TRACER_GENS_CNT + MEM_TRACER_GENS_CNT + MESSAGE_TRACER_GENS_CNT;
    variable result : tPort2_array(0 to max(2, CNT)-1) := (others => NULL_PORTS);
    variable index  : natural := 0;
  begin

    --report "getPorts2 tInstGens tMemGens tMessageGens parameter";
    --print(INST_TRACER_ALL);
    --print(MEM_TRACER_ALL);
    --print(MESSAGE_TRACER_ALL);

    if INST_TRACER_GENS_CNT > 0 then
      result(index to index+INST_TRACER_GENS_CNT-1) := getPorts2(INST_TRACER_ALL)(0 to INST_TRACER_GENS_CNT-1);
      index := index + INST_TRACER_GENS_CNT;
    end if;

    if MEM_TRACER_GENS_CNT > 0 then
      result(index to index+MEM_TRACER_GENS_CNT-1) := getPorts2(MEM_TRACER_ALL)(0 to MEM_TRACER_GENS_CNT-1);
      index := index + MEM_TRACER_GENS_CNT;
    end if;

    if MESSAGE_TRACER_GENS_CNT > 0 then
      result(index to index+MESSAGE_TRACER_GENS_CNT-1) := getPorts2(MESSAGE_TRACER_ALL)(0 to MESSAGE_TRACER_GENS_CNT-1);
      index := index + MESSAGE_TRACER_GENS_CNT;
    end if;

    --report "getPorts2 result";
    --print(result);

    return result;

  end function getPorts2;

  function getPorts2(INST_TRACER_ALL : tInstGens) return tPort2_array is
    constant CNT    : natural := countTracerGens(INST_TRACER_ALL);
    variable result : tPort2_array(0 to max(CNT,2)-1) := (others => NULL_PORTS);
  begin

    for i in 0 to CNT-1 loop
      result(i) := getPorts(INST_TRACER_ALL(i));
    end loop;

    return result;

  end function getPorts2;

  function getPorts2(MEM_TRACER_ALL : tMemGens) return tPort2_array is
    constant CNT    : natural := countTracerGens(MEM_TRACER_ALL);
    variable result : tPort2_array(0 to max(CNT,2)-1) := (others => NULL_PORTS);
  begin

    for i in 0 to CNT-1 loop
      result(i) := getPorts(MEM_TRACER_ALL(i));
    end loop;

    return result;

  end function getPorts2;

  function getPorts2(MESSAGE_TRACER_ALL : tMessageGens) return tPort2_array is
    constant CNT    : natural := countTracerGens(MESSAGE_TRACER_ALL);
    variable result : tPort2_array(0 to max(CNT,2)-1) := (others => NULL_PORTS);
  begin

    for i in 0 to CNT-1 loop
      result(i) := getPorts(MESSAGE_TRACER_ALL(i));
    end loop;

    return result;

  end function getPorts2;

  -- count ports per single tracer

  function countPorts(INST_TRACER : tInstGen) return natural is
    variable result : natural := 0;
  begin

    --report "countPorts tInstGen parameter";
    --print(INST_TRACER);

    if not isNullTracer(INST_TRACER) then
      result := result + 1;
      if not isNullPort(INST_TRACER.BRANCH_PORT) then
        result := result + 1;
      end if;
    end if;

    --report "countPorts result "&integer'image(result);

    return result;

  end function countPorts;

  function countPorts(MEM_TRACER : tMemGen) return natural is
    variable result : natural := 0;
  begin

    if not isNullTracer(MEM_TRACER) then
      result := result + countPorts(MEM_TRACER.ADR_PORTS);
      result := result + 2;
      if not isNullPort(MEM_TRACER.SOURCE_PORT) then
        result := result + 1;
      end if;
    end if;

    return result;

  end function countPorts;

  function countPorts(MESSAGE_TRACER : tMessageGen) return natural is
    variable result : natural := 0;
  begin

    if not isNullTracer(MESSAGE_TRACER) then
      result := result + countPorts(MESSAGE_TRACER.MSG_PORTS);
    end if;

    return result;

  end function countPorts;

  -- count ports per tracer (with doublings)

  function countPorts(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural is
    variable result : natural := 0;
  begin

    result := result + countPorts(INST_TRACER_ALL);
    result := result + countPorts(MEM_TRACER_ALL);
    result := result + countPorts(MESSAGE_TRACER_ALL);

    return result;

  end function countPorts;

  function countPortsNoDoublings(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural is
    variable result : natural;
  begin

    --report "countPortsNoDoublings tInstGens tMemGens tMessageGens parameter";
    --print(INST_TRACER_ALL);
    --print(MEM_TRACER_ALL);
    --print(MESSAGE_TRACER_ALL);

    result := countPortsNoDoublings(getPorts(INST_TRACER_ALL, MEM_TRACER_ALL, MESSAGE_TRACER_ALL));

    --report "countPortsNoDoublings result "&integer'image(result);
    return result;
  end function countPortsNoDoublings;

  function countPortsNoDoublings(INST_TRACER_ALL : tInstGens) return natural is
  begin
    return countPortsNoDoublings(getPorts(INST_TRACER_ALL));
  end function countPortsNoDoublings;

  function countPortsNoDoublings(MEM_TRACER_ALL : tMemGens) return natural is
  begin
    return countPortsNoDoublings(getPorts(MEM_TRACER_ALL));
  end function countPortsNoDoublings;

  function countPortsNoDoublings(MESSAGE_TRACER_ALL : tMessageGens) return natural is
  begin
    return countPortsNoDoublings(getPorts(MESSAGE_TRACER_ALL));
  end function countPortsNoDoublings;

  function countPorts(INST_TRACER_ALL : tInstGens) return natural is
    constant TRACER_GENS_CNT : natural := countTracerGens(INST_TRACER_ALL);
    variable result          : natural := 0;
  begin

    --report "countPorts tInstGens parameter";
    --print(INST_TRACER_ALL);

    if TRACER_GENS_CNT > 0 then
      for i in 0 to TRACER_GENS_CNT-1 loop
        result := result + countPorts(INST_TRACER_ALL(i));
      end loop;
    end if;

    --report "countPorts result "&integer'image(result);

    return result;

  end function countPorts;


  function countPorts(MEM_TRACER_ALL : tMemGens) return natural is
    constant TRACER_GENS_CNT : natural := countTracerGens(MEM_TRACER_ALL);
    variable result          : natural := 0;
  begin

    if TRACER_GENS_CNT > 0 then
      for i in 0 to TRACER_GENS_CNT-1 loop
        result := result + countPorts(MEM_TRACER_ALL(i));
      end loop;
    end if;

    return result;

  end function countPorts;

  function countPorts(MESSAGE_TRACER_ALL : tMessageGens) return natural is
    constant TRACER_GENS_CNT : natural := countTracerGens(MESSAGE_TRACER_ALL);
    variable result          : natural := 0;
  begin

    if TRACER_GENS_CNT > 0 then
      for i in 0 to TRACER_GENS_CNT-1 loop
        result := result + countPorts(MESSAGE_TRACER_ALL(i));
      end loop;
    end if;

    return result;

  end function countPorts;

  -- remove null values for tracer AND for trigger/ports associated with tracer

  function removeNullValues(INST_TRACER_ALL : tInstGens) return tInstGens is
    constant CNT    : natural := countTracerGens(INST_TRACER_ALL);
    variable result : tInstGens(0 to max(2, CNT)-1) := (others => NULL_INST_TRACER);
    variable index  : natural := 0;
  begin

    for i in 0 to INST_TRACER_ALL'length-1 loop
      if not isNullTracer(INST_TRACER_ALL(i)) then
        result(index)         := INST_TRACER_ALL(i);
        result(index).TRIGGER := fill(removeValue(INST_TRACER_ALL(i).TRIGGER, 0), MAX_TRIGGER);
        index                 := index + 1;
      end if;
    end loop;

    return result;

  end function removeNullValues;

  function removeNullValues(MEM_TRACER_ALL : tMemGens) return tMemGens is
    constant CNT    : natural := countTracerGens(MEM_TRACER_ALL);
    variable result : tMemGens(0 to max(2, CNT)-1) := (others => NULL_MEM_TRACER);
    variable index  : natural := 0;
  begin

    for i in 0 to MEM_TRACER_ALL'length-1 loop
      if not isNullTracer(MEM_TRACER_ALL(i)) then
        result(index)           := MEM_TRACER_ALL(i);
        result(index).ADR_PORTS := fill(removeNullValues(result(index).ADR_PORTS), MEM_ADR_PORTS_PER_INSTANCE);
        result(index).TRIGGER   := fill(removeValue(MEM_TRACER_ALL(i).TRIGGER, 0), MAX_TRIGGER);
        index                   := index + 1;
      end if;
    end loop;

    return result;

  end function removeNullValues;

  function removeNullValues(MESSAGE_TRACER_ALL : tMessageGens) return tMessageGens is
    constant CNT    : natural := countTracerGens(MESSAGE_TRACER_ALL);
    variable result : tMessageGens(0 to max(2, CNT)-1) := (others => NULL_MESSAGE_TRACER);
    variable index  : natural := 0;
  begin

    --report "removeNullValues tMessageGens parameter";
    --print(MESSAGE_TRACER_ALL);

    for i in 0 to MESSAGE_TRACER_ALL'length-1 loop
      if not isNullTracer(MESSAGE_TRACER_ALL(i)) then
        result(index)           := MESSAGE_TRACER_ALL(i);
        result(index).MSG_PORTS := fill(removeNullValues(result(index).MSG_PORTS), MESSAGE_PORTS_PER_INSTANCE);
        result(index).TRIGGER   := fill(removeValue(MESSAGE_TRACER_ALL(i).TRIGGER, 0), MAX_TRIGGER);
        index                   := index + 1;
      end if;
    end loop;

    --report "removeNullValues result";
    --print(result);

    return result;

  end function removeNullValues;

  function countTrigger(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return natural is
    variable cnt : natural := 0;
  begin
    cnt := cnt + countTrigger(INST_TRACER_ALL);
    cnt := cnt + countTrigger(MEM_TRACER_ALL);
    cnt := cnt + countTrigger(MESSAGE_TRACER_ALL);
    return cnt;
  end function countTrigger;

  function countTrigger(INST_TRACER_ALL : tInstGens) return natural is
    constant TRACER_GEN_CNT : natural := countTracerGens(INST_TRACER_ALL);
    variable cnt : natural := 0;
  begin
    if TRACER_GEN_CNT > 0 then
      for i in 0 to TRACER_GEN_CNT-1 loop
        cnt := cnt + countValuesGreaterThan(INST_TRACER_ALL(i).TRIGGER, 0);
      end loop;
    end if;
    return cnt;
  end function countTrigger;

  function countTrigger(MEM_TRACER_ALL : tMemGens) return natural is
    constant TRACER_GEN_CNT : natural := countTracerGens(MEM_TRACER_ALL);
    variable cnt : natural := 0;
  begin
    if TRACER_GEN_CNT > 0 then
      for i in 0 to TRACER_GEN_CNT-1 loop
        cnt := cnt + countValuesGreaterThan(MEM_TRACER_ALL(i).TRIGGER, 0);
      end loop;
    end if;
    return cnt;
  end function countTrigger;

  function countTrigger(MESSAGE_TRACER_ALL : tMessageGens) return natural is
    constant TRACER_GEN_CNT : natural := countTracerGens(MESSAGE_TRACER_ALL);
    variable cnt : natural := 0;
  begin
    if TRACER_GEN_CNT > 0 then
      for i in 0 to TRACER_GEN_CNT-1 loop
        cnt := cnt + countValuesGreaterThan(MESSAGE_TRACER_ALL(i).TRIGGER, 0);
      end loop;
    end if;
    return cnt;
  end function countTrigger;

  function getTriggerIds(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tNat_array is
    constant INST_TRIGGER_CNT    : natural := countTrigger(INST_TRACER_ALL);
    constant MEM_TRIGGER_CNT     : natural := countTrigger(MEM_TRACER_ALL);
    constant MESSAGE_TRIGGER_CNT : natural := countTrigger(MESSAGE_TRACER_ALL);
    constant INST_TRIGGER_IDS    : tNat_array(0 to max(2, INST_TRIGGER_CNT)-1)    := getTriggerIds(INST_TRACER_ALL);
    constant MEM_TRIGGER_IDS     : tNat_array(0 to max(2, MEM_TRIGGER_CNT)-1)     := getTriggerIds(MEM_TRACER_ALL);
    constant MESSAGE_TRIGGER_IDS : tNat_array(0 to max(2, MESSAGE_TRIGGER_CNT)-1) := getTriggerIds(MESSAGE_TRACER_ALL);
    constant CNT    : natural := INST_TRIGGER_CNT + MEM_TRIGGER_CNT + MESSAGE_TRIGGER_CNT;
    variable result : tNat_array(0 to max(CNT, 2)) := (others => 0);
    variable index  : natural;
  begin

    if INST_TRIGGER_CNT > 0 then
      result(index to index+INST_TRIGGER_CNT-1) := INST_TRIGGER_IDS(0 to INST_TRIGGER_CNT-1);
      index := index + INST_TRIGGER_CNT;
    end if;

    if MEM_TRIGGER_CNT > 0 then
      result(index to index+MEM_TRIGGER_CNT-1) := MEM_TRIGGER_IDS(0 to MEM_TRIGGER_CNT-1);
      index := index + MEM_TRIGGER_CNT;
    end if;

    if MESSAGE_TRIGGER_CNT > 0 then
      result(index to index+MESSAGE_TRIGGER_CNT-1) := MESSAGE_TRIGGER_IDS(0 to MESSAGE_TRIGGER_CNT-1);
      index := index + MESSAGE_TRIGGER_CNT;
    end if;

    return result;

  end function getTriggerIds;

  function getTriggerIds(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens;
                         MESSAGE_TRACER_ALL : tMessageGens; INDEX : natural) return tNat_array is
    constant INST_TRACER_GEN_CNT    : natural := countTracerGens(INST_TRACER_ALL);
    constant MEM_TRACER_GEN_CNT     : natural := countTracerGens(MEM_TRACER_ALL);
    constant MESSAGE_TRACER_GEN_CNT : natural := countTracerGens(MESSAGE_TRACER_ALL);
  begin
    if INDEX < INST_TRACER_GEN_CNT then
      return INST_TRACER_ALL(INDEX).TRIGGER;
    end if;

    if INDEX < INST_TRACER_GEN_CNT+MEM_TRACER_GEN_CNT then
      return MEM_TRACER_ALL(INDEX-INST_TRACER_GEN_CNT).TRIGGER;
    end if;

    if INDEX < INST_TRACER_GEN_CNT+MEM_TRACER_GEN_CNT+MESSAGE_TRACER_GEN_CNT then
      return MESSAGE_TRACER_ALL(INDEX-INST_TRACER_GEN_CNT-MEM_TRACER_GEN_CNT).TRIGGER;
    end if;

    assert false severity error;
    return NULL_TRIGGER_IDS;

  end function getTriggerIds;


  function getTriggerIdsNoDoublings(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tNat_array is
    constant INST_TRIGGER_CNT    : natural := countTrigger(INST_TRACER_ALL);
    constant MEM_TRIGGER_CNT     : natural := countTrigger(MEM_TRACER_ALL);
    constant MESSAGE_TRIGGER_CNT : natural := countTrigger(MESSAGE_TRACER_ALL);
    constant INST_TRIGGER_IDS    : tNat_array(0 to max(2, INST_TRIGGER_CNT)-1)    := getTriggerIds(INST_TRACER_ALL);
    constant MEM_TRIGGER_IDS     : tNat_array(0 to max(2, MEM_TRIGGER_CNT)-1)     := getTriggerIds(MEM_TRACER_ALL);
    constant MESSAGE_TRIGGER_IDS : tNat_array(0 to max(2, MESSAGE_TRIGGER_CNT)-1) := getTriggerIds(MESSAGE_TRACER_ALL);
    constant CNT    : natural := INST_TRIGGER_CNT + MEM_TRIGGER_CNT + MESSAGE_TRIGGER_CNT;
    variable result : tNat_array(0 to max(CNT, 2)) := (others => 0);
    variable index  : natural;
  begin

    if INST_TRIGGER_CNT > 0 then
      for i in 0 to INST_TRIGGER_CNT-1 loop
        if not containsValue(result, INST_TRIGGER_IDS(i), index) then
          result(index) := INST_TRIGGER_IDS(i);
          index         := index + 1;
        end if;
      end loop;
    end if;

    if MEM_TRIGGER_CNT > 0 then
      for i in 0 to MEM_TRIGGER_CNT-1 loop
        if not containsValue(result, MEM_TRIGGER_IDS(i), index) then
          result(index) := MEM_TRIGGER_IDS(i);
          index         := index + 1;
        end if;
      end loop;
    end if;

    if MESSAGE_TRIGGER_CNT > 0 then
      for i in 0 to MESSAGE_TRIGGER_CNT-1 loop
        if not containsValue(result, MESSAGE_TRIGGER_IDS(i), index) then
          result(index) := MESSAGE_TRIGGER_IDS(i);
          index         := index + 1;
        end if;
      end loop;
    end if;

    return result(0 to max(2, index)-1);

  end function getTriggerIdsNoDoublings;

  function getTriggerIds(INST_TRACER_ALL : tInstGens) return tNat_array is
    constant CNT    : natural := countTrigger(INST_TRACER_ALL);
    variable result : tNat_array(0 to max(2, CNT)-1) := (others => 0);
    variable index  : natural := 0;
    variable cnt_i  : natural;
  begin

    for i in 0 to countTracerGens(INST_TRACER_ALL)-1 loop
      cnt_i := countValuesGreaterThan(INST_TRACER_ALL(i).TRIGGER, 0);
      if cnt_i > 0 then
        for j in 0 to cnt_i-1 loop
          result(index) := INST_TRACER_ALL(i).TRIGGER(j);
          index         := index + 1;
        end loop;
      end if;
    end loop;

    return result;

  end function getTriggerIds;

  function getTriggerIds(MEM_TRACER_ALL : tMemGens) return tNat_array is
    constant CNT    : natural := countTrigger(MEM_TRACER_ALL);
    variable result : tNat_array(0 to max(2, CNT)-1) := (others => 0);
    variable index  : natural := 0;
    variable cnt_i  : natural;
  begin

    for i in 0 to countTracerGens(MEM_TRACER_ALL)-1 loop
      cnt_i := countValuesGreaterThan(MEM_TRACER_ALL(i).TRIGGER, 0);
      if cnt_i > 0 then
        for j in 0 to cnt_i-1 loop
          result(index) := MEM_TRACER_ALL(i).TRIGGER(j);
          index         := index + 1;
        end loop;
      end if;
    end loop;

    return result;

  end function getTriggerIds;

  function getTriggerIds(MESSAGE_TRACER_ALL : tMessageGens) return tNat_array is
    constant CNT    : natural := countTrigger(MESSAGE_TRACER_ALL);
    variable result : tNat_array(0 to max(2, CNT)-1) := (others => 0);
    variable index  : natural := 0;
    variable cnt_i  : natural;
  begin

    for i in 0 to countTracerGens(MESSAGE_TRACER_ALL)-1 loop
      cnt_i := countValuesGreaterThan(MESSAGE_TRACER_ALL(i).TRIGGER, 0);
      if cnt_i > 0 then
        for j in 0 to cnt_i-1 loop
          result(index) := MESSAGE_TRACER_ALL(i).TRIGGER(j);
          index         := index + 1;
        end loop;
      end if;
    end loop;

    return result;

  end function getTriggerIds;

  -- Priority

  function getPriorities(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens) return tPrio_array is
    constant INST_TRACER_GENS_CNT    : natural := countTracerGens(INST_TRACER_ALL);
    constant MEM_TRACER_GENS_CNT     : natural := countTracerGens(MEM_TRACER_ALL);
    constant MESSAGE_TRACER_GENS_CNT : natural := countTracerGens(MESSAGE_TRACER_ALL);
    variable priorities : tPrio_array(0 to countTracer(INST_TRACER_ALL, MEM_TRACER_ALL, MESSAGE_TRACER_ALL)-1);
    variable index      : natural := 0;
  begin

    if INST_TRACER_GENS_CNT > 0 then
      for i in 0 to INST_TRACER_GENS_CNT-1 loop
        for j in 0 to getInputs(INST_TRACER_ALL(i))-1 loop
          priorities(index) := INST_TRACER_ALL(i).PRIORITY;
          index := index + 1;
        end loop;
      end loop;
    end if;

    if MEM_TRACER_GENS_CNT > 0 then
      for i in 0 to MEM_TRACER_GENS_CNT-1 loop
        for j in 0 to getInputs(MEM_TRACER_ALL(i))-1 loop
          priorities(index) := MEM_TRACER_ALL(i).PRIORITY;
          index := index + 1;
        end loop;
      end loop;
    end if;

    if MESSAGE_TRACER_GENS_CNT > 0 then
      for i in 0 to MESSAGE_TRACER_GENS_CNT-1 loop
        for j in 0 to getInputs(MESSAGE_TRACER_ALL(i))-1 loop
          priorities(index) := MESSAGE_TRACER_ALL(i).PRIORITY;
          index := index + 1;
        end loop;
      end loop;
    end if;

    return priorities;
  end function getPriorities;

  -- Output-Data-Bits

  function getTracerDataOutBits(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens; MESSAGE_TRACER_ALL : tMessageGens;
                                TIME_BITS : natural; PRIORITIES : tPrio_array) return tNat_array is
    constant INST_TRACER_GENS_CNT    : natural := countTracerGens(INST_TRACER_ALL);
    constant MEM_TRACER_GENS_CNT     : natural := countTracerGens(MEM_TRACER_ALL);
    constant MESSAGE_TRACER_GENS_CNT : natural := countTracerGens(MESSAGE_TRACER_ALL);
    constant TRACER_CNT       : positive := countTracer(INST_TRACER_ALL, MEM_TRACER_ALL, MESSAGE_TRACER_ALL);
    variable result           : tNat_array(0 to max(TRACER_CNT, 2)-1) := (others => 0);
    variable index            : natural := 0;
  begin

    if INST_TRACER_GENS_CNT > 0 then
      for i in 0 to INST_TRACER_GENS_CNT-1 loop
        for j in 0 to getInputs(INST_TRACER_ALL(i))-1 loop
          result(index) := getInstDataOutBits(INST_TRACER_ALL(i).ADR_PORT, not isNullPort(INST_TRACER_ALL(i).BRANCH_PORT),
                                              INST_TRACER_ALL(i).COUNTER_BITS, INST_TRACER_ALL(i).HISTORY_BYTES,
                                              getCodeCoding(PRIORITIES,  countTracer(INST_TRACER_ALL, i)+j)'length, TIME_BITS);
          index         := index + 1;
        end loop;
      end loop;
    end if;

    if MEM_TRACER_GENS_CNT > 0 then
      for i in 0 to MEM_TRACER_GENS_CNT-1 loop
        for j in 0 to getInputs(MEM_TRACER_ALL(i))-1 loop
          result(index) := getMemDataOutBits(MEM_TRACER_ALL(i).ADR_PORTS, MEM_TRACER_ALL(i).DATA_PORT,
                                             ifThenElse(isNullPort(MEM_TRACER_ALL(i).SOURCE_PORT), 0,
                                             MEM_TRACER_ALL(i).SOURCE_PORT.WIDTH), getCodeCoding(PRIORITIES,
                                             countTracer(INST_TRACER_ALL) + countTracer(MEM_TRACER_ALL, i)+j)'length,
                                             TIME_BITS);
          index         := index + 1;
        end loop;
      end loop;
    end if;

    if MESSAGE_TRACER_GENS_CNT > 0 then
      for i in 0 to MESSAGE_TRACER_GENS_CNT-1 loop
        for j in 0 to getInputs(MESSAGE_TRACER_ALL(i))-1 loop
          result(index) := getMessageDataOutBits(MESSAGE_TRACER_ALL(i).MSG_PORTS, getCodeCoding(PRIORITIES,
                                                 countTracer(INST_TRACER_ALL)+countTracer(MEM_TRACER_ALL)+countTracer(MESSAGE_TRACER_ALL, i)+j)'length, TIME_BITS);
          index         := index + 1;
        end loop;
      end loop;
    end if;
    return result;
  end function getTracerDataOutBits;

  function getTracerDataOutBits(OUT_BITS : positive; COMPRESSION : boolean; TIME_BITS : natural) return positive is
  begin

    --report "getTracerDataOutBits parameter OUT_BITS "&integer'image(OUT_BITS);

    if OUT_BITS < 8 then
      if COMPRESSION then

        --report "getTracerDataOutBits result 8";

        return 8;
      else

        --report "getTracerDataOutBits result "&integer'image(OUT_BITS);

        return OUT_BITS;
      end if;
    end if;
    for i in 8 to OUT_BITS loop
      if (OUT_BITS mod i = 0) or ((OUT_BITS mod i) + TIME_BITS >= 8) then
        --report "getTracerDataOutBits result "&integer'image(i);
        return i;
      end if;
    end loop;
    assert false severity error;
    return 1;

  end function getTracerDataOutBits;

  function getTracerGlobalIndex(INST_TRACER_ALL : tInstGens; MEM_TRACER_ALL : tMemGens;
                                MESSAGE_TRACER_ALL : tMessageGens; GEN : natural; INPUTS : natural) return natural is
    constant INST_TRACER_GEN_CNT    : natural := countTracerGens(INST_TRACER_ALL);
    constant MEM_TRACER_GEN_CNT     : natural := countTracerGens(MEM_TRACER_ALL);
    constant MESSAGE_TRACER_GEN_CNT : natural := countTracerGens(MESSAGE_TRACER_ALL);
    variable index : natural;
  begin
    if GEN < INST_TRACER_GEN_CNT then
      index := gen;
      return countTracer(INST_TRACER_ALL, index) + INPUTS;
    end if;

    if GEN < INST_TRACER_GEN_CNT+MEM_TRACER_GEN_CNT then
      index := GEN-INST_TRACER_GEN_CNT;
      return countTracer(INST_TRACER_ALL)+countTracer(MEM_TRACER_ALL, index) + INPUTS;
    end if;

    if GEN < INST_TRACER_GEN_CNT+MEM_TRACER_GEN_CNT+MESSAGE_TRACER_GEN_CNT then
      index := GEN-INST_TRACER_GEN_CNT-MEM_TRACER_GEN_CNT;
      return countTracer(INST_TRACER_ALL)+countTracer(MEM_TRACER_ALL)+
             countTracer(MESSAGE_TRACER_ALL, index) + INPUTS;
    end if;

    assert false severity error;
    return 0;
  end function getTracerGlobalIndex;

  --------------------------
  -- Controller-Functions --
  --------------------------

  -- Config-Functions

  function getConfig(PORTS : tPorts; INST_TRACER : tInstGens; MEM_TRACER : tMemGens; MESSAGE_TRACER : tMessageGens;
                     SINGLE_EVENTS : tSingleEvent_array; TRIGGER_ARRAY : tTrigger_array; ICE_REGISTERS : tNat_array;
                     TIME_BITS : positive; TRIGGER_INFORM : boolean; CYCLE_ACCURATE : boolean) return tSlv8_array is
    constant INST_TRACER_GENS_CNT    : natural := countTracerGens(INST_TRACER);
    constant MEM_TRACER_GENS_CNT     : natural := countTracerGens(MEM_TRACER);
    constant MESSAGE_TRACER_GENS_CNT : natural := countTracerGens(MESSAGE_TRACER);
    constant ICE_REGISTERS_CNT       : natural := countValuesGreaterThan(ICE_REGISTERS, 0);
    constant SINGLE_EVENT_CNT        : natural := countSingleEvents(SINGLE_EVENTS);
    constant TRIGGER_CNT             : natural := countTrigger(TRIGGER_ARRAY);
    constant LENGTH : positive := getConfigCnt(PORTS, INST_TRACER, MEM_TRACER, MESSAGE_TRACER, SINGLE_EVENTS,
                                               TRIGGER_ARRAY, ICE_REGISTERS, TIME_BITS, TRIGGER_INFORM, CYCLE_ACCURATE);
    variable result           : tSlv8_array(0 to LENGTH-1);
    variable index            : natural := 0;
  begin

    --report "getConfig parameter";
    --report "ice-register";
    --print(ICE_REGISTERS);

    -- ports
    --report "getConfig ports index "&integer'image(index);
    result(index) := std_logic_vector(to_unsigned(countPorts(PORTS), 8));
    index := index + 1;
    for i in 0 to countPorts(PORTS)-1 loop
      result(index)   := std_logic_vector(to_unsigned(PORTS(i).ID, 8));
      result(index+1) := std_logic_vector(to_unsigned(PORTS(i).WIDTH-1, 8));
      result(index+2) := std_logic_vector(to_unsigned(getEnumIndex(PORTS(i).COMP),2)) &
                         std_logic_vector(to_unsigned(PORTS(i).INPUTS, 6));
      index := index + 3;
    end loop;

    -- single-events
    --report "getConfig trigger index "&integer'image(index);
    result(index) := std_logic_vector(to_unsigned(SINGLE_EVENT_CNT, 8));
    index := index + 1;
    if SINGLE_EVENT_CNT > 0 then
      for i in 0 to SINGLE_EVENT_CNT-1 loop

        result(index)   := std_logic_vector(to_unsigned(SINGLE_EVENTS(i).ID, 8));
        result(index+1) := std_logic_vector(to_unsigned(SINGLE_EVENTS(i).PORT_IN.ID, 8));
        result(index+2) := "00000"&
                           ifThenElse(SINGLE_EVENTS(i).TWO_REGS,
                           std_logic_vector(to_unsigned(getEnumIndex(SINGLE_EVENTS(i).CMP2_INIT), 2)),
                           std_logic_vector(to_unsigned(getEnumIndex(SINGLE_EVENTS(i).CMP1_INIT), 2))) &
                           ifThenElse(SINGLE_EVENTS(i).TWO_REGS, "1", "0");
        index           := index + 3;
      end loop;

      -- initial values
      for i in 0 to getBytesUp(getSingleEventsInitialRegs(SINGLE_EVENTS)'length)-1 loop
        result(index) := getByte(getSingleEventsInitialRegs(SINGLE_EVENTS), i);
        index         := index + 1;
      end loop;
    end if;

    -- trigger
    result(index) := std_logic_vector(to_unsigned(TRIGGER_CNT, 8));
    index := index + 1;
    if TRIGGER_CNT > 0 then
      for i in 0 to TRIGGER_CNT-1 loop
        result(index)   := std_logic_vector(to_unsigned(TRIGGER_ARRAY(i).ID, 8));
        result(index+1) := std_logic_vector(to_unsigned(getTriggerEvents(TRIGGER_ARRAY(i)), 8));
        result(index+2) := "0000" &
                           std_logic_vector(to_unsigned(getEnumIndex(TRIGGER_ARRAY(i).MODE_INIT), 2)) &
                           std_logic_vector(to_unsigned(getEnumIndex(TRIGGER_ARRAY(i).TYPE_INIT), 2));
        index           := index + 3;
      end loop;
    end if;

    -- inst-tracer
    --report "getConfig instTracer index "&integer'image(index);
    result(index) := std_logic_vector(to_unsigned(INST_TRACER_GENS_CNT, 8));
    index         := index + 1;

    if INST_TRACER_GENS_CNT > 0 then
      for i in 0 to INST_TRACER_GENS_CNT-1 loop

        result(index)   := std_logic_vector(to_unsigned(INST_TRACER(i).ADR_PORT.ID, 8));
        result(index+1) := ifThenElse(isNullPort(INST_TRACER(i).BRANCH_PORT), "0", "1") &
                           std_logic_vector(to_unsigned(INST_TRACER(i).PRIORITY,4)) &
                           std_logic_vector(to_unsigned(INST_TRACER(i).HISTORY_BYTES,2)) &
                           ifThenElse(INST_TRACER(i).LS_ENCODING, "1", "0");
        result(index+2) := std_logic_vector(to_unsigned(INST_TRACER(i).COUNTER_BITS,8));
        index           := index + 3;

        if not isNullPort(INST_TRACER(i).BRANCH_PORT) then
          result(index) := std_logic_vector(to_unsigned(INST_TRACER(i).BRANCH_PORT.ID, 8));
          index         := index + 1;
        end if;

      end loop;
    end if;

    -- mem-tracer
    --report "getConfig memTracer index "&integer'image(index);
    result(index) := std_logic_vector(to_unsigned(MEM_TRACER_GENS_CNT, 8));
    index         := index + 1;

    if MEM_TRACER_GENS_CNT > 0 then
      for i in 0 to MEM_TRACER_GENS_CNT-1 loop

        result(index) := std_logic_vector(to_unsigned(countPorts(MEM_TRACER(i).ADR_PORTS),8));
        index         := index + 1;

        for j in 0 to countPorts(MEM_TRACER(i).ADR_PORTS)-1 loop
          result(index) := std_logic_vector(to_unsigned(MEM_TRACER(i).ADR_PORTS(j).ID,8));
          index         := index + 1;
        end loop;

        result(index)   := std_logic_vector(to_unsigned(MEM_TRACER(i).DATA_PORT.ID, 8));
        result(index+1) := std_logic_vector(to_unsigned(MEM_TRACER(i).RW_PORT.ID, 8));
        result(index+2) := std_logic_vector(to_unsigned(MEM_TRACER(i).SOURCE_PORT.ID, 8));
        result(index+3) := "000" &
                           ifThenElse(MEM_TRACER(i).COLLECT_VAL, "1", "0") &
                           std_logic_vector(to_unsigned(MEM_TRACER(i).PRIORITY,4));
        index           := index + 4;

      end loop;
    end if;

    -- message-tracer
    --report "getConfig messageTracer index "&integer'image(index);
    result(index) := std_logic_vector(to_unsigned(MESSAGE_TRACER_GENS_CNT, 8));
    index         := index + 1;

    if MESSAGE_TRACER_GENS_CNT > 0 then
      for i in 0 to MESSAGE_TRACER_GENS_CNT-1 loop

        result(index) := std_logic_vector(to_unsigned(countPorts(MESSAGE_TRACER(i).MSG_PORTS), 8));
        index         := index + 1;

        for j in 0 to countPorts(MESSAGE_TRACER(i).MSG_PORTS)-1 loop
          result(index) := std_logic_vector(to_unsigned(MESSAGE_TRACER(i).MSG_PORTS(j).ID, 8));
          index         := index + 1;
        end loop;

        result(index)   := "0000" & std_logic_vector(to_unsigned(MESSAGE_TRACER(i).PRIORITY,4));
        index           := index + 1;

      end loop;
    end if;

    -- Other Information
    --report "getConfig other information index "&integer'image(index);
    result(index) := std_logic_vector(to_unsigned(TIME_BITS-1, 3)) &
                     "000" &
                     ifThenElse(TRIGGER_INFORM, "1", "0") &
                     ifThenElse(CYCLE_ACCURATE, "1", "0");
    index         := index + 1;


    -- ICE-Register
    --report "getConfig ice-register index "&integer'image(index);
    result(index) := std_logic_vector(to_unsigned(countValuesGreaterThan(ICE_REGISTERS, 0), 8));
    index         := index + 1;

    if ICE_REGISTERS_CNT > 0 then
      for i in 0 to ICE_REGISTERS_CNT-1 loop
        result(index) := std_logic_vector(to_unsigned(ICE_REGISTERS(i), 8));
        index         := index + 1;
      end loop;
    end if;

    --report "getConfig result index "&integer'image(index);

    return result;

  end function getConfig;

  function getConfigCnt(PORTS : tPorts; INST_TRACER : tInstGens; MEM_TRACER : tMemGens; MESSAGE_TRACER : tMessageGens;
                        SINGLE_EVENTS : tSingleEvent_array; TRIGGER_ARRAY : tTrigger_array; ICE_REGISTERS : tNat_array; TIME_BITS : positive;
                        TRIGGER_INFORM : boolean; CYCLE_ACCURATE : boolean) return natural is
    constant INST_TRACER_GENS_CNT    : natural := countTracerGens(INST_TRACER);
    constant MEM_TRACER_GENS_CNT     : natural := countTracerGens(MEM_TRACER);
    constant MESSAGE_TRACER_GENS_CNT : natural := countTracerGens(MESSAGE_TRACER);
    constant ICE_REGISTERS_CNT       : natural := countValuesGreaterThan(ICE_REGISTERS, 0);
    constant SINGLE_EVENT_CNT        : natural := countSingleEvents(SINGLE_EVENTS);
    constant TRIGGER_CNT             : natural := countTrigger(TRIGGER_ARRAY);
    variable index : natural := 0;
  begin

    -- ports
    --report "getConfigCnt ports index "&integer'image(index);
    index := index + 1;
    index := index + countPorts(PORTS)*3;

    -- single-events
    --report "getConfig trigger index "&integer'image(index);
    index := index + 1;
    if SINGLE_EVENT_CNT > 0 then
      index := index + 3*SINGLE_EVENT_CNT;
      index := index + getBytesUp(getSingleEventsInitialRegs(SINGLE_EVENTS)'length);
    end if;

    -- trigger
    index := index + 1;
    index := index + 3*TRIGGER_CNT;

    -- inst-tracer
    --report "getConfigCnt instTracer index "&integer'image(index);
    index := index + 1;
    if INST_TRACER_GENS_CNT > 0 then
      for i in 0 to INST_TRACER_GENS_CNT-1 loop
        index := index + 3;
        if not isNullPort(INST_TRACER(i).BRANCH_PORT) then
          index := index + 1;
        end if;

      end loop;
    end if;

    -- mem-tracer
    --report "getConfigCnt memTracer index "&integer'image(index);
    index := index + 1;
    if MEM_TRACER_GENS_CNT > 0 then
      for i in 0 to MEM_TRACER_GENS_CNT-1 loop

        index := index + 1;

        index := index + countPorts(MEM_TRACER(i).ADR_PORTS);

        index := index + 4;

      end loop;
    end if;

    -- message-tracer
    --report "getConfigCnt messageTracer index "&integer'image(index);
    index := index + 1;
    if MESSAGE_TRACER_GENS_CNT > 0 then
      for i in 0 to MESSAGE_TRACER_GENS_CNT-1 loop

        index := index + 1;

        index := index + countPorts(MESSAGE_TRACER(i).MSG_PORTS);

        index := index + 1;

      end loop;
    end if;

    -- Other Information
    --report "getConfigCnt other information index "&integer'image(index);
    index := index + 1;

    -- ICE-Register
    --report "getConfigCnt ice-register index "&integer'image(index);
    index := index + 1;

    if ICE_REGISTERS_CNT > 0 then
      index := index + ICE_REGISTERS_CNT;
    end if;

    --report "getConfigCnt result index "&integer'image(index);
    return index;

  end function getConfigCnt;

  ---------------------------------------
  -- General Tracer-Functions (intern) --
  ---------------------------------------

  function getTracerHeaderBits(MSG_PORT : tPort) return positive is
    variable result : positive;
  begin
    --report "getTracerHeaderBits tPort parameter";
    --print(MSG_PORT);
    result := getTracerHeaderLenBits(MSG_PORT)+getTracerHeaderValBits(MSG_PORT);
    --report "getTracerHeaderBits result "&integer'image(result);
    return result;
  end function getTracerHeaderBits;

  function sumTracerHeaderBits(MSG_PORTS : tPorts) return positive is
    variable result : natural := 0;
  begin
    --report "sumTracerHeaderBits tPorts parameter";
    --print(MSG_PORTS);
    for i in 0 to countPorts(MSG_PORTS)-1 loop
      result := result + getTracerHeaderBits(MSG_PORTS(i));
    end loop;
    --report "sumTracerHeaderBits result "&integer'image(result);
    return result;
  end function sumTracerHeaderBits;

  function sumTracerHeaderBytes(MSG_PORTS : tPorts) return positive is
    variable bytes : natural := 0;
  begin
    bytes := sumTracerHeaderBits(MSG_PORTS)/8;
    if sumTracerHeaderBits(MSG_PORTS) mod 8 > 0 then
      bytes := bytes + 1;
    end if;
    return bytes;
  end function sumTracerHeaderBytes;

  function getTracerHeaderLenBits(MSG_PORT : tPort) return natural is
    variable result : natural := 0;
  begin
    --report "getTracerHeaderLenBits tPort parameter";
    --print(MSG_PORT);
    if haveCompression(MSG_PORT) then
      result := log2ceil((MSG_PORT.WIDTH/8)+1);
    end if;
    --report "getTracerHeaderLenBits result "&integer'image(result);
    return result;
  end function getTracerHeaderLenBits;

  function sumTracerHeaderLenBits(MSG_PORTS : tPorts) return natural is
    variable cnt : natural := 0;
  begin
    --report "sumTracerHeaderLenBits tPorts parameter";
    --print(MSG_PORTS);
    for i in 0 to countPorts(MSG_PORTS)-1 loop
      cnt := cnt + getTracerHeaderLenBits(MSG_PORTS(i));
    end loop;
    --report "sumTracerHeaderLenBits tPorts result "&integer'image(cnt);
    return cnt;
  end function sumTracerHeaderLenBits;

  function getTracerHeaderValBits(MSG_PORT : tPort) return natural is
  begin
    if not haveCompression(MSG_PORT) then
      return MSG_PORT.WIDTH;
    else
      return MSG_PORT.WIDTH mod 8;
    end if;
  end function getTracerHeaderValBits;

  function sumTracerHeaderValBits(MSG_PORTS : tPorts) return natural is
    variable bits : natural := 0;
  begin
    --report "sumTracerHeaderValBits tPorts parameter";
    --print(MSG_PORTS);
    for i in 0 to countPorts(MSG_PORTS)-1 loop
      bits := bits + getTracerHeaderValBits(MSG_PORTS(i));
    end loop;
    --report "sumTracerHeaderValBits tPorts result "&integer'image(bits);
    return bits;
  end function sumTracerHeaderValBits;

  function getTracerVarValBytes(MSG_PORT : tPort) return natural is
    variable result : natural;
  begin
    if haveCompression(MSG_PORT) then
      result := MSG_PORT.WIDTH/8;
    else
      result := 0;
    end if;

    --report "getTracerVarValBytes result "&integer'image(result);

    return result;
  end function getTracerVarValBytes;

  function sumTracerVarValBytes(MSG_PORTS : tPorts) return natural is
  begin
    return sumTracerVarValBytes(MSG_PORTS, countPorts(MSG_PORTS));
  end function sumTracerVarValBytes;

  function sumTracerVarValBytes(MSG_PORTS : tPorts; INDEX : natural) return natural is
    variable bytes : natural := 0;
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        bytes := bytes + getTracerVarValBytes(MSG_PORTS(i));
      end loop;
    end if;
    return bytes;
  end function sumTracerVarValBytes;

  function haveCompression(MSG_PORT : tPort) return boolean is
  begin
    if MSG_PORT.COMP /= noneC and MSG_PORT.WIDTH/8 > 0 then
      --report "haveCompression result true";
      return true;
    else
      --report "haveCompression result false";
      return false;
    end if;
  end function haveCompression;

  function haveCompression(MSG_PORTS : tPorts) return boolean is
    variable result : boolean := false;
  begin
    for i in 0 to countPorts(MSG_PORTS)-1 loop
      if haveCompression(MSG_PORTS(i)) then
        result := true;
      end if;
    end loop;
    return result;
  end function haveCompression;

  function getCompressionCnt(MSG_PORTS : tPorts) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to countPorts(MSG_PORTS)-1 loop
      if haveCompression(MSG_PORTS(i)) then
        cnt := cnt + 1;
      end if;
    end loop;
    return cnt;
  end function getCompressionCnt;

  function getMaxBitsWithCompression(MSG_PORTS : tPorts) return natural is
    variable max : natural := 0;
  begin
    for i in 0 to countPorts(MSG_PORTS)-1 loop
      if haveCompression(MSG_PORTS(i)) then
        if MSG_PORTS(i).WIDTH > max then
          max := MSG_PORTS(i).WIDTH;
        end if;
      end if;
    end loop;
    return max;
  end function getMaxBitsWithCompression;

  ------------------------------------
  -- Inst-Tracer-Functions (intern) --
  ------------------------------------

  function getInstDataOutBits(ADR_PORT : tPort; BRANCH_INFO : boolean; COUNTER_BITS : positive; HISTORY_BYTES : natural;
                              CODING_BITS : natural; TIME_BITS : natural) return positive is
    variable out_bits    : positive := getTracerHeaderValBits(ADR_PORT) +
                                        getTracerHeaderLenBits(ADR_PORT) +
                                       ifThenElse(BRANCH_INFO, HISTORY_BYTES*8, 0) +
                                       COUNTER_BITS + CODING_BITS;
    variable result      : natural;
  begin
    --report "getInstDataOutBits parameter";
    --report "out_bits "&integer'image(out_bits);
    result := getTracerDataOutBits(out_bits, haveCompression(ADR_PORT), TIME_BITS);
    --report "getInstDataOutBits result "&integer'image(result);
    return result;
  end function getInstDataOutBits;

  -----------------------------------
  -- Mem-Tracer-Functions (intern) --
  -----------------------------------

  function getMemDataOutBits(ADR_PORTS : tPorts; DATA_PORT : tPort; SOURCE_BITS : natural; CODING_BITS : natural;
                             TIME_BITS : natural) return positive is
    constant ADR_PORT_CNT : natural := countPorts(ADR_PORTS);
    constant ID_BITS      : natural := log2ceil(ADR_PORT_CNT+2);
    variable tmp          : positive;
    variable maxValue     : positive := 1;
  begin
    if ADR_PORT_CNT > 1 then
      for i in 0 to ADR_PORT_CNT-2 loop
        tmp := getTracerDataOutBits(CODING_BITS + ID_BITS + SOURCE_BITS + getTracerHeaderBits(ADR_PORTS(i)),
                                    haveCompression(ADR_PORTS(i)), TIME_BITS);
        maxValue := max(maxValue, tmp);
      end loop;
    end if;

    tmp := getTracerDataOutBits(CODING_BITS + ID_BITS + SOURCE_BITS + 1 +
                                getTracerHeaderBits(ADR_PORTS(ADR_PORT_CNT-1)),
                                haveCompression(ADR_PORTS(ADR_PORT_CNT-1)),
                                TIME_BITS);
    maxValue := max(maxValue, tmp);

    tmp := getTracerDataOutBits(CODING_BITS + ID_BITS + SOURCE_BITS +
                                getTracerHeaderBits(DATA_PORT),
                                haveCompression(DATA_PORT),
                                TIME_BITS);
    maxValue := max(maxValue, tmp);

    tmp := getTracerDataOutBits(CODING_BITS + ID_BITS + SOURCE_BITS + 1 +
                                getTracerHeaderBits(ADR_PORTS(ADR_PORT_CNT-1)) + getTracerHeaderBits(DATA_PORT),
                                haveCompression(ADR_PORTS(ADR_PORT_CNT-1)) or haveCompression(DATA_PORT),
                                TIME_BITS);
    maxValue := max(maxValue, tmp);

    return maxValue;

  end function getMemDataOutBits;

  ---------------------------------------
  -- Message-Tracer-Functions (intern) --
  ---------------------------------------

  function getMessageMinMessages(MESSAGES : positive; AVG_COMP_RATIO : tRatio; MIN_MEMORY : boolean; VAR_VAL_BYTES : natural) return positive is
    variable bits : natural := 0;
  begin
    if not MIN_MEMORY or VAR_VAL_BYTES = 0 then
      return MESSAGES;
    else
      return minValue(MESSAGES, positive((real(VAR_VAL_BYTES)*real(MESSAGES)*
                                                          AVG_COMP_RATIO))/VAR_VAL_BYTES);
    end if;
  end function getMessageMinMessages;

  function getMessageDataOutBits(MSG_PORTS : tPorts; CODING_BITS : natural; TIME_BITS : natural) return positive is
    constant OUT_BITS    : positive := sumTracerHeaderBits(MSG_PORTS) + CODING_BITS;
    constant COMPRESSION : boolean  := haveCompression(MSG_PORTS);
  begin
    --report "getMessageDataOutBits parameter";
    --print(MSG_PORTS);
    return getTracerDataOutBits(OUT_BITS, COMPRESSION, TIME_BITS);
  end function getMessageDataOutBits;

  function sumMessageCompLenBits(MSG_PORTS : tPorts; INDEX : natural) return natural is
    variable bits : natural := 0;
  begin
    --report "sumMessageCompLenBits tPorts parameter";
    --report "INDEX "&integer'image(INDEX);
    --print(MSG_PORTS);
    if INDEX > 0 then
      for j in 0 to INDEX-1 loop
        bits := bits + getTracerHeaderLenBits(MSG_PORTS(j));
      end loop;
    end if;
    --report "sumMessageCompLenBits result "&integer'image(bits);
    return bits;
  end function sumMessageCompLenBits;

  function sumMessageCompLenMarkBits(MSG_PORTS : tPorts; INDEX : natural) return natural is
    variable bits : natural := 0;
  begin
    --report "sumMessageCompLenMarkBits tPorts parameter";
    --report "INDEX "&integer'image(INDEX);
    --print(MSG_PORTS);
    if INDEX > 0 then
      for j in 0 to INDEX-1 loop
        bits := bits + getTracerVarValBytes(MSG_PORTS(j));
      end loop;
    end if;
    --report "sumMessageCompLenMarkBits result "&integer'image(bits);
    return bits;
  end function sumMessageCompLenMarkBits;

  function sumMessageCompOutBits(MSG_PORTS : tPorts; INDEX : natural) return natural is
    variable bits : natural := 0;
  begin
    if INDEX > 0 then
      for j in 0 to INDEX-1 loop
        bits := bits + getTracerVarValBytes(MSG_PORTS(j))*8;
      end loop;
    end if;
    return bits;
  end function sumMessageCompOutBits;

  function getMessageVarValValid(MSG_PORTS : tPorts; INDEX : natural; DATA_VALID_BITS : positive) return unsigned is
    variable cnt : natural := 0;
  begin
    for k in 0 to countPorts(MSG_PORTS)-1 loop
      if haveCompression(MSG_PORTS(k)) then
        for l in 0 to getBytesUp(MSG_PORTS(k).WIDTH)-1 loop
          if cnt < INDEX then
            cnt := cnt + 1;
          else
            if l < getBytesUp(MSG_PORTS(k).WIDTH) then
              return to_unsigned(8, DATA_VALID_BITS);
            else
              if MSG_PORTS(k).WIDTH mod 8 = 0 then
                return to_unsigned(8, DATA_VALID_BITS);
              else
                return to_unsigned(MSG_PORTS(k).WIDTH mod 8, DATA_VALID_BITS);
              end if;
            end if;
          end if;
        end loop;
      end if;
    end loop;
    assert false severity error;
    return "0";
  end function getMessageVarValValid;

  function haveMessageResync(MESSAGE_TRACER_ALL : tMessageGens) return boolean is
    variable CNT : natural := countTracerGens(MESSAGE_TRACER_ALL);
  begin
    if CNT > 0 then
      for i in 0 to CNT-1 loop
        if MESSAGE_TRACER_ALL(i).RESYNC then
          return true;
        end if;
      end loop;
    end if;
    return false;
  end function haveMessageResync;

  -----------------------
  -- Trigger-Functions --
  -----------------------

  function removeNullValues(TRIGGER_ARRAY : tTrigger_array) return tTrigger_array is
    constant CNT : natural := countTrigger(TRIGGER_ARRAY);
    variable result : tTrigger_array(0 to max(2, CNT)-1) := (others => NULL_TRIGGER);
    variable index  : natural := 0;
  begin
    for i in 0 to TRIGGER_ARRAY'length-1 loop
      if not isNullTrigger(TRIGGER_ARRAY(i)) then
        result(index)                  := TRIGGER_ARRAY(i);
        result(index).SINGLE_EVENT_IDS := fill(removeValue(TRIGGER_ARRAY(i).SINGLE_EVENT_IDS, 0), MAX_SINGLE_EVENTS);
        --result(index).COMPLEX_EVENTS   := fill(removeNullValues(TRIGGER_ARRAY(i).COMPLEX_EVENTS), MAX_COMPLEX_EVENTS);
        index                          := index + 1;
      end if;
    end loop;
    return result;
  end function removeNullValues;

  function removeNullValues(SINGLE_EVENTS : tSingleEvent_array) return tSingleEvent_array is
    constant CNT : natural := countSingleEvents(SINGLE_EVENTS);
    variable result : tSingleEvent_array(0 to max(2, CNT)-1) := (others => NULL_SINGLE_EVENT);
    variable index  : natural := 0;
  begin
    for i in 0 to SINGLE_EVENTS'length-1 loop
      if not isNullSingleEvent(SINGLE_EVENTS(i)) then
        result(index) := SINGLE_EVENTS(i);
        index         := index + 1;
      end if;
    end loop;
    return result;
  end function removeNullValues;

  function removeNullValues(COMPLEX_EVENTS : tComplexEvent_array) return tComplexEvent_array is
    constant CNT : natural := countComplexEvents(COMPLEX_EVENTS);
    variable result : tComplexEvent_array(0 to max(2, CNT)-1) := (others => NULL_SINGLE_EVENT_IDS);
    variable index  : natural := 0;
  begin
    for i in 0 to COMPLEX_EVENTS'length-1 loop
      if not isNullComplexEvent(COMPLEX_EVENTS(i)) then
        result(index) := fill(removeValue(COMPLEX_EVENTS(i), 0), MAX_SINGLE_EVENTS);
        index         := index + 1;
      end if;
    end loop;
    return result;
  end function removeNullValues;

  function noDoubleId(SINGLE_EVENTS : tSingleEvent_array) return boolean is
    constant CNT : natural := countSingleEvents(SINGLE_EVENTS);
  begin
    if CNT > 1 then
      for i in 0 to CNT-2 loop
        for j in i+1 to CNT-1 loop
          if SINGLE_EVENTS(i).ID = SINGLE_EVENTS(j).ID then
            --report "noDoubleId result false";
            return false;
          end if;
        end loop;
      end loop;
    end if;
    --report "noDoubleId result true";
    return true;
  end function noDoubleId;

  function noDoubleId(TRIGGER_ARRAY : tTrigger_array) return boolean is
    constant CNT : natural := countTrigger(TRIGGER_ARRAY);
  begin
    if CNT > 1 then
      for i in 0 to CNT-2 loop
        for j in i+1 to CNT-1 loop
          if TRIGGER_ARRAY(i).ID = TRIGGER_ARRAY(j).ID then
            --report "noDoubleId result false";
            return false;
          end if;
        end loop;
      end loop;
    end if;
    --report "noDoubleId result true";
    return true;
  end function noDoubleId;

  function isNullTrigger(TRIGGER : tTrigger) return boolean is
  begin
    if countSingleEvents(TRIGGER.SINGLE_EVENT_IDS) > 0 then
      --report "isNullTrigger result false";
      return false;
    end if;
    if countComplexEvents(TRIGGER.COMPLEX_EVENTS) > 0 then
      --report "isNullTrigger result false";
      return false;
    end if;
    --report "isNullTrigger result true";
    return true;
  end function isNullTrigger;

  function isNullSingleEvent(SINGLE_EVENT : tSingleEvent) return boolean is
  begin
    return isNullPort(SINGLE_EVENT.PORT_IN);
  end function isNullSingleEvent;

  function isNullComplexEvent(COMPLEX_EVENT : tNat_array) return boolean is
  begin
    return countSingleEvents(COMPLEX_EVENT) = 0;
  end function isNullComplexEvent;

  function countSingleEvents(SINGLE_EVENTS : tSingleEvent_array) return natural is
  begin
    return countSingleEvents(SINGLE_EVENTS, SINGLE_EVENTS'length);
  end function countSingleEvents;

  function countSingleEvents(SINGLE_EVENTS : tSingleEvent_array; INDEX : natural) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to INDEX-1 loop
      if not isNullSingleEvent(SINGLE_EVENTS(i)) then
        cnt := cnt + 1;
      end if;
    end loop;
    --report "countSingleEvents result "&integer'image(cnt);
    return cnt;
  end function countSingleEvents;

  function countSingleEvents(SINGLE_EVENT_IDS : tNat_array) return natural is
    variable cnt : natural := 0;
  begin
    cnt := countValuesGreaterThan(SINGLE_EVENT_IDS, 0);
    --report "countSingleEvents result "&integer'image(cnt);
    return cnt;
  end function countSingleEvents;

  function countSingleEvents(TRIGGER_ARRAY : tTrigger_array) return natural is
    constant TRIGGER_CNT : natural := countTrigger(TRIGGER_ARRAY);
    variable cnt : natural := 0;
  begin
    --report "countSingleEvents tTrigger_array parameter";
    --print(TRIGGER_ARRAY);
    if TRIGGER_CNT > 0 then
      for i in 0 to countTrigger(TRIGGER_ARRAY)-1 loop
        cnt := cnt + countSingleEvents(TRIGGER_ARRAY(i));
      end loop;
    end if;
    --report "countSingleEvents result "&integer'image(cnt);
    return cnt;
  end function countSingleEvents;

  function countSingleEvents(TRIGGER : tTrigger) return natural is
    variable cnt               : natural := countSingleEvents(TRIGGER.SINGLE_EVENT_IDS);
    constant COMPLEX_EVENT_CNT : natural := countComplexEvents(TRIGGER.COMPLEX_EVENTS);
  begin
    --report "countSingleEvents tTrigger parameter";
    --print(TRIGGER);
    if COMPLEX_EVENT_CNT > 0 then
      for j in 0 to COMPLEX_EVENT_CNT-1 loop
        cnt := cnt + countSingleEvents(TRIGGER.COMPLEX_EVENTS(j));
      end loop;
    end if;
    --report "countSingleEvents result "&integer'image(cnt);
    return cnt;
  end function countSingleEvents;

  function countSingleEventsNoDoublings(TRIGGER : tTrigger) return natural is
    variable cnt               : natural := 0;
    constant SINGLE_EVENT_CNT  : natural := countSingleEvents(TRIGGER.SINGLE_EVENT_IDS);
    constant COMPLEX_EVENT_CNT : natural := countComplexEvents(TRIGGER.COMPLEX_EVENTS);
  begin
    --report "countSingleEventsNoDoublings tTrigger";
    if SINGLE_EVENT_CNT > 0 then
      for j in 0 to SINGLE_EVENT_CNT-1 loop
        if not containsValue(TRIGGER.SINGLE_EVENT_IDS, TRIGGER.SINGLE_EVENT_IDS(j), j) then
          cnt := cnt + 1;
        end if;
      end loop;
    end if;
    if COMPLEX_EVENT_CNT > 0 then
      for j in 0 to COMPLEX_EVENT_CNT-1 loop
        for k in 0 to countSingleEvents(TRIGGER.COMPLEX_EVENTS(j))-1 loop
          if not containsValue(TRIGGER.SINGLE_EVENT_IDS, TRIGGER.COMPLEX_EVENTS(j)(k)) then
            if not containsSingleEvent(TRIGGER.COMPLEX_EVENTS, TRIGGER.COMPLEX_EVENTS(j)(k), j) then
              cnt := cnt + 1;
            end if;
          end if;
        end loop;
      end loop;
    end if;
    --report "countSingleEventsNoDoublings result "&integer'image(cnt);
    return cnt;
  end function countSingleEventsNoDoublings;

  function countComplexEvents(COMPLEX_EVENTS : tComplexEvent_array) return natural is
    variable cnt : natural := 0;
  begin
    --report "countComplexEvents tComplexEvent_array parameter";
    --print(COMPLEX_EVENTS);
    for i in 0 to COMPLEX_EVENTS'length-1 loop
      if not isNullComplexEvent(COMPLEX_EVENTS(i)) then
        cnt := cnt + 1;
      end if;
    end loop;

    --report "countComplexEvents result "&integer'image(cnt);
    return cnt;
  end function countComplexEvents;

  function countComplexEvents(TRIGGER_ARRAY : tTrigger_array) return natural is
    variable cnt : natural := 0;
  begin
    --report "countComplexEvents tTrigger_array";
    for i in 0 to countTrigger(TRIGGER_ARRAY)-1 loop
      cnt := cnt + countComplexEvents(TRIGGER_ARRAY(i).COMPLEX_EVENTS);
    end loop;

    --report "countComplexEvents result "&integer'image(cnt);
    return cnt;
  end function countComplexEvents;

  function countComplexEventsNoDoublings(TRIGGER_ARRAY : tTrigger_array) return natural is
    variable cnt : natural := 0;
  begin
    --report "countComplexEventsNoDoublings tTrigger_array";
    for i in 0 to countTrigger(TRIGGER_ARRAY)-1 loop
      for j in 0 to countComplexEvents(TRIGGER_ARRAY(i).COMPLEX_EVENTS)-1 loop
        if not containsComplexEvent(TRIGGER_ARRAY, TRIGGER_ARRAY(i).COMPLEX_EVENTS(j), i) then
          cnt := cnt + 1;
        end if;
      end loop;
    end loop;

    --report "countComplexEventsNoDoublings result "&integer'image(cnt);
    return cnt;
  end function countComplexEventsNoDoublings;

  function countTriggerNoDoublings(TRIGGER_ARRAY : tTrigger_array) return natural is
    variable cnt : natural := 0;
  begin
    --report "countTriggerNoDoublings tTrigger_array parameter";
    --print(TRIGGER_ARRAY);
    for i in 0 to TRIGGER_ARRAY'length-1 loop
      if not containsTrigger(TRIGGER_ARRAY, TRIGGER_ARRAY(i).ID, i) then
        if not isNullTrigger(TRIGGER_ARRAY(i)) then
          cnt := cnt + 1;
        end if;
      end if;
    end loop;
    --report "countTriggerNoDoublings result "&integer'image(cnt);
    return cnt;
  end function countTriggerNoDoublings;

  function countTrigger(TRIGGER_ARRAY : tTrigger_array) return natural is
    variable cnt : natural := 0;
  begin
    --report "countTrigger tTrigger_array parameter";
    --print(TRIGGER_ARRAY);
    for i in 0 to TRIGGER_ARRAY'length-1 loop
      if not isNullTrigger(TRIGGER_ARRAY(i)) then
        cnt := cnt + 1;
      end if;
    end loop;
    --report "countTrigger result "&integer'image(cnt);
    return cnt;
  end function countTrigger;

  function containsSingleEvent(SINGLE_EVENTS : tSingleEvent_array; ID : natural) return boolean is
  begin
    return containsSingleEvent(SINGLE_EVENTS, ID, countSingleEvents(SINGLE_EVENTS));
  end function containsSingleEvent;

  function containsSingleEvent(SINGLE_EVENTS : tSingleEvent_array; ID : natural; INDEX : natural) return boolean is
  begin
    --report "containsSingleEvent tSingleEvent_array";
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        if SINGLE_EVENTS(i).ID = ID then
          --report "containsSingleEvent result true";
          return true;
        end if;
      end loop;
    end if;
    --report "containsSingleEvent result false";
    return false;
  end function containsSingleEvent;

  function containsSingleEvent(TRIGGER_ARRAY : tTrigger_array; ID : natural; INDEX : natural) return boolean is
  begin
    --report "containsSingleEvent tTrigger_array";
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        if containsValue(TRIGGER_ARRAY(i).SINGLE_EVENT_IDS, ID) then
          --report "containsSingleEvent result true";
          return true;
        end if;
        if containsSingleEvent(TRIGGER_ARRAY(i).COMPLEX_EVENTS, ID) then
          --report "containsSingleEvent result true";
          return true;
        end if;
      end loop;
    end if;
    --report "containsSingleEvent result false";
    return false;
  end function containsSingleEvent;

  function containsSingleEvent(COMPLEX_EVENTS : tComplexEvent_array; ID : natural; INDEX : natural) return boolean is
  begin
    --report "containsSingleEvent tComplexEvent_array";
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        if containsValue(COMPLEX_EVENTS(i), ID) then
          --report "containsSingleEvent result true";
          return true;
        end if;
      end loop;
    end if;
    --report "containsSingleEvent result false";
    return false;
  end function containsSingleEvent;

  function containsComplexEvent(COMPLEX_EVENTS : tComplexEvent_array; COMPLEX_EVENT : tNat_array; INDEX : natural) return boolean is
  begin
    --report "containsComplexEvent tComplexEvent_array";
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        if complexEventsEqual(COMPLEX_EVENTS(i), COMPLEX_EVENT) then
          --report "containsComplexEvent result true";
          return true;
        end if;
      end loop;
    end if;
    --report "containsComplexEvent result false";
    return false;
  end function containsComplexEvent;

  function containsComplexEvent(TRIGGER_ARRAY : tTrigger_array; COMPLEX_EVENT : tNat_array; INDEX : natural) return boolean is
  begin
    --report "containsComplexEvent tTrigger_array";
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        for j in 0 to countComplexEvents(TRIGGER_ARRAY(i).COMPLEX_EVENTS) loop
          if complexEventsEqual(TRIGGER_ARRAY(i).COMPLEX_EVENTS(j), COMPLEX_EVENT) then
            --report "containsComplexEvent result true";
            return true;
          end if;
        end loop;
      end loop;
    end if;
    --report "containsComplexEvent result false";
    return false;
  end function containsComplexEvent;

  function containsComplexEvent(COMPLEX_EVENTS : tComplexEvent_array; COMPLEX_EVENT : tNat_array) return boolean is
  begin
    return containsComplexEvent(COMPLEX_EVENTS, COMPLEX_EVENT, countComplexEvents(COMPLEX_EVENTS));
  end function containsComplexEvent;

  function containsSingleEvent(COMPLEX_EVENTS : tComplexEvent_array; ID : natural) return boolean is
  begin
    return containsSingleEvent(COMPLEX_EVENTS, ID, countComplexEvents(COMPLEX_EVENTS));
  end function containsSingleEvent;

  function containsPort(SINGLE_EVENTS : tSingleEvent_array; ID : natural) return boolean is
  begin
    --report "containsPort";
    return containsPort(SINGLE_EVENTS, ID, countSingleEvents(SINGLE_EVENTS));
  end function containsPort;

  function containsPort(SINGLE_EVENTS : tSingleEvent_array; ID : natural; INDEX : natural) return boolean is
    variable cnt : natural := 0;
  begin
    --report "containsPort tSingleEvent_array";
    for i in 0 to INDEX-1 loop
      if SINGLE_EVENTS(i).PORT_IN.ID = ID then
        --report "containsPort result true";
        return true;
      end if;
    end loop;
    --report "containsPort result false";
    return false;
  end function containsPort;

  function containsTrigger(TRIGGER_ARRAY : tTrigger_array; ID : natural) return boolean is
  begin
    --report "containsTrigger";
    return containsTrigger(TRIGGER_ARRAY, ID, countTrigger(TRIGGER_ARRAY));
  end function containsTrigger;

  function containsTrigger(TRIGGER_ARRAY : tTrigger_array; ID : natural; INDEX : natural) return boolean is
    variable cnt : natural := 0;
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        if TRIGGER_ARRAY(i).ID = ID then
          --report "containsTrigger result true";
          return true;
        end if;
      end loop;
    end if;
    --report "containsTrigger result false";
    return false;
  end function containsTrigger;

  function getSingleEventIds(TRIGGER_ARRAY : tTrigger_array) return tNat_array is
    constant TRIGGER_CNT     : natural := countTrigger(TRIGGER_ARRAY);
    constant CNT             : natural := countSingleEvents(TRIGGER_ARRAY);
    variable result          : tNat_array(0 to max(CNT, 2)-1) := (others => 0);
    variable index           : natural := 0;
    variable singleEventCnt  : natural;
    variable complexEventCnt : natural;
  begin
    --report "getSingleEventsIds tTrigger_array parameter";
    --print(TRIGGER_ARRAY);
    if TRIGGER_CNT > 0 then
      for i in 0 to TRIGGER_CNT-1 loop

        -- check all single events
        singleEventCnt := countSingleEvents(TRIGGER_ARRAY(i).SINGLE_EVENT_IDS);
        if singleEventCnt > 0 then
          for j in 0 to singleEventCnt-1 loop
            result(index) := TRIGGER_ARRAY(i).SINGLE_EVENT_IDS(j);
            index         := index + 1;
          end loop;
        end if;

        -- check all complex events
        complexEventCnt := countComplexEvents(TRIGGER_ARRAY(i).COMPLEX_EVENTS);
        if complexEventCnt > 0 then
          for j in 0 to complexEventCnt-1 loop
            for k in 0 to countSingleEvents(TRIGGER_ARRAY(i).COMPLEX_EVENTS(j))-1 loop
              result(index) := TRIGGER_ARRAY(i).COMPLEX_EVENTS(j)(k);
              index         := index + 1;
            end loop;
          end loop;
        end if;

      end loop;
    end if;

    --report "getSingleEventsIds result";
    --print(result);
    return result;

  end function getSingleEventIds;

  function getSingleEventIdsNoDoublings(TRIGGER_ARRAY : tTrigger_array) return tNat_array is
    constant TRIGGER_CNT     : natural := countTrigger(TRIGGER_ARRAY);
    constant CNT             : natural := countSingleEvents(TRIGGER_ARRAY);
    variable result          : tNat_array(0 to max(CNT, 2)-1) := (others => 0);
    variable index           : natural := 0;
    variable singleEventCnt  : natural;
    variable complexEventCnt : natural;
  begin
    --report "getSingleEventIdsNoDoublings tTrigger_array";
    --print(TRIGGER_ARRAY);
    if TRIGGER_CNT > 0 then
      for i in 0 to TRIGGER_CNT-1 loop

        -- check all single events
        singleEventCnt := countSingleEvents(TRIGGER_ARRAY(i).SINGLE_EVENT_IDS);
        if singleEventCnt > 0 then
          for j in 0 to singleEventCnt-1 loop
            -- check, if event is already in list
            if not containsValue(result, TRIGGER_ARRAY(i).SINGLE_EVENT_IDS(j), index) then
              result(index) := TRIGGER_ARRAY(i).SINGLE_EVENT_IDS(j);
              index         := index + 1;
            end if;

          end loop;
        end if;

        -- check all complex events
        complexEventCnt := countComplexEvents(TRIGGER_ARRAY(i).COMPLEX_EVENTS);
        if complexEventCnt > 0 then
          for j in 0 to complexEventCnt-1 loop
            for k in 0 to countSingleEvents(TRIGGER_ARRAY(i).COMPLEX_EVENTS(j))-1 loop
              if not containsValue(result, TRIGGER_ARRAY(i).COMPLEX_EVENTS(j)(k), index) then
                result(index) := TRIGGER_ARRAY(i).COMPLEX_EVENTS(j)(k);
                index         := index + 1;
              end if;

            end loop;
          end loop;
        end if;

      end loop;
    end if;

    --report "getSingleEventIdsNoDoublings result";
    return result(0 to max(2, index)-1);

  end function getSingleEventIdsNoDoublings;

  function getSingleEventIds(TRIGGER : tTrigger) return tNat_array is
    constant CNT               : natural := countSingleEvents(TRIGGER);
    variable result            : tNat_array(0 to max(2, CNT)-1) := (others => 0);
    variable index             : natural := 0;
    constant SINGLE_EVENT_CNT  : natural := countSingleEvents(TRIGGER.SINGLE_EVENT_IDS);
    constant COMPLEX_EVENT_CNT : natural := countComplexEvents(TRIGGER.COMPLEX_EVENTS);
  begin
    --report "getSingleEventIds tTrigger";
    -- check all single events
    if SINGLE_EVENT_CNT > 0 then
      for j in 0 to SINGLE_EVENT_CNT-1 loop
        -- check, if event is already in list
        result(index) := TRIGGER.SINGLE_EVENT_IDS(j);
        index := index + 1;
      end loop;
    end if;

    -- check all complex events
    if COMPLEX_EVENT_CNT > 0 then
      for j in 0 to COMPLEX_EVENT_CNT-1 loop
        for k in 0 to countSingleEvents(TRIGGER.COMPLEX_EVENTS(j))-1 loop
          result(index) := TRIGGER.COMPLEX_EVENTS(j)(k);
          index := index + 1;
        end loop;
      end loop;
    end if;

    --report "getSingleEventIds result";
    return result(0 to max(2, index)-1);

  end function getSingleEventIds;

  function getSingleEventIdsNoDoublings(TRIGGER : tTrigger) return tNat_array is
    constant CNT               : natural := countSingleEvents(TRIGGER);
    variable result            : tNat_array(0 to max(2, CNT)-1);
    variable index             : natural := 0;
    constant SINGLE_EVENT_CNT  : natural := countSingleEvents(TRIGGER.SINGLE_EVENT_IDS);
    constant COMPLEX_EVENT_CNT : natural := countComplexEvents(TRIGGER.COMPLEX_EVENTS);
  begin
    --report "getSingleEventIdsNoDoublings tTrigger";
    -- check all single events
    if SINGLE_EVENT_CNT > 0 then
      for j in 0 to SINGLE_EVENT_CNT-1 loop
        -- check, if event is already in list
        if not containsValue(result, TRIGGER.SINGLE_EVENT_IDS(j), index) then
          result(index) := TRIGGER.SINGLE_EVENT_IDS(j);
          index := index + 1;
        end if;

      end loop;
    end if;

    -- check all complex events
    if COMPLEX_EVENT_CNT > 0 then
      for j in 0 to COMPLEX_EVENT_CNT-1 loop
        for k in 0 to countSingleEvents(TRIGGER.COMPLEX_EVENTS(j))-1 loop
          if not containsValue(result, TRIGGER.COMPLEX_EVENTS(j)(k), index) then
            result(index) := TRIGGER.COMPLEX_EVENTS(j)(k);
            index := index + 1;
          end if;
        end loop;
      end loop;
    end if;

    --report "getSingleEventIdsNoDoublings result";
    return result(0 to max(2, index)-1);

  end function getSingleEventIdsNoDoublings;

  function getSingleEvent(SINGLE_EVENTS : tSingleEvent_array; ID : natural) return tSingleEvent is
  begin
    --report "getSingleEvent tSingleEvent_array ID "&integer'image(ID);
    --print(SINGLE_EVENTS);
    for i in 0 to countSingleEvents(SINGLE_EVENTS)-1 loop
      if SINGLE_EVENTS(i).ID = ID then
        --report "getSingleEvent result";
        --print(SINGLE_EVENTS(i));
        return SINGLE_EVENTS(i);
      end if;
    end loop;
    assert false
      report "ERROR: Single-Event with ID "&integer'image(ID)&" not found."
      severity error;
    return NULL_SINGLE_EVENT;
  end function getSingleEvent;

  function getSingleEvents(SINGLE_EVENTS : tSingleEvent_array; IDS : tNat_array) return tSingleEvent_array is
    variable result : tSingleEvent_array(0 to IDS'length-1) := (others => NULL_SINGLE_EVENT);
  begin
    --report "getSingleEvents tSingleEvent_array tNat_array";
    --print(SINGLE_EVENTS);
    --print(IDS);
    if countSingleEvents(IDS) > 0 then
      for i in 0 to countSingleEvents(IDS)-1 loop
        result(i) := getSingleEvent(SINGLE_EVENTS, IDS(i));
      end loop;
    end if;
    --report "getSingleEvents result";
    --print(result);
    return result;
  end function getSingleEvents;

  function getSingleEventsInitialRegs(SINGLE_EVENTS : tSingleEvent_array) return std_logic_vector is
    constant SINGLE_EVENT_CNT : natural := countSingleEvents(SINGLE_EVENTS);
    constant BITS             : natural := sumSingleEventsRegWidths(SINGLE_EVENTS);
    variable result           : std_logic_vector(BITS-1 downto 0);
    variable index            : natural := 0;
    variable width            : natural;
  begin
    --report "getSingleEventsInitialRegs tSingleEvent_array";
    if SINGLE_EVENT_CNT > 0 then
      for i in 0 to SINGLE_EVENT_CNT-1 loop
        width := SINGLE_EVENTS(i).PORT_IN.WIDTH;
        result(index+width-1 downto index) := SINGLE_EVENTS(i).REG1_INIT(width-1 downto 0);
        index := index + width;
        if SINGLE_EVENTS(i).TWO_REGS then
          result(index+width-1 downto index) := SINGLE_EVENTS(i).REG2_INIT(width-1 downto 0);
          index := index + width;
        end if;
      end loop;
    end if;
    --report "getSingleEventsInitialRegs result";
    return result;
  end function getSingleEventsInitialRegs;

  function getSingleEventLevel(SINGLE_EVENT : tSingleEvent) return natural is
  begin
    --report "getSingleEventLevel";
    return ifThenElse(SINGLE_EVENT.LEVEL_OR, 1, SINGLE_EVENT.PORT_IN.INPUTS);
  end function getSingleEventLevel;

  function sumSingleEventsLevel(SINGLE_EVENTS : tSingleEvent_array) return natural is
  begin
    --report "sumSingleEventsLevel";
    return sumSingleEventsLevel(SINGLE_EVENTS, countSingleEvents(SINGLE_EVENTS));
  end function sumSingleEventsLevel;

  function sumSingleEventsLevel(SINGLE_EVENTS : tSingleEvent_array; INDEX : natural) return natural is
    variable result : natural := 0;
  begin
    --report "sumSingleEventsLevel tSingleEvent_array";
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        result := result + getSingleEventLevel(SINGLE_EVENTS(i));
      end loop;
    end if;
    --report "sumSingleEventsLevel result";
    return result;
  end function sumSingleEventsLevel;

  function getSingleEventIndex(SINGLE_EVENTS : tSingleEvent_array; ID : natural) return natural is
    variable index : natural := 0;
  begin
    --report "getSingleEventIndex tSingleEvent_array";
    for i in 0 to countSingleEvents(SINGLE_EVENTS)-1 loop
      if SINGLE_EVENTS(i).ID = ID then
        --report "getSingleEventIndex result "&integer'image(index);
        return index;
      else
        index := index + 1;
      end if;
    end loop;
    assert false severity error;
    return 1;
  end function getSingleEventIndex;

  function getSingleEventsPorts(SINGLE_EVENTS : tSingleEvent_array) return tPorts is
    constant SINGLE_EVENT_CNT : natural := countSingleEvents(SINGLE_EVENTS);
    variable result           : tPorts(0 to max(2, SINGLE_EVENT_CNT)-1) := (others => NULL_PORT);
    variable index            : natural := 0;
  begin
    --report "getSingleEventsPorts tSingleEvent_array";
    --print(SINGLE_EVENTS);
    if SINGLE_EVENT_CNT > 0 then
      for i in 0 to SINGLE_EVENT_CNT-1 loop
        if not containsPort(result, SINGLE_EVENTS(i).PORT_IN.ID, index) then
          result(index) := SINGLE_EVENTS(i).PORT_IN;
          index := index + 1;
        end if;
      end loop;
    end if;
    --report "getSingleEventsPorts result";
    --print(result);
    return result;
  end function getSingleEventsPorts;

  function sumSingleEventsRegWidths(SINGLE_EVENTS : tSingleEvent_array) return natural is
    variable result : natural := 0;
  begin
    --report "sumSingleEventsRegWidths tSingleEvent_array";
    for i in 0 to countSingleEvents(SINGLE_EVENTS)-1 loop
      result := result + SINGLE_EVENTS(i).PORT_IN.WIDTH;
      if SINGLE_EVENTS(i).TWO_REGS then
        result := result + SINGLE_EVENTS(i).PORT_IN.WIDTH;
      end if;
    end loop;
    --report "sumSingleEventsRegWidths result";
    return result;
  end function sumSingleEventsRegWidths;

  function getSingleEventsRegBits(SINGLE_EVENTS : tSingleEvent_array) return tNat_array is
    constant SINGLE_EVENT_CNT : natural := countSingleEvents(SINGLE_EVENTS);
    variable index            : natural := 0;
    variable result           : tNat_array(0 to SINGLE_EVENTS'length-1) := (others => 0);
  begin
    --report "getSingleEventsRegBits tSingleEvent_array";
    if SINGLE_EVENT_CNT > 0 then
      for i in 0 to SINGLE_EVENT_CNT-1 loop
        result(i) := SINGLE_EVENTS(i).PORT_IN.WIDTH;
      end loop;
    end if;
    --report "getSingleEventsRegBits report";
    return result;
  end function getSingleEventsRegBits;

  function getSingleEventsRegMaxBits(SINGLE_EVENTS : tSingleEvent_array) return natural is
    constant SINGLE_EVENT_CNT : natural := countSingleEvents(SINGLE_EVENTS);
    variable result           : natural := 0;
  begin
    --report "getSingleEventsRegMaxBits tSingleEvent_array";
    if SINGLE_EVENT_CNT > 0 then
      for i in 0 to SINGLE_EVENT_CNT-1 loop
        if SINGLE_EVENTS(i).PORT_IN.WIDTH > result then
          result := SINGLE_EVENTS(i).PORT_IN.WIDTH;
        end if;
      end loop;
    end if;
    --report "getSingleEventsRegMaxBits result";
    return result;
  end function getSingleEventsRegMaxBits;

  function sumSingleEventsPortBits(SINGLE_EVENTS : tSingleEvent_array) return natural is
  begin
    return sumSingleEventsPortBits(SINGLE_EVENTS, countSingleEvents(SINGLE_EVENTS));
  end function sumSingleEventsPortBits;

  function sumSingleEventsPortBits(SINGLE_EVENTS : tSingleEvent_array; INDEX : natural) return natural is
    variable cnt : natural := 0;
  begin
    --report "sumSingleEventsPortBits tSingleEvent_array parameter";
    --report "INDEX "&integer'image(INDEX);
    --print(SINGLE_EVENTS);
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        cnt := cnt + SINGLE_EVENTS(i).PORT_IN.INPUTS*SINGLE_EVENTS(i).PORT_IN.WIDTH;
      end loop;
    end if;
    --report "sumSingleEventsPortBits result "&integer'image(cnt);
    return cnt;
  end function sumSingleEventsPortBits;

  function getMaxSingleEventOutputWidth(SINGLE_EVENTS : tSingleEvent_array) return natural is
    variable result : natural := 0;
    variable tmp : natural := 0;
  begin
    --report "getMaxSingleEventOutputWidth tSingleEvent_array";
    for i in 0 to countSingleEvents(SINGLE_EVENTS)-1 loop
      tmp := ifThenElse(SINGLE_EVENTS(i).LEVEL_OR, 1, SINGLE_EVENTS(i).PORT_IN.WIDTH);
      if tmp > result then
        result := tmp;
      end if;
    end loop;
    --report "getMaxSingleEventOutputWidth result "&integer'image(result);
    return result;
  end function getMaxSingleEventOutputWidth;

  function getComplexEventsNoDoublings(TRIGGER_ARRAY : tTrigger_array) return tComplexEvent_array is
    constant TRIGGER_CNT     : natural := countTrigger(TRIGGER_ARRAY);
    constant CNT             : natural := countComplexEvents(TRIGGER_ARRAY);
    variable complexEventCnt : natural;
    variable result          : tComplexEvent_array(0 to max(2, CNT)-1);
    variable index           : natural := 0;
    variable have            : boolean := false;
  begin
    --report "getComplexEventsNoDoublings tTrigger_array";
    --print(TRIGGER_ARRAY);
    if TRIGGER_CNT > 0 then
      for i in 0 to TRIGGER_CNT-1 loop
        -- check all complex events
        complexEventCnt := countComplexEvents(TRIGGER_ARRAY(i).COMPLEX_EVENTS);
        if complexEventCnt > 0 then
          for j in 0 to complexEventCnt-1 loop
            -- check, if event is already in list
            if index > 0 then
              for k in 0 to index-1 loop
                if complexEventsEqual(TRIGGER_ARRAY(i).COMPLEX_EVENTS(j), result(k)) then
                  have := true;
                end if;
              end loop;
            end if;

            if not have then
              result(index) := TRIGGER_ARRAY(i).COMPLEX_EVENTS(j);
              index := index + 1;
            end if;
            have := false;

          end loop;
        end if;

      end loop;
    end if;
    --report "getComplexEventsNoDoublings result";
    --print(result);
    return result(0 to max(2, index)-1);

  end function getComplexEventsNoDoublings;

  function getComplexEventLevel(COMPLEX_EVENT : tNat_array; SINGLE_EVENTS : tSingleEvent_array) return natural is
    constant SINGLE_EVENT_CNT : natural := countSingleEvents(COMPLEX_EVENT);
    variable levelTmp         : natural;
    variable level            : natural := 1;
  begin
    --report "getComplexEventLevel tNat_array tSingleEvent_array";
    if SINGLE_EVENT_CNT > 0 then
      for i in 0 to SINGLE_EVENT_CNT-1 loop
        levelTmp := getSingleEventLevel(getSingleEvent(SINGLE_EVENTS, COMPLEX_EVENT(i)));
        if levelTmp = 1 or levelTmp = level or level = 1 then
          level := ifThenElse(level > 1, level, getSingleEventLevel(getSingleEvent(SINGLE_EVENTS, COMPLEX_EVENT(i))));
        else
          report "ERROR: Inconsistent level in complex trigger.";
        end if;
      end loop;
    end if;
    --report "getComplexEventLevel result "&integer'image(level);
    return level;
  end function getComplexEventLevel;

  function sumComplexEventsLevel(COMPLEX_EVENTS : tComplexEvent_array; SINGLE_EVENTS : tSingleEvent_array) return natural is
  begin
    return sumComplexEventsLevel(COMPLEX_EVENTS, SINGLE_EVENTS, countComplexEvents(COMPLEX_EVENTS));
  end function sumComplexEventsLevel;

  function sumComplexEventsLevel(COMPLEX_EVENTS : tComplexEvent_array; SINGLE_EVENTS : tSingleEvent_array; INDEX : natural) return natural is
    variable level : natural := 0;
  begin
    --report "sumComplexEventsLevel tComplexEvent_array tSingleEvent_array parameter";
    --report "INDEX "&integer'image(INDEX);
    --print(COMPLEX_EVENTS);
    --print(SINGLE_EVENTS);
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        level := level + getComplexEventLevel(COMPLEX_EVENTS(i), SINGLE_EVENTS);
      end loop;
    end if;
    --report "sumComplexEventsLevel result "&integer'image(level);
    return level;
  end function sumComplexEventsLevel;

  function getComplexEventIndex(COMPLEX_EVENTS : tComplexEvent_array; COMPLEX_EVENT : tNat_array) return natural is
  begin
    --report "getComplexEventIndex tComplexEvent_Array tSingleEvent_array parameter";
    --print(COMPLEX_EVENTS);
    --print(COMPLEX_EVENT);
    for i in 0 to countComplexEvents(COMPLEX_EVENTS)-1 loop
      if complexEventsEqual(COMPLEX_EVENTS(i), COMPLEX_EVENT) then
        --report "getComplexEventIndex result "&integer'image(i);
        return i;
      end if;
    end loop;
    assert false severity error;
    return 0;
  end function getComplexEventIndex;

  function complexEventsEqual(V1 : tNat_array; V2 : tNat_array) return boolean is
    variable have : boolean := false;
  begin

    for i in 0 to countSingleEvents(V1)-1 loop
      if not containsValue(V2, V1(i)) then
        return false;
      end if;
    end loop;

    for i in 0 to countSingleEvents(V2)-1 loop
      if not containsValue(V1, V2(i)) then
        return false;
      end if;
    end loop;

    return true;

  end function complexEventsEqual;

  function getTrigger(TRIGGER_ARRAY : tTrigger_array; ID : natural) return tTrigger is
  begin
    --report "getTrigger tTrigger_array parameter";
    --report "ID "&integer'image(ID);
    --print(TRIGGER_ARRAY);
    for i in 0 to countTrigger(TRIGGER_ARRAY)-1 loop
      if TRIGGER_ARRAY(i).ID = ID then
        return TRIGGER_ARRAY(i);
      end if;
    end loop;
    assert false
      report "ERROR: Trigger with ID "&integer'image(ID)&" not found."
      severity error;
    return NULL_TRIGGER;
  end function getTrigger;


  function getTrigger(TRIGGER_ARRAY : tTrigger_array; IDS : tNat_array) return tTrigger_array is
    variable result : tTrigger_array(0 to IDS'length-1) := (others => NULL_TRIGGER);
    constant ID_CNT : natural := countValuesGreaterThan(IDS, 0);
  begin
    if ID_CNT > 0 then
      for i in 0 to ID_CNT-1 loop
        result(i) := getTrigger(TRIGGER_ARRAY, IDS(i));
      end loop;
    end if;
    return result;
  end function getTrigger;

  function getTriggerIndex(TRIGGER_ARRAY : tTrigger_array; ID : natural) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to countTrigger(TRIGGER_ARRAY)-1 loop
      if TRIGGER_ARRAY(i).ID = ID then
        return cnt;
      else
        cnt := cnt + 1;
      end if;
    end loop;
    assert false severity error;
    return 0;
  end function getTriggerIndex;

  function getTriggerEvents(TRIGGER : tTrigger) return natural is
    variable result : natural := 0;
  begin
    result := result + countSingleEvents(TRIGGER.SINGLE_EVENT_IDS);
    result := result + countComplexEvents(TRIGGER.COMPLEX_EVENTS);
    return result;
  end function getTriggerEvents;

  function getTriggerMaxEvents(TRIGGER_ARRAY : tTrigger_array) return natural is
    constant TRIGGER_CNT : natural := countTrigger(TRIGGER_ARRAY);
    variable result      : natural := 0;
  begin
    if TRIGGER_CNT > 0 then
      for i in 0 to TRIGGER_CNT-1 loop
        if getTriggerEvents(TRIGGER_ARRAY(i)) > result then
          result := getTriggerEvents(TRIGGER_ARRAY(i));
        end if;
      end loop;
    end if;
    return result;
  end function getTriggerMaxEvents;

  function getTriggerLevel(TRIGGER : tTrigger; SINGLE_EVENTS : tSingleEvent_array) return natural is
    constant SINGLE_EVENT_CNT  : natural := countSingleEvents(TRIGGER.SINGLE_EVENT_IDS);
    constant COMPLEX_EVENT_CNT : natural := countComplexEvents(TRIGGER.COMPLEX_EVENTS);
    variable level             : natural := 1;
    variable se_level          : natural := 1;
  begin
    --report "getTriggerLevel tTrigger";
    --print(TRIGGER);
    --print(SINGLE_EVENTS);
    if SINGLE_EVENT_CNT > 0 then
      for i in 0 to SINGLE_EVENT_CNT-1 loop
        se_level := getSingleEventLevel(getSingleEvent(SINGLE_EVENTS, TRIGGER.SINGLE_EVENT_IDS(i)));
        if not ((level = 1) or (se_level = 1) or (se_level = level)) then
          assert false report "ERROR: Trigger-Level are not valid."
            severity error;
        end if;
        level := max(level, se_level);
      end loop;
    end if;
    if COMPLEX_EVENT_CNT > 0 then
      for i in 0 to COMPLEX_EVENT_CNT-1 loop
        for j in 0 to countSingleEvents(TRIGGER.COMPLEX_EVENTS(i))-1 loop
          se_level := getSingleEventLevel(getSingleEvent(SINGLE_EVENTS, TRIGGER.COMPLEX_EVENTS(i)(j)));
          if not ((level = 1) or (se_level = 1) or (se_level = level)) then
            assert false report "ERROR: Trigger-Level are not valid."
              severity error;
          end if;
          level := max(level, se_level);
        end loop;
      end loop;
    end if;
    --report "getTriggerLevel result "&integer'image(level);
    return level;
  end function getTriggerLevel;

  function sumTriggerOutBits(TRIGGER_ARRAY : tTrigger_array; SINGLE_EVENTS : tSingleEvent_array) return natural is
  begin
    return sumTriggerOutBits(TRIGGER_ARRAY, SINGLE_EVENTS, countTrigger(TRIGGER_ARRAY));
  end function sumTriggerOutBits;

  function sumTriggerOutBits(TRIGGER_ARRAY : tTrigger_array; SINGLE_EVENTS : tSingleEvent_array; INDEX : natural) return natural is
    variable result : natural := 0;
  begin
    --report "sumTriggerOutBits tTrigger_array";
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        result := result + getTriggerLevel(TRIGGER_ARRAY(i), SINGLE_EVENTS);
      end loop;
    end if;
    --report "sumTriggerOutBits result "&integer'image(result);
    return result;
  end function sumTriggerOutBits;

  function sumTriggerOutBits(TRIGGER_ARRAY : tTrigger_array; SINGLE_EVENTS : tSingleEvent_array; TRIGGER : tTrigger) return natural is
    variable cnt : natural := 0;
  begin
    --report "sumTriggerOutBits tTrigger_array tTrigger";
    for i in 0 to countTrigger(TRIGGER_ARRAY)-1 loop
      if TRIGGER_ARRAY(i).ID = TRIGGER.ID then
        --report "sumTriggerOutBits result "&integer'image(cnt);
        return cnt;
      else
        cnt := cnt + getTriggerLevel(TRIGGER_ARRAY(i), SINGLE_EVENTS);
      end if;
    end loop;
    assert false severity error;
    return 1;
  end function sumTriggerOutBits;

  ----------------------
  -- Coding-Functions --
  ----------------------

 function getCodeCoding(PRIOARRAY : tPrio_array; I : natural) return std_logic_vector is
    variable startCoding  : std_logic_vector(notZero(getCodeStartCodingLength(PRIOARRAY, I))-1 downto 0);
    variable singleCoding : std_logic_vector(notZero(getCodeSingleCodingLength(PRIOARRAY, I))-1 downto 0);
    variable singleCnt    : positive;
    variable tmp          : natural;
  begin

    --report "getCodeCoding parameter I "&integer'image(I);
    --print(PRIOARRAY);

    -- search all values with same priority
    singleCnt := getCodeEqualPriorityCnt(PRIOARRAY, PRIOARRAY(I));
    if singleCnt > 1 then
      singleCoding
            := std_logic_vector(to_unsigned(getCodeEqualPriorityLowerInListCnt(PRIOARRAY, I), log2ceil(singleCnt)));
    end if;

    --report "singleCoding length "&integer'image(singleCoding'length);
    --report "singleCoding value "&integer'image(to_integer(unsigned(singleCoding)));

    -- all have same coding, so no startCoding is needed
    if getCodeAllPrioEqual(PRIOARRAY) then

      if singleCnt > 1 then
        return singleCoding;
      else
        return "";
      end if;

    -- startCoding is needed
    else

      if PRIOARRAY(I) = getCodeLowestPriority(PRIOARRAY) then
        startCoding := (getCodeHigherPriorityGroupCnt(PRIOARRAY, PRIOARRAY(I))-1 downto 0 => '0');
      else
        if (getCodeHigherPriorityGroupCnt(PRIOARRAY, PRIOARRAY(I)) > 0) then
          startCoding := '1' & (getCodeHigherPriorityGroupCnt(PRIOARRAY, PRIOARRAY(I))-1 downto 0 => '0');
        else
          startCoding := "1";
        end if;
      end if;

      if singleCnt > 1 then
        return singleCoding & startcoding;
      else
        return startcoding;
      end if;

    end if;
    return "0";
  end function getCodeCoding;

  function getCodeStartCodingLength(PRIOARRAY : tPrio_array; I : natural) return natural is
    variable length : positive;
  begin

    --report "getCodeStartCodingLength parameter I "&integer'image(I);
    --print(PRIOARRAY);

    if PRIOARRAY(I) = getCodeLowestPriority(PRIOARRAY) then
      --report "getCodeStartCodingLength result "&integer'image(getCodeHigherPriorityGroupCnt(PRIOARRAY, PRIOARRAY(I)));
      return getCodeHigherPriorityGroupCnt(PRIOARRAY, PRIOARRAY(I));
    else
      --report "getCodeStartCodingLength result "&integer'image(getCodeHigherPriorityGroupCnt(PRIOARRAY, PRIOARRAY(I))+1);
      return getCodeHigherPriorityGroupCnt(PRIOARRAY, PRIOARRAY(I))+1;
    end if;
  end function getCodeStartCodingLength;

  function getCodeSingleCodingLength(PRIOARRAY : tPrio_array; I : natural) return positive is
    variable singleCnt : positive;
  begin
    singleCnt := getCodeEqualPriorityCnt(PRIOARRAY, PRIOARRAY(I));
    return log2ceilnz(singleCnt);
  end function getCodeSingleCodingLength;

  function getCodeAllPrioEqual(PRIOARRAY : tPrio_array) return boolean is
  begin
    if PRIOARRAY'length > 1 then
      for i in 1 to PRIOARRAY'length-1 loop
        if PRIOARRAY(i) /= PRIOARRAY(0) then
          --report "getCodeAllPrioEqual result false";
          return false;
        end if;
      end loop;
    end if;
    --report "getCodeAllPrioEqual result true";
    return true;
  end function getCodeAllPrioEqual;

  function getCodeEqualPriorityCnt(PRIOARRAY : tPrio_array; I : tPrio) return natural is
    variable cnt : natural := 0;
  begin
    for j in 0 to PRIOARRAY'length-1 loop
      if PRIOARRAY(j) = I then
        cnt := cnt + 1;
      end if;
    end loop;
    return cnt;
  end function getCodeEqualPriorityCnt;

  function getCodeHigherPriorityGroupCnt(PRIOARRAY : tPrio_array; PRIO : tPrio) return natural is
    variable cnt : natural := 0;
  begin
    if PRIO < tPrio'high then
      for j in tPrio'high downto PRIO+1 loop
        if getCodeHaveEqualCoding(PRIOARRAY, j) then
          cnt := cnt + 1;
        end if;
      end loop;
    end if;

    --report "getCodeHigherPriorityGroupCount result "&integer'image(cnt);

    return cnt;
  end function getCodeHigherPriorityGroupCnt;

  function getCodeHaveEqualCoding(PRIOARRAY : tPrio_array; I : tPrio) return boolean is
  begin
    for j in 0 to PRIOARRAY'length-1 loop
      if PRIOARRAY(j) = I then
        return true;
      end if;
    end loop;
    return false;
  end function getCodeHaveEqualCoding;

  function getCodeLowestPriority(PRIOARRAY : tPrio_array) return natural is
    variable prio : tPrio := tPrio'high;
  begin
    for i in 0 to PRIOARRAY'length-1 loop
      if PRIOARRAY(i) < prio then
        prio := PRIOARRAY(i);
      end if;
    end loop;
    --report "getCodeLowestPriority result "&integer'image(prio);
    return prio;
  end function getCodeLowestPriority;

  function getCodeEqualPriorityLowerInListCnt(PRIOARRAY : tPrio_array; INDEX : natural) return natural is
    variable cnt : natural := 0;
  begin
    if INDEX > 0 then
      for j in 0 to INDEX-1 loop
        if PRIOARRAY(j) = PRIOARRAY(INDEX) then
          cnt := cnt + 1;
        end if;
      end loop;
    end if;
    return cnt;
  end function getCodeEqualPriorityLowerInListCnt;

  --------------------
  -- Help-Functions --
  --------------------

  function notZero(V : natural) return positive is
    variable result : natural;
  begin
    if V = 0 then
      result := 1;
    else
      result := V;
    end if;
    --report "notZero result "&integer'image(result);
    return result;
  end function notZero;

  function getMsgIndex(MSG_BITS : tNat_array; i : natural) return natural is
    variable index : natural := 0;
  begin
    if i > 0 then
      for j in 0 to i-1 loop
        index := index + MSG_BITS(j);
      end loop;
    end if;
    return index;
  end function getMsgIndex;

  function getByte(INPUT : std_logic_vector; INDEX : natural) return std_logic_vector is
    constant BITS   : natural := getBytesUp(INPUT'length)*8;
    variable tmp    : std_logic_vector(BITS-1 downto 0);
    variable result : std_logic_vector(7 downto 0);
  begin
    tmp    := fill(INPUT, BITS);
    result :=  tmp((INDEX+1)*8-1 downto INDEX*8);
    --report "getByte result LENGTH "&integer'image(result'length)&" VALUE "&integer'image(to_integer(unsigned(result)));
    return result;
  end function getByte;

  function getBytesUp(BITS : natural) return natural is
  begin
    if BITS mod 8 > 0 then
      return BITS/8 + 1;
    else
      return BITS/8;
    end if;
  end function getBytesUp;

  function getBytesUp(BITS : tNat_array) return tNat_array is
    variable result : tNat_array(0 to BITS'length-1);
  begin
    for i in 0 to BITS'length-1 loop
      if BITS(i) mod 8 > 0 then
        result(i) := BITS(i)/8 + 1;
      else
        result(i) := BITS(i)/8;
      end if;
    end loop;
    return result;
  end function getBytesUp;

  function getBytesDown(BITS : natural) return natural is
    variable result : natural;
  begin
    if BITS mod 8 > 0 then
      result := BITS/8;
    else
      result := BITS/8 - 1;
    end if;
    --report "getBytesDown result "&integer'image(result);
    return result;
  end function getBytesDown;

  function getCompInstances(COMPARRAY : tComp_array) return positive is
    variable cnt : natural := 0;
  begin
    for i in 0 to COMPARRAY'length-1 loop
      if COMPARRAY(i) /= noneC then
        cnt := cnt + 1;
      end if;
    end loop;
    return cnt;
  end function getCompInstances;

  function max(NATARRAY : tNat_array) return natural is
    variable max : natural;
  begin
    for i in 0 to NATARRAY'length-1 loop
      if NATARRAY(i) > max then
        max := NATARRAY(i);
      end if;
    end loop;
    --report "max result "&integer'image(max);
    return max;
  end function max;

  function max(POSARRAY : tPos_array) return positive is
    variable max : positive;
  begin
    for i in 0 to POSARRAY'length-1 loop
      if POSARRAY(i) > max then
        max := POSARRAY(i);
      end if;
    end loop;
    return max;
  end function max;

  function minValue(V1 : positive; V2 : positive) return positive is
  begin
    if V1 < V2 then
      --report "max result "&integer'image(V1);
      return V1;
    else
      --report "max result "&integer'image(V2);
      return V2;
    end if;
  end function minValue;

  function max(V1 : natural; V2 : natural) return natural is
  begin
    if V1 > V2 then
      --report "max result "&integer'image(V1);
      return V1;
    else
      --report "max result "&integer'image(V2);
      return V2;
    end if;
  end function max;

  function max(V1 : natural; V2 : natural; V3 : natural) return natural is
  begin
    return max(V1, max(V2, V3));
  end function max;

  function max(V1 : natural; V2 : natural; V3 : natural; V4 : natural) return natural is
  begin
    return max(V1, max(V2, max(V3, V4)));
  end function max;

  function greatestElement(NATARRAY : tNat_array) return natural is
    variable greatest : natural := 0;
  begin
    for i in 0 to NATARRAY'length-1 loop
      if NATARRAY(i) > greatest then
        greatest := NATARRAY(i);
      end if;
    end loop;
    return greatest;
  end function greatestElement;

  function greatestElement(POSARRAY : tPos_array) return positive is
    variable greatest : natural := 0;
  begin
    for i in 0 to POSARRAY'length-1 loop
      if POSARRAY(i) > greatest then
        greatest := POSARRAY(i);
      end if;
    end loop;
    return greatest;
  end function greatestElement;

  function sum(POSARRAY : tPos_array) return positive is
    variable value : natural;
  begin
    for i in 0 to POSARRAY'length-1 loop
      value := value + POSARRAY(i);
    end loop;
    return value;
  end function sum;

  function sum(NATARRAY : tNat_array) return natural is
    variable value : natural;
  begin
    for i in 0 to NATARRAY'length-1 loop
      value := value + NATARRAY(i);
    end loop;
    return value;
  end function sum;

  function sum(POSARRAY : tPos_array; I : natural) return positive is
    variable value : natural := 0;
  begin
    if I > 0 then
      for j in 0 to I-1 loop
        value := value + POSARRAY(j);
      end loop;
    end if;
    return value;
  end function sum;

  function sum(NATARRAY : tNat_array; I : natural) return natural is
    variable value : natural := 0;
  begin
    --report "sum tNat_array parameter";
    --report "I "&integer'image(I);
    --print(NATARRAY);
    if I > 0 then
      for j in 0 to I-1 loop
        value := value + NATARRAY(j);
      end loop;
    end if;
    --report "sum result "&integer'image(value);
    return value;
  end function sum;

  function sumSubsequent(LEFT : natural; RIGHT : natural) return natural is
    variable value : natural := 0;
  begin
    if RIGHT >= LEFT then
      for i in LEFT to RIGHT loop
        value := value+i;
      end loop;
    end if;
    --report "sumSubsequent result " & integer'image(value);
    return value;
  end function sumSubsequent;

  function sumLog2CeilPlusOne(POSARRAY : tPos_array) return positive is
    variable sum : natural;
  begin
    for i in 0 to POSARRAY'length-1 loop
      sum := sum + log2ceil(POSARRAY(i)+1);
    end loop;
    return sum;
  end function sumLog2CeilPlusOne;

  function concat(V1 : tNat_array; V2 : tNat_array) return tNat_array is
    variable result : tNat_array(0 to V1'length+V2'length-1);
  begin
    result(0 to V1'length-1)                   := V1;
    result(V1'length to V1'length+V2'length-1) := V1;
    return result;
  end function concat;

  function divideValuesReturnNZ(V1 : natural; V2 : positive) return positive is
  begin
    if V1/V2 = 0 then
      return 1;
    else
      return V1/V2;
    end if;
  end function divideValuesReturnNZ;

  function divideRoundUp(V1 : natural; V2 : positive) return natural is
    variable result : natural;
  begin
    result := V1 / V2;
    if V1 mod V2 > 0 then
      result := result + 1;
    end if;
    return result;
  end function divideRoundUp;

  function containsValue(NATARRAY : tNat_array; VAL : natural; INDEX : natural) return boolean is
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        if NATARRAY(i) = VAL then
          return true;
        end if;
      end loop;
    end if;
    return false;
  end function containsValue;


  function containsValue(NATARRAY : tNat_array; VAL : natural) return boolean is
  begin
    for i in 0 to NATARRAY'length-1 loop
      if NATARRAY(i) = VAL then
        return true;
      end if;
    end loop;
    return false;
  end function containsValue;

  function countValues(NATARRAY : tNat_array; VAL : natural) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to NATARRAY'length-1 loop
      if NATARRAY(i) = VAL then
        cnt := cnt + 1;
      end if;
    end loop;
    return cnt;
  end function countValues;

  function countValuesGreaterThan(NATARRAY : tNat_array; VAL : natural) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to NATARRAY'length-1 loop
      if NATARRAY(i) > VAL then
        cnt := cnt + 1;
      end if;
    end loop;
    return cnt;
  end function countValuesGreaterThan;

  function countValuesGreaterThan(NATARRAY : tNat_array; INDEX : natural; VAL : natural) return natural is
    variable cnt : natural := 0;
  begin
    if INDEX > 0 then
      for i in 0 to INDEX-1 loop
        if NATARRAY(i) > VAL then
          cnt := cnt + 1;
        end if;
      end loop;
    end if;
    return cnt;
  end function countValuesGreaterThan;

  function countValuesGreaterThanNoDoublings(NATARRAY : tNat_array; VAL : natural) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to NATARRAY'length-1 loop
      if NATARRAY(i) > VAL then
        if not containsValue(NATARRAY, NATARRAY(i), i) then
          cnt := cnt + 1;
        end if;
      end if;
    end loop;
    return cnt;
  end function countValuesGreaterThanNoDoublings;

  function countValuesExclude(NATARRAY : tNat_array; VAL : natural) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to NATARRAY'length-1 loop
      if NATARRAY(i) /= VAL then
        cnt := cnt + 1;
      end if;
    end loop;
    return cnt;
  end function countValuesExclude;

  function getValueFilterNotZero(NATARRAY : tNat_array; INDEX : natural) return positive is
    variable indexTmp : natural := 0;
  begin
    for i in 0 to NATARRAY'length-1 loop
      if NATARRAY(i) /= 0 then
        if indexTmp = INDEX then
          return NATARRAY(i);
        else
          indexTmp := index + 1;
        end if;
      end if;
    end loop;
    assert false severity error;
    return 1;
  end function getValueFilterNotZero;

  function getValuesGreaterThan(NATARRAY : tNat_array; VAL : natural) return tNat_array is
    constant CNT    : natural := countValuesGreaterThan(NATARRAY, VAL);
    variable result : tNat_array(0 to max(2, CNT)-1) := (others => 0);
    variable index  : natural := 0;
  begin
    for i in 0 to NATARRAY'length-1 loop
      if NATARRAY(i) > VAL then
        result(index) := NATARRAY(i);
        index         := index + 1;
      end if;
    end loop;
    return result;
  end function getValuesGreaterThan;

  function getValuesNoDoublings(NATARRAY : tNat_array) return tNat_array is
    constant CNT    : natural := countGroups(NATARRAY);
    variable result : tNat_array(0 to max(2, CNT)-1) := (others => 0);
    variable index  : natural := 0;
  begin
    --report "getValuesNoDoublings tNat_array parameter";
    --print(NATARRAY);
    for i in 0 to NATARRAY'length-1 loop
      if not containsValue(result, NATARRAY(i), index) then
        result(index) := NATARRAY(i);
        index         := index + 1;
      end if;
    end loop;
    --report "getValuesNoDoublings result";
    --print(result);
    return result;
  end function getValuesNoDoublings;

  function removeValue(NATARRAY : tNat_array; VAL : natural) return tNat_array is
    constant CNT    : natural := countValuesExclude(NATARRAY, VAL);
    variable result : tNat_array(0 to max(2, CNT)-1) := (others => 0);
    variable index  : natural := 0;
  begin
    --report "removeValue paramter";
    --report "VAL "&integer'image(VAL);
    --print(NATARRAY);
    for i in 0 to NATARRAY'length-1 loop
      if NATARRAY(i) /= VAL then
        result(index) := NATARRAY(i);
        index         := index + 1;
      end if;
    end loop;
    --report "removeValue result";
    --print(result);
    return result;
  end function removeValue;

  function sort(NATARRAY : tNat_array) return tNat_array is
    variable result        : tNat_array(0 to NATARRAY'length-1);
    variable index         : natural := 0;
    variable last_smallest : integer := -1;
    variable smallest      : natural := integer'high;
    variable cnt           : natural;
  begin
    for i in 0 to countGroups(NATARRAY)-1 loop

      -- get smallest
      for j in 0 to NATARRAY'length-1 loop
        if NATARRAY(j) < smallest and NATARRAY(j) > last_smallest then
          smallest := NATARRAY(j);
        end if;
      end loop;

      cnt                          := countValues(NATARRAY, smallest);
      result(index to index+cnt-1) := (others => smallest);
      index                        := index + cnt;
      last_smallest                := smallest;
      smallest                     := integer'high;
    end loop;
    return result;
  end function sort;

  function countGroups(NATARRAY : tNat_array) return natural is
    variable cnt : natural := 0;
  begin
    for j in 0 to NATARRAY'length-1 loop
      if not containsValue(NATARRAY, NATARRAY(j), j) then
        cnt := cnt + 1;
      end if;
    end loop;
    return cnt;
  end function countGroups;

  function getGroup(NATARRAY : tNat_array; INDEX : natural) return natural is
    variable i : natural := 0;
  begin
    --report "getGroup parameter";
    --report "INDEX "&integer'image(INDEX);
    --print(NATARRAY);
    for j in 0 to NATARRAY'length-1 loop
      if not containsValue(NATARRAY, NATARRAY(j), j) then
        if i = INDEX then
          --report "getGroup result "&integer'image(NATARRAY(j));
          return NATARRAY(j);
        else
          i := i + 1;
        end if;
      end if;
    end loop;
    return 9999;
  end function getGroup;

  function sumGroups(NATARRAY : tNat_array; INDEX : natural) return natural is
    variable sum : natural := 0;
  begin
    --report "sumGroups parameter";
    --report "INDEX "&integer'image(INDEX);
    --print(NATARRAY);

    for j in 0 to NATARRAY'length-1 loop
      if not containsValue(NATARRAY, NATARRAY(j), j) then
        sum := sum + NATARRAY(j);
      end if;
    end loop;
    --report "sumGroups result "&integer'image(sum);
    return sum;
  end function sumGroups;

  function indexOf(NATARRAY : tNat_array; VALUE : natural) return natural is
  begin
    --report "indexOf parameter";
    --report "VALUE "&integer'image(VALUE);
    --print(NATARRAY);
    for j in 0 to NATARRAY'length-1 loop
      if VALUE = NATARRAY(j) then
        --report "indexOf result "&integer'image(j);
        return j;
      end if;
    end loop;
    --report "indexOf result "&integer'image(9999);
    return 9999;
  end function indexOf;

  function indexOf(NATARRAY : tNat_array; VALUE : natural; I : natural) return natural is
    variable cnt : natural := 0;
  begin
    --report "indexOf parameter";
    --report "VALUE "&integer'image(VALUE);
    --report "I "&integer'image(I);
    --print(NATARRAY);
    for j in 0 to NATARRAY'length-1 loop
      if VALUE = NATARRAY(j) then
        if cnt = I then
          report "indexOf result "&integer'image(j);
          return j;
        else
          cnt := cnt + 1;
        end if;
      end if;
    end loop;
    --report "indexOf result "&integer'image(9999);
    return 9999;
  end function indexOf;

  function ifThenElse(COND : boolean; V1 : boolean; V2 : boolean) return boolean is
  begin
    if COND then
      return V1;
    else
      return V2;
    end if;
  end function ifThenElse;

  function ifThenElse(COND : boolean; V1 : integer; V2 : integer) return integer is
  begin

    --report "ifThenElse natural parameter";
    --report boolean'image(COND);
    --report integer'image(V1);
    --report integer'image(V2);

    if COND then
      return V1;
    else
      return V2;
    end if;
  end function ifThenElse;

  function ifThenElse(COND : boolean; V1 : std_logic_vector; V2 : std_logic_vector) return std_logic_vector is
  begin
    if COND then
      return V1;
    else
      return V2;
    end if;
  end function ifThenElse;

  function ifThenElse(COND : boolean; V1 : std_logic; V2 : std_logic) return std_logic is
  begin
    if COND then
      return V1;
    else
      return V2;
    end if;
  end function ifThenElse;

  function ifThenElse(COND : boolean; V1 : unsigned; V2 : unsigned) return unsigned is
  begin
    if COND then
      return V1;
    else
      return V2;
    end if;
  end function ifThenElse;

  function ifThenElse(COND : boolean; V1 : tNat_array; V2 : tNat_array) return tNat_array is
  begin
    if COND then
      return V1;
    else
      return V2;
    end if;
  end function ifThenElse;

  function ifThenElse(COND : boolean; V1 : tPort; V2 : tPort) return tPort is
  begin
    if COND then
      return V1;
    else
      return V2;
    end if;
  end function ifThenElse;

  function ifThenElse(COND : boolean; V1 : tPort2_array; V2 : tPort2_array) return tPort2_array is
  begin
    if COND then
      return V1;
    else
      return V2;
    end if;
  end function ifThenElse;

  function ifThenElse(COND : boolean; V1 : tTriggerMode_array; V2 : tTriggerMode_array) return tTriggerMode_array is
  begin
    if COND then
      return V1;
    else
      return V2;
    end if;
  end function ifThenElse;

  function ifThenElse(COND : boolean; V1 : tTriggerType_array; V2 : tTriggerType_array) return tTriggerType_array is
  begin
    if COND then
      return V1;
    else
      return V2;
    end if;
  end function ifThenElse;

  function ifThenElse(COND : boolean; V1 : tOvDangerReaction; V2 : tOvDangerReaction) return tOvDangerReaction is
  begin
    if COND then
      return V1;
    else
      return V2;
    end if;
  end function ifThenElse;

  function log2ceilnz(arg : tNat_array) return tNat_array is
    variable result : tNat_array(arg'length-1 downto 0);
  begin
    for i in 0 to arg'length-1 loop
      if arg(i) = 0 then
        result(i) := 0;
      else
        result(i) := log2ceilnz(arg(i));
      end if;
    end loop;
    return result;
  end;

  -- returns the position (position 0 = 0) of the first bit with '1'. if no bit is set, the first position is returned
  function getFirstBitSet(INPUT : std_logic_vector) return natural is
  begin
    for i in 0 to INPUT'length-1 loop
      if INPUT(i) = '1' then
        return i;
      end if;
    end loop;
    return 0;
  end function getFirstBitSet;

  -- returns the position (position 0 = 0) of the last bit with '1'. if no bit is set, the first position is returned
  function getLastBitSet(INPUT : std_logic_vector) return natural is
  begin
    for i in INPUT'length-1 downto 0 loop
      if INPUT(i) = '1' then
        return i;
      end if;
    end loop;
    return 0;
  end function getLastBitSet;

  function countBitsSet(INPUT : std_logic_vector) return natural is
    variable cnt : natural := 0;
  begin
    for i in 0 to INPUT'length-1 loop
      if INPUT(i) = '1' then
        cnt := cnt + 1;
      end if;
    end loop;
    return cnt;
  end function countBitsSet;

  function countBlocksSet(INPUT : std_logic_vector; BLOCKSIZE : positive) return natural is
    variable cnt : natural := 0;
  begin
    if INPUT'length/BLOCKSIZE > 0 then
      for i in 0 to INPUT'length/BLOCKSIZE-1 loop
        if INPUT((i+1)*BLOCKSIZE-1 downto i*BLOCKSIZE) = (BLOCKSIZE-1 downto 0 => '1') then
          cnt := cnt + 1;
        end if;
      end loop;
    end if;
    return cnt;
  end function countBlocksSet;

  function fillOrCut(INPUT : std_logic_vector; SIZE : positive) return std_logic_vector is
  begin
    if INPUT'length > SIZE then
      return INPUT(SIZE-1 downto 0);
    elsif INPUT'length < SIZE then
      return (SIZE-1 downto INPUT'LENGTH => '0') & INPUT;
    else
      return INPUT;
    end if;
  end function fillOrCut;

  function fillOrCut(INPUT : unsigned; SIZE : positive) return unsigned is
  begin
    if INPUT'length > SIZE then
      return INPUT(SIZE-1 downto 0);
    elsif INPUT'length < SIZE then
      return (SIZE-1 downto INPUT'LENGTH => '0') & INPUT;
    else
      return INPUT;
    end if;
  end function fillOrCut;

  function fill(INPUT : std_logic_vector; SIZE : positive) return std_logic_vector is
  begin
    --report "fill parameter";
    --report "input length "&integer'image(INPUT'length);
    --report "input value "&integer'image(to_integer(unsigned(INPUT)));
    --report "size "&integer'image(SIZE);
    if INPUT'length < SIZE then
      return (SIZE-1 downto INPUT'LENGTH => '0') & INPUT;
    elsif INPUT'length = SIZE then
      return INPUT;
    end if;
    assert false severity error;
    return INPUT;
  end function fill;

  function fillLSB(INPUT : std_logic_vector; SIZE : positive) return std_logic_vector is
  begin
    if INPUT'length < SIZE then
      return INPUT & (SIZE-1 downto INPUT'LENGTH => '0');
    elsif INPUT'length = SIZE then
      return INPUT;
    end if;
    assert false severity error;
    return INPUT;
  end function fillLSB;

  function fill(INPUT : unsigned; SIZE : positive) return unsigned is
  begin
    if INPUT'length < SIZE then
      return (SIZE-1 downto INPUT'LENGTH => '0') & INPUT;
    elsif INPUT'length = SIZE then
      return INPUT;
    end if;
    assert false severity error;
    return INPUT;
  end function fill;

  function fill(INPUT : tPorts; SIZE : positive) return tPorts is
    variable result : tPorts(0 to SIZE-1);
  begin
    if INPUT'length > SIZE then
      assert false severity error;
    end if;
    if INPUT'length < SIZE then
      result(INPUT'length to SIZE-1) := (others => NULL_PORT);
    end if;
    result(0 to INPUT'length-1) := INPUT;
    return result;
  end function fill;

  function fill(INPUT : tTrigger_array; SIZE : positive) return tTrigger_array is
    variable result : tTrigger_array(0 to SIZE-1);
  begin
    if INPUT'length > SIZE then
      assert false severity error;
    end if;
    if INPUT'length < SIZE then
      result(INPUT'length to SIZE-1) := (others => NULL_TRIGGER);
    end if;
    result(0 to INPUT'length-1) := INPUT;
    return result;
  end function fill;

  function fill(INPUT : tSingleEvent_array; SIZE : positive) return tSingleEvent_array is
    variable result : tSingleEvent_array(0 to SIZE-1);
  begin
    if INPUT'length > SIZE then
      assert false severity error;
    end if;
    if INPUT'length < SIZE then
      result(INPUT'length to SIZE-1) := (others => NULL_SINGLE_EVENT);
    end if;
    result(0 to INPUT'length-1) := INPUT;
    return result;
  end function fill;

  function fill(INPUT : tSingleEvent; SIZE : positive) return tSingleEvent_array is
    variable result : tSingleEvent_array(0 to SIZE-1) := (others => NULL_SINGLE_EVENT);
  begin

    result(0) := INPUT;

    return result;
  end function fill;

  function fill(INPUT : tComplexEvent_array; SIZE : positive) return tComplexEvent_array is
    variable result : tComplexEvent_array(0 to SIZE-1); -- TODO
  begin
    if INPUT'length > SIZE then
      assert false severity error;
    end if;
    if INPUT'length < SIZE then
      result(INPUT'length to SIZE-1) := (INPUT'length to SIZE-1 => NULL_SINGLE_EVENT_IDS);
    end if;
    result(0 to INPUT'length-1) := INPUT;
    return result;
  end function fill;


  function fill(INPUT : tNat_array; SIZE : positive) return tNat_array is
  begin
    --report "fill tNat_array SIZE "&integer'image(SIZE);
    --print(INPUT);
    if INPUT'length < SIZE then
      return INPUT & (SIZE-1 downto INPUT'LENGTH => 0);
    elsif INPUT'length = SIZE then
      return INPUT;
    end if;
    assert false severity error;
    return INPUT;
  end function fill;

  function cut(INPUT : std_logic_vector; SIZE : positive) return std_logic_vector is
  begin
    if INPUT'length > SIZE then
      return input(SIZE-1 downto 0);
    elsif INPUT'length = SIZE then
      return INPUT;
    end if;
    assert false severity error;
    return INPUT;
  end function cut;

  function cut(INPUT : unsigned; SIZE : positive) return unsigned is
  begin
    if INPUT'length > SIZE then
      return input(SIZE-1 downto 0);
    elsif INPUT'length = SIZE then
      return INPUT;
    end if;
    assert false severity error;
    return INPUT;
  end function cut;

  function merge(V1 : tPorts; V2 : tPorts) return tPorts is
    constant V1_CNT : natural := countPorts(V1);
    constant V2_CNT : natural := countPorts(V2);
    constant CNT    : natural := V1_CNT + V2_CNT;
    variable result : tPorts(0 to max(2, CNT) -1) := (others => NULL_PORT);
  begin

    --report "merge tPorts parameter 1";
    --print(V1);
    --report "merge tPorts parameter 2";
    --print(V2);

    result(0 to V1_CNT-1)             := V1(0 to V1_CNT-1);
    result(V1_CNT to V1_CNT+V2_CNT-1) := V2(0 to V2_CNT-1);

    --report "merge result";
    --print(result);

    return result;
  end function merge;

  function mergeNoDoublings(V1 : tPorts; V2 : tPorts) return tPorts is
    constant V1_CNT : natural := countPorts(V1);
    constant V2_CNT : natural := countPorts(V2);
    constant CNT    : natural := V1_CNT + V2_CNT;
    variable result : tPorts(0 to max(2, CNT) -1) := (others => NULL_PORT);
    variable index  : natural := 0;
  begin

    --report "mergeNoDoublings tPorts parameter 1";
    --print(V1);
    --report "mergeNoDoublings tPorts parameter 2";
    --print(V2);

    if V1_CNT > 0 then
      for i in 0 to V1_CNT-1 loop
        if not containsPort(result, V1(i).ID, index) then
          result(index) := V1(i);
          index         := index + 1;
        end if;
      end loop;
    end if;

    if V2_CNT > 0 then
      for i in 0 to V2_CNT-1 loop
        if not containsPort(result, V2(i).ID, index) then
          result(index) := V2(i);
          index         := index + 1;
        end if;
      end loop;
    end if;


    --report "mergeNoDoublings result";
    --print(result);

    return result;
  end function mergeNoDoublings;

  function merge(V1 : tPorts; V2 : tPorts; V3 : tPorts; V4 : tPorts; V5 : tPorts; V6 : tPorts; V7 : tPorts;
                  V8 : tPorts) return tPorts is
    constant V1_CNT : natural := countPorts(V1);
    constant V2_CNT : natural := countPorts(V2);
    constant V3_CNT : natural := countPorts(V3);
    constant V4_CNT : natural := countPorts(V4);
    constant V5_CNT : natural := countPorts(V5);
    constant V6_CNT : natural := countPorts(V6);
    constant V7_CNT : natural := countPorts(V7);
    constant V8_CNT : natural := countPorts(V8);
    constant CNT    : natural := V1_CNT + V2_CNT + V3_CNT + V4_CNT + V5_CNT + V6_CNT + V7_CNT + V8_CNT;
    variable result : tPorts(0 to max(2, CNT) -1) := (others => NULL_PORT);
    variable index  : natural := 0;
  begin

    --report "merge parameter";
    --report "V1";
    --print(V1);
    --report "V2";
    --print(V2);
    --report "V3";
    --print(V3);
    --report "V4";
    --print(V4);
    --report "V5";
    --print(V5);
    --report "V6";
    --print(V6);
    --report "V7";
    --print(V7);
    --report "V8";
    --print(V8);


    if V1_CNT > 0 then
      result(0 to V1_CNT-1) := V1(0 to V1_CNT-1);
      index := index + V1_CNT;
    end if;
    if V2_CNT > 0 then
      result(index to index+V2_CNT-1) := V2(0 to V2_CNT-1);
      index := index + V2_CNT;
    end if;
    if V3_CNT > 0 then
      result(index to index+V3_CNT-1) := V3(0 to V3_CNT-1);
      index := index + V3_CNT;
    end if;
    if V4_CNT > 0 then
      result(index to index+V4_CNT-1) := V4(0 to V4_CNT-1);
      index := index + V4_CNT;
    end if;
    if V5_CNT > 0 then
      result(index to index+V5_CNT-1) := V5(0 to V5_CNT-1);
      index := index + V5_CNT;
    end if;
    if V6_CNT > 0 then
      result(index to index+V6_CNT-1) := V6(0 to V6_CNT-1);
      index := index + V6_CNT;
    end if;
    if V7_CNT > 0 then
      result(index to index+V7_CNT-1) := V7(0 to V7_CNT-1);
      index := index + V7_CNT;
    end if;
    if V8_CNT > 0 then
      result(index to index+V8_CNT-1) := V8(0 to V8_CNT-1);
      index := index + V8_CNT;
    end if;

    --report "merge result";
    --print(result);

   return result;
  end function merge;

  function merge(V1 : tTrigger_array; V2 : tTrigger_array) return tTrigger_array is
    constant V1_CNT : natural := countTrigger(V1);
    constant V2_CNT : natural := countTrigger(V2);
    constant CNT    : natural := V1_CNT + V2_CNT;
    variable result : tTrigger_array(0 to max(2, CNT) -1) := (others => NULL_TRIGGER);
  begin

    --report "merge tTrigger_array parameter 1";
    --print(V1);
    --report "merge tTrigger_array parameter 2";
    --print(V2);

    result(0 to V1_CNT-1)             := V1(0 to V1_CNT-1);
    result(V1_CNT to V1_CNT+V2_CNT-1) := V2(0 to V2_CNT-1);

    --report "merge result";
    --print(result);

    return result;
  end function merge;

  function append(A : tMessageGens; V : tMessageGen) return tMessageGens is
    variable result : tMessageGens(0 to A'length);
  begin
    result(0 to A'length-1) := A;
    result(A'length)        := V;
    return removeNullValues(result);
  end function append;

  function append(A : tPorts; V : tPort) return tPorts is
    variable result : tPorts(0 to A'length);
  begin
    result(0 to A'length-1) := A;
    result(A'length)        := V;
    return removeNullValues(result);
  end function append;

  function append(A : tTrigger_array; V : tTrigger) return tTrigger_array is
    variable result : tTrigger_array(0 to A'length);
  begin

    result(0 to A'length-1) := A;
    result(A'length)        := V;

    return removeNullValues(result);
  end function append;

  function appendFirst(A : tPorts; V : tPort) return tPorts is
    variable result : tPorts(0 to A'length);
  begin
    result(1 to A'length) := A;
    result(0)             := V;
    return result;
  end function appendFirst;

  function appendFirst(A : tMessageGens; V : tMessageGen) return tMessageGens is
    variable result : tMessageGens(0 to A'length);
  begin
    result(1 to A'length) := A;
    result(0)             := V;
    return result;
  end function appendFirst;

  function slv8ToSlv16(INPUT : tSlv8_array) return tSlv16_array is
    constant size   : positive := divideRoundUp(INPUT'length, 2);
    variable result : tSlv16_array(0 to SIZE-1) := (others => (15 downto 0 => '0'));
  begin

    --report "slv8ToSlv16 parameter";
    --print(INPUT);

    for i in 0 to INPUT'length-1 loop
      if (i mod 2 = 0) then
        result(i/2)(7 downto 0) := INPUT(i);
      else
        result(i/2)(15 downto 8) := INPUT(i);
      end if;
    end loop;

    --report "slv8ToSlv16 result";
    --print(result);

    return result;

  end function slv8ToSlv16;

  --------------------
  -- Enum-Functions --
  --------------------

  function getEnumIndex(V : tComp) return natural is
  begin

    case V is
      when noneC =>
        return 0;
      when diffC =>
        return 1;
      when xorC =>
        return 2;
      when trimC =>
        return 3;
    end case;

  end function getEnumIndex;

  function getEnumIndex(V : tTriggerCmp1) return natural is
  begin

    case V is
      when greaterThan =>
        return 0;
      when equal =>
        return 1;
      when smallerThan =>
        return 2;
    end case;

  end function getEnumIndex;

  function getEnumIndex(V : tTriggerCmp2) return natural is
  begin

    case V is
      when betweenEqualRange =>
        return 0;
      when outsideRange =>
        return 1;
    end case;

  end function getEnumIndex;

  function getEnumIndex(V : tTriggerType) return natural is
  begin

    case V is
      when Normal =>
        return 0;
      when Start =>
        return 1;
      when Stop =>
        return 2;
    end case;

  end function getEnumIndex;

  function getEnumIndex(V : tTriggerMode) return natural is
  begin

    case V is
      when PointTrigger =>
        return 0;
      when PreTrigger =>
        return 1;
      when PostTrigger =>
        return 2;
      when CenterTrigger =>
        return 3;
    end case;

  end function getEnumIndex;

  function getTriggerCmp1Value(INDEX : natural) return tTriggerCmp1 is
  begin

    case INDEX is
      when 0 => return greaterThan;
      when 1 => return equal;
      when others => return smallerThan;
    end case;

  end function getTriggerCmp1Value;

  function getTriggerCmp2Value(INDEX : natural) return tTriggerCmp2 is
  begin

    case INDEX is
      when 0 => return betweenEqualRange;
      when others => return outsideRange;
    end case;

  end function getTriggerCmp2Value;

  function getTriggerTypeValue(INDEX : natural) return tTriggerType is
  begin

    case INDEX is
      when 0 =>
        return Normal;
      when 1 =>
        return Start;
      when others =>
        return Stop;
    end case;

  end function getTriggerTypeValue;

  function getTriggerModeValue(INDEX : natural) return tTriggerMode is
  begin

    case INDEX is
      when 0 =>
        return PointTrigger;
      when 1 =>
        return PreTrigger;
      when 2 =>
        return PostTrigger;
      when others =>
        return CenterTrigger;
    end case;

  end function getTriggerModeValue;

  ----------------------
  -- Print-procedures --
  ----------------------

  procedure print(P : in tPort) is
  begin
    report "Port ID: "&integer'image(P.ID)&" WIDTH: "&integer'image(P.WIDTH)&" INPUTS: "&integer'image(P.INPUTS);
  end procedure print;

  procedure print(PORTS : in tPorts) is
  begin
    report "Ports";
    for i in 0 to PORTS'length-1 loop
      if PRINT_NULL or not isNullPort(PORTS(i)) then
        if PRINT_INDEX then
          report "INDEX "&integer'image(i);
        end if;
        print(PORTS(i));
      end if;
    end loop;
    report "End Ports";
  end procedure print;

  procedure print(PORTS : in tPort2_array) is
  begin
    report "Port2_array";
    for i in 0 to PORTS'length-1 loop
      print(PORTS(i));
    end loop;
    report "End Port2_array";
  end procedure print;

  procedure print(INST_TRACER : in tInstGen) is
  begin
    report "InstTracer";
    report "AdressPort";
    print(INST_TRACER.ADR_PORT);
    report "BranchPort";
    print(INST_TRACER.BRANCH_PORT);
    report "End InstTracer";

  end procedure print;

  procedure print(INST_TRACER_ALL : in tInstGens) is
  begin
    report "InstTracerAll";
    for i in 0 to INST_TRACER_ALL'length-1 loop
      if PRINT_NULL or not isNullTracer(INST_TRACER_ALL(i)) then
        if PRINT_INDEX then
          report "INDEX "&integer'image(i);
        end if;
        print(INST_TRACER_ALL(i));
      end if;
    end loop;
    report "End InstTracerAll";

  end procedure print;

  procedure print(MEM_TRACER : in tMemGen) is
  begin
    report "MemTracer";
    report "AdressPorts";
    print(MEM_TRACER.ADR_PORTS);
    report "DataPort";
    print(MEM_TRACER.DATA_PORT);
    report "SourcePort";
    print(MEM_TRACER.SOURCE_PORT);
    report "RwPort";
    print(MEM_TRACER.RW_PORT);
    report "End MemTracer";

  end procedure print;

  procedure print(MEM_TRACER_ALL : in tMemGens) is
  begin
    report "MemTracerAll";
    for i in 0 to MEM_TRACER_ALL'length-1 loop
      if PRINT_NULL or not isNullTracer(MEM_TRACER_ALL(i)) then
        if PRINT_INDEX then
          report "INDEX "&integer'image(i);
        end if;
        print(MEM_TRACER_ALL(i));
      end if;
    end loop;
    report "End MemTracerAll";

  end procedure print;


  procedure print(MESSAGE_TRACER : in tMessageGen) is
  begin
    report "MessageTracer";
    print(MESSAGE_TRACER.MSG_PORTS);
    print(MESSAGE_TRACER.TRIGGER);
    report "End MessageTracer";

  end procedure print;

  procedure print(MESSAGE_TRACER_ALL : in tMessageGens) is
  begin
    report "MessageTracerAll";
    for i in 0 to MESSAGE_TRACER_ALL'length-1 loop
      if PRINT_NULL or not isNullTracer(MESSAGE_TRACER_ALL(i)) then
        if PRINT_INDEX then
          report "INDEX "&integer'image(i);
        end if;
        print(MESSAGE_TRACER_ALL(i));
      end if;
    end loop;
    report "End MessageTracerAll";

  end procedure print;

  procedure print(NAT_ARRAY : in tNat_array) is
  begin
    report "NatArray LENGTH "&integer'image(NAT_ARRAY'length);
    for i in 0 to NAT_ARRAY'length-1 loop
      report integer'image(NAT_ARRAY(i));
    end loop;
    report "End NatArray";

  end procedure print;

  procedure print(PRIO_ARRAY : in tPrio_array) is
  begin
    report "PrioArray";
    for i in 0 to PRIO_ARRAY'length-1 loop
      report integer'image(PRIO_ARRAY(i));
    end loop;
    report "End PrioArray";

  end procedure print;

  procedure print(INPUT : in tSlv8_array) is
  begin
    report "Slv8Array";
    for i in 0 to INPUT'length-1 loop
      report integer'image(to_integer(unsigned(INPUT(i))));
    end loop;
    report "End Slv8Array";

  end procedure print;

  procedure print(INPUT : in tSlv16_array) is
  begin
    report "Slv16Array";
    for i in 0 to INPUT'length-1 loop
      report integer'image(to_integer(unsigned(INPUT(i)(15 downto 8)))) & " " &
             integer'image(to_integer(unsigned(INPUT(i)(7 downto 0))));
    end loop;
    report "End Slv16Array";

  end procedure print;

  procedure print(TRIGGER_ARRAY : in tTrigger_array) is
  begin
    report "TriggerArray";
    for i in 0 to TRIGGER_ARRAY'length-1 loop
      if PRINT_NULL or not isNullTrigger(TRIGGER_ARRAY(i)) then
        if PRINT_INDEX then
          report "INDEX "&integer'image(i);
        end if;
        print(TRIGGER_ARRAY(i));
      end if;
    end loop;
    report "End TriggerArray";
  end procedure print;

  procedure print(TRIGGER : in tTrigger) is
  begin
    report "Trigger";
    report "ID "&integer'image(TRIGGER.ID);
    report "SingleEvent-Ids";
    print(TRIGGER.SINGLE_EVENT_IDS);
    report "End SingleEvent-Ids";
    print(TRIGGER.COMPLEX_EVENTS);
    report "End Trigger";
  end procedure print;

  procedure print(COMPLEX_EVENTS : in tComplexEvent_array) is
  begin
    report "ComplexEventArray";
    for i in 0 to COMPLEX_EVENTS'length-1 loop
      if PRINT_NULL or not isNullComplexEvent(COMPLEX_EVENTS(i)) then
        if PRINT_INDEX then
          report "INDEX "&integer'image(i);
        end if;
        print(COMPLEX_EVENTS(i));
      end if;
    end loop;
    report "End ComplexEventArray";
  end procedure print;

  procedure print(SINGLE_EVENTS : in tSingleEvent_array) is
  begin
    report "SingleEventArray";
    for i in 0 to SINGLE_EVENTS'length-1 loop
      if PRINT_NULL or not isNullSingleEvent(SINGLE_EVENTS(i)) then
        if PRINT_INDEX then
          report "INDEX "&integer'image(i);
        end if;
        print(SINGLE_EVENTS(i));
      end if;
    end loop;
    report "End SingleEventArray";
  end procedure print;

  procedure print(SINGLE_EVENT : in tSingleEvent) is
  begin
    report "SingleEvent";
    report "ID "&integer'image(SINGLE_EVENT.ID);
    report "LEVEL_OR "&boolean'image(SINGLE_EVENT.LEVEL_OR);
    report "TWO_REGS "&boolean'image(SINGLE_EVENT.TWO_REGS);
    report "REG1_INIT "&integer'image(to_integer(unsigned(SINGLE_EVENT.REG1_INIT(23 downto 0))));
    report "REG2_INIT "&integer'image(to_integer(unsigned(SINGLE_EVENT.REG2_INIT(23 downto 0))));
    print(SINGLE_EVENT.PORT_IN);
    report "End SingleEvent";
  end procedure print;

end trace_functions;
