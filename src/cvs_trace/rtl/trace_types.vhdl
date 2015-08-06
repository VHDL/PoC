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
-- Package: trace_types
-- Author(s): Stefan Alex
-- 
-- Types for Configuration
--
-- Revision:    $Revision: 1.2 $
-- Last change: $Date: 2010-04-23 06:37:38 $
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package trace_types is

  -- see Trace.vhdl for additional types

  constant MESSAGE_PORTS_PER_INSTANCE : positive := 3;
  constant MEM_ADR_PORTS_PER_INSTANCE : positive := 2;
  constant MAX_PORTS                  : positive := 255;
  constant MAX_PORTS_PER_TRACER       : positive := 5;
  constant MAX_PORT_WIDTH             : positive := 64;
  constant MAX_SINGLE_EVENTS          : positive := 5;
  constant MAX_COMPLEX_EVENTS         : positive := 2;
  constant MAX_TRIGGER                : positive := 2;

  -------------------
  -- general types --
  -------------------

  type tComp             is (NoneC, DiffC, XorC, TrimC);
  type tOvDangerReaction is (FilterDataTrace, SystemStall, None);

  subtype tPortWidth is integer range 1   to MAX_PORT_WIDTH;
  subtype tPrio      is integer range 0   to 10; -- 10 is highest priority
  subtype t1To8Int   is integer range 1   to 8;
  subtype tRatio     is real    range 0.0 to 1.0;
  subtype tBitPtr    is integer range 0   to 7;
  subtype tGr1Int    is integer range 0   to integer'high;

  type tNat_array    is array(natural range<>) of natural;
  type tPos_array    is array(natural range<>) of natural;
  type tBool_array   is array(natural range<>) of boolean;
  type tComp_array   is array(natural range<>) of tComp;
  type tSlv8_array   is array(natural range<>) of std_logic_vector(7 downto 0);
  type tSlv16_array  is array(natural range<>) of std_logic_vector(15 downto 0);
  type tSlv256_array is array(natural range<>) of std_logic_vector(255 downto 0);
  type tPrio_array   is array(natural range<>) of tPrio;

  -----------
  -- ports --
  -----------

  type tPort is
    record
      ID           : natural;    -- the port's identification
      WIDTH        : tPortWidth; -- bit-width
      INPUTS       : positive;   -- input-vectors (for multi-core) (if 0, port is not instantiated)
      COMP         : tComp;      -- compression
    end record;

  type tPorts       is array(natural range<>) of tPort;
  type tPort2_array is array(natural range<>) of tPorts(0 to MAX_PORTS_PER_TRACER-1);

  constant NULL_PORT : tPort := (ID     => 0,
                                 WIDTH  => 1,
                                 INPUTS => 1,
                                 COMP   => noneC);

  constant NULL_PORTS        : tPorts := (0 to MAX_PORTS_PER_TRACER-1 => NULL_PORT);

  -------------------
  -- trigger types --
  -------------------

  type tTriggerCmp1 is (greaterThan, equal, smallerThan);
  type tTriggerCmp2 is (betweenEqualRange, outsideRange);

  type tTriggerType is (Normal, Start, Stop);
  type tTriggerMode is (PointTrigger, PreTrigger, PostTrigger, CenterTrigger);

  type tTriggerType_array is array(natural range <>) of tTriggerType;
  type tTriggerMode_array is array(natural range <>) of tTriggerMode;

  -- user types

  type tSingleEvent is
    record
      ID        : natural;
      PORT_IN   : tPort;
      TWO_REGS  : boolean;
      LEVEL_OR  : boolean;
      REG1_INIT : std_logic_vector(MAX_PORT_WIDTH-1 downto 0);
      REG2_INIT : std_logic_vector(MAX_PORT_WIDTH-1 downto 0);
      CMP1_INIT : tTriggerCmp1;
      CMP2_INIT : tTriggerCmp2;
  end record;

  type tSingleEvent_array is array(natural range<>) of tSingleEvent;
  type tComplexEvent_array is array(natural range<>) of tNat_array(0 to MAX_SINGLE_EVENTS-1);
  
  type tTrigger is
    record
      ID               : natural;
      SINGLE_EVENT_IDS : tNat_array(0 to MAX_SINGLE_EVENTS-1);
      COMPLEX_EVENTS   : tComplexEvent_array(0 to MAX_COMPLEX_EVENTS-1);
      TYPE_INIT        : tTriggerType;
      MODE_INIT        : tTriggerMode;
    end record;
    
  type tTrigger_array is array(natural range<>) of tTrigger;

  -- null-values

  constant NULL_SINGLE_EVENT     : tSingleEvent := (ID        => 0,
                                                    PORT_IN   => NULL_PORT,
                                                    TWO_REGS  => false,
                                                    LEVEL_OR  => false,
                                                    REG1_INIT => (others => '0'),
                                                    REG2_INIT => (others => '0'),
                                                    CMP1_INIT => greaterThan,
                                                    CMP2_INIT => betweenEqualRange);
 
  constant NULL_SINGLE_EVENTS    : tSingleEvent_array
                                 := (0 to MAX_SINGLE_EVENTS-1 => NULL_SINGLE_EVENT);

  constant NULL_SINGLE_EVENT_IDS : tNat_array
                                 := (0 to MAX_SINGLE_EVENTS-1 => 0);

  constant NULL_COMPLEX_EVENTS   : tComplexEvent_array
                                 := (0 to MAX_COMPLEX_EVENTS-1 => NULL_SINGLE_EVENT_IDS);

  constant NULL_TRIGGER          : tTrigger := (ID               => 0,
                                                SINGLE_EVENT_IDS => NULL_SINGLE_EVENT_IDS,                                                
                                                COMPLEX_EVENTS   => NULL_COMPLEX_EVENTS,
                                                TYPE_INIT        => normal,
                                                MODE_INIT        => PointTrigger);
                                                
  constant NULL_TRIGGERS         : tTrigger_array := (0 to MAX_TRIGGER-1 => NULL_TRIGGER);

  constant NULL_TRIGGER_IDS      : tNat_array(0 to MAX_TRIGGER-1) := (others => 0);
  
  ------------
  -- tracer --
  ------------

  type tInstGen is
    record
      ADR_PORT      : tPort;    -- adress-port     
      BRANCH_PORT   : tPort;    -- infer branchs
      COUNTER_BITS  : positive; -- instruction-counter-bits
      HISTORY_BYTES : natural;  -- use history-encoding
      LS_ENCODING   : boolean;  -- use ls-encoding for history
      FIFO_DEPTH    : positive;
      FIFO_SDS      : positive; -- safe-distance
      PRIORITY      : tPrio;    -- priority
      TRIGGER       : tNat_array(0 to MAX_TRIGGER-1); -- trigger-generation
      INSTANTIATE   : boolean;  -- instantiate component
    end record;

  type tMemGen is
    record
      ADR_PORTS   : tPorts(0 to MEM_ADR_PORTS_PER_INSTANCE-1); -- adress-ports
      DATA_PORT   : tPort;    -- data-port
      SOURCE_PORT : tPort;    -- source-port
      RW_PORT     : tPort;    -- read-write-port
      COLLECT_VAL : boolean;  -- only transmit, when last adress and data are present
      FIFO_DEPTH  : positive;
      FIFO_SDS    : positive; -- safe-distance
      PRIORITY    : tPrio;    -- priority
      TRIGGER     : tNat_array(0 to MAX_TRIGGER-1); -- trigger-generation
      INSTANTIATE : boolean;  -- instantiate component
    end record;

  type tMessageGen is
    record
      MSG_PORTS   : tPorts(0 to MESSAGE_PORTS_PER_INSTANCE-1); -- message-port
      FIFO_DEPTH  : positive;                          -- depth for fifo
      FIFO_SDS    : positive;                          -- safe-distance for fifo
      RESYNC      : boolean;                           -- retransfer after sync is lost
      PRIORITY    : tPrio;                             -- priority
      TRIGGER     : tNat_array(0 to MAX_TRIGGER-1);    -- trigger-generation
      INSTANTIATE : boolean;                           -- instantiate component
    end record;

  type tInstGens      is array(natural range<>) of tInstGen;
  type tMemGens       is array(natural range<>) of tMemGen;
  type tMessageGens   is array(natural range<>) of tMessageGen;

  -- constants
  constant NULL_INST_TRACER : tInstGen := (ADR_PORT      => NULL_PORT,
                                           BRANCH_PORT   => NULL_PORT,
                                           COUNTER_BITS  => 1,
                                           HISTORY_BYTES => 0,
                                           LS_ENCODING   => false,
                                           FIFO_DEPTH    => 1,
                                           FIFO_SDS      => 1,
                                           PRIORITY      => 10,
                                           TRIGGER       => NULL_TRIGGER_IDS,
                                           INSTANTIATE   => false);

  constant NULL_MEM_TRACER : tMemGen := (ADR_PORTS   => (0 to MEM_ADR_PORTS_PER_INSTANCE-1 => NULL_PORT),
                                         DATA_PORT   => NULL_PORT,
                                         SOURCE_PORT => NULL_PORT,
                                         RW_PORT     => NULL_PORT,
                                         COLLECT_VAL => false,
                                         FIFO_DEPTH  => 1,
                                         FIFO_SDS    => 1,
                                         PRIORITY    => 10,
                                         TRIGGER     => NULL_TRIGGER_IDS,
                                         INSTANTIATE => false);

  constant NULL_MESSAGE_TRACER : tMessageGen := (MSG_PORTS   => (0 to MESSAGE_PORTS_PER_INSTANCE-1 => NULL_PORT),
                                                 FIFO_DEPTH  => 1,
                                                 FIFO_SDS    => 1,
                                                 RESYNC      => true,
                                                 PRIORITY    => 5,
                                                 TRIGGER     => NULL_TRIGGER_IDS,
                                                 INSTANTIATE => false);


end trace_types;

package body trace_types is
end trace_types;
