.. _IP/axi4lite_Register:

axi4lite_Register
#################

This issue documents the functionality and usage of the ``AXI4Lite_Register`` module located at `src\bus\axi4\AXI4Lite\AXI4Lite_Register.vhdl`.

Overview
********

The ``AXI4Lite-Register`` is a generic implementation of a register interface for access of software via the AXI4Lite protocol. It uses a ``Config`` record vector to describe the registers. It was designed to work for all purposes as `Eierlegende Wollmilchsau`.

Interface
*********
The interface of the PL-side is named from the PL point-of-view, the configuration is named from the software point-of-view!

Generics
========

``CONFIG``
----------

:Name:          ``CONFIG``
:Type:          ``AXI4Lite:T_AXI4_Register_Description_Vector``
:Default Value: — — — —
:Description:   This generic holds the Register-Configuration. |br|
                See :ref:`todo`

``INTERRUPT_IS_STROBE``
-----------------------

:Name:          ``INTERRUPT_IS_STROBE``
:Type:          ``boolean``
:Default Value: ``true``
:Description:   With this generic, it can be selected if the Interrupt-pin should through an interrupt as ``Strobe`` or
                ``Value``. By selecting ``Strobe``, the module will block a new interrupt until the
                ``INTERRUPT_MATCH_REGISTER``is read out.

``INTERRUPT_ENABLE_REGISTER_ADDRESS``
-------------------------------------

:Name:          ``INTERRUPT_ENABLE_REGISTER_ADDRESS``
:Type:          ``unsigned``
:Default Value: ``x"00"``
:Description:   If Interrupts are used, this generic selects the address of the internal ``INTERRUPT_ENABLE_REGISTER``.

``INTERRUPT_MATCH_REGISTER_ADDRESS``
------------------------------------

:Name:          ``INTERRUPT_MATCH_REGISTER_ADDRESS``
:Type:          ``unsigned``
:Default Value: ``x"04"``
:Description:   If Interrupts are used, this generic selects the address of the internal ``INTERRUPT_MATCH_REGISTER``.

``INIT_ON_RESET``
-----------------

:Name:          ``INIT_ON_RESET``
:Type:          ``boolean``
:Default Value: ``true``
:Description:   The Init-value of the registers, that is set by the ``Config``, is set by default with the Reset. This
                can be disabled here. This helps with reducing control-sets and therefore helps by CLB utilization.

``IGNORE_HIGH_ADDRESS``
-----------------------

:Name:          ``IGNORE_HIGH_ADDRESS``
:Type:          ``boolean``
:Default Value: ``true``
:Description:   The module will calculate based on the configuration how many bits are needed to address every specified
                register. If this generic is set, it will ignore every bit which is coming after the needed address-bits.
                These bits are considered as base address. By setting this value, you can pass the full 40/32bit from
                Zynq, and it will filter out the base address for it.

``RESPONSE_ON_ERROR``
---------------------

:Name:          ``RESPONSE_ON_ERROR``
:Type:          ``AXI4Lite:T_AXI4_Response``
:Default Value: ``C_AXI4_RESPONSE_DECODE_ERROR``
:Possible Values: ``C_AXI4_RESPONSE_OKAY``, ``C_AXI4_RESPONSE_EX_OKAY``, ``C_AXI4_RESPONSE_SLAVE_ERROR`` or ``C_AXI4_RESPONSE_DECODE_ERROR``
:Description:   With this generic can be selected which response code should be sent out if an address is accessed that
                is not handled by ``Config``.

``DISABLE_ADDRESS_CHECK``
-------------------------

:Name:          ``DISABLE_ADDRESS_CHECK``
:Type:          ``boolean``
:Default Value: ``false``
:Description:   The module is internally calculating if any registers have overlapping addresses and will create an
                error if so. This check takes a bit of synthesis time that depends on the size of ``Config``. This check
                can be disabled.

                .. attention:: This is not recommended!

``VERBOSE``
-----------

:Name:          ``VERBOSE``
:Type:          ``boolean``
:Default Value: ``false``
:Description:   If set to true, the module will print the configuration and settings into the synthesis-log with
                ``assert``.

:Description:   If set to true, the module sets specific internal signals as mark-debug. These signals are the
                hit-vectors, decoded addresses, and interrupt signals.


Ports
=====

``Clock``
---------

:Name:          ``Clock``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   Clock

``Reset``
---------

:Name:          ``Reset``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   synchronous high-active reset

``AXI4Lite_m2s``
----------------

:Name:          ``AXI4Lite_m2s``
:Type:          ``axi4lite.T_AXI4Lite_BUS_M2S``
:Mode:          in
:Default Value: — — — —
:Description:   AXI4-Lite manager to subordinate signals.

``AXI4Lite_s2m``
----------------

:Name:          ``AXI4Lite_s2m``
:Type:          ``axi4lite.T_AXI4Lite_BUS_S2M``
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.

``AXI4Lite_irq``
----------------

:Name:          ``AXI4Lite_irq``
:Type:          ``std_logic``
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite interrupt request. |br|
                Functionality depends on configured generics.

``RegisterFile_ReadPort``
-------------------------

:Name:          ``RegisterFile_ReadPort``
:Type:          ``T_SLVV(0 to CONFIG'length - 1)(31 downto 0)``
:Mode:          out
:Default Value: — — — —
:Description:   Read-Port for register values (to fabric). |br|
                An array of 32-bit words; one 32-bit word per register.

``RegisterFile_ReadPort_hit``
-----------------------------

:Name:          ``RegisterFile_ReadPort_hit``
:Type:          ``std_logic_vector(0 to CONFIG'length - 1)``
:Mode:          out
:Default Value: — — — —
:Description:   Hit-vector to fabric. A bit is asserted if the a AXI4-Lite manager has written a specific register and
                therefore changed the value in the corresponding register.

``RegisterFile_WritePort``
--------------------------

:Name:          ``RegisterFile_WritePort``
:Type:          ``T_SLVV(0 to CONFIG'length - 1)(31 downto 0)``
:Mode:          in
:Default Value: — — — —
:Description:   Write-Port for register values (from fabric). |br|
                An array of 32-bit words; one 32-bit word per register.

``RegisterFile_WritePort_hit``
------------------------------

:Name:          ``RegisterFile_WritePort_hit``
:Type:          ``std_logic_vector(0 to CONFIG'length - 1)``
:Mode:          out
:Default Value: — — — —
:Description:   Hit-vector to fabric. A bit is asserted if the a AXI4-Lite manager has read a specific register and
                therefore fetched the value in the corresponding register.

``RegisterFile_WritePort_strobe``
---------------------------------

:Name:          ``RegisterFile_WritePort_strobe``
:Type:          ``std_logic_vector(0 to CONFIG'length - 1)``
:Mode:          in
:Default Value: — — — —
:Description:   By asserting a bit to ``'1'``, the corresponding value at ``RegisterFile_WritePort`` is captured into
                the corresponding register. |br|
                The default value is set by the function ``get_strobeVector(CONFIG)``.

                .. todo:: Overwrite is mostly needed if ``rw_config`` is set to `readWriteable`.

Configuration
*************

The configuration specified via ``Config`` generic determines the functionality of the register. It's an array of the
``AXI4Lite.pkg:T_AXI4_Register_Description``. This record has the following elements:

+-----------------------+-------------------------------+--------------------------------------------------------------+
| Field                 | Type                          | Description                                                  |
+=======================+===============================+==============================================================+
| Name                  | string(1 to 64)               | A Name as string can be selected for this register.          |
+-----------------------+-------------------------------+--------------------------------------------------------------+
| Address               | unsigned(31 downto 0)         | The Address of this register.                                |
+-----------------------+-------------------------------+--------------------------------------------------------------+
| rw_config             | T_ReadWrite_Config            | See chapter ``Register Mode (ReadWrite-Config)``             |
+-----------------------+-------------------------------+--------------------------------------------------------------+
| Init_Value            | std_logic_vector(31 downto 0) | The initial value after reset or boot-up of the register.    |
+-----------------------+-------------------------------+--------------------------------------------------------------+
| Auto_Clear_Mask       | std_logic_vector(31 downto 0) | Auto-clear-mask if rw_config is `readWriteable`. Bits set in |
|                       |                               | this maks are given out only as a strobe and cleared with the|
|                       |                               | next clock-cycle.                                            |
+-----------------------+-------------------------------+--------------------------------------------------------------+
| Is_Interrupt_Register | boolean                       | Selects if this register can create and interrupt or not.    |
|                       |                               | See section `Interrupt`.                                     |
+-----------------------+-------------------------------+--------------------------------------------------------------+

Register Mode (ReadWrite-Config)
================================

For each register, a mode can be selected with the field `rw_config`. This mode depends on the functionality that should
be achieved. Possible modes are:

+---------------------------+------------+
| Mode                      | Used for | Description |
+===========================+
| constant_fromInit         | constant       | This Mode connects the ``Init_Value`` directly to the read-mux. No Flip-Flop is created and the Read and Write Port is unconnected. |
| readable                  | Read-only-Reg  | This Mode is used to provide a Status register. |
| readable_non_reg          | Read-only-Reg  | As ``readable`` but does not create flip-flops internally. The WritePort is directly connected to the read-mux. Can be used if data is already driven by registers or if path is not time-critical. |
| readWriteable             | Read-Write-Reg | This Mode can be used to configure or control the PL form SW. Software can write into this register, and it will be visible through `RegisterFile_ReadPort`. The PL can also overwrite the Value by setting the corresponding bit in port `RegisterFile_WritePort_strobe`. In this mode, the field ``Auto_Clear_Mask`` is active. It can be used to control FSM's with a command, that is set only for one CC. |
| readWriteable_non_reg     | Special        | This mode is used only for special use-cases. It provides the internal read- and write-mux connections directly to the ports, so any external functionality can be implemented. **Data on the ``RegisterFile_ReadPort`` is only valid if ``RegisterFile_WritePort_strobe`` is set!** See also chapter `Special Functionality`. |
| latchValue_clearOnRead    | Status/Error   | ``Interrupt Capable`` After Reset or boot-up, this latch is cleared and can accept new data. If Stobe is then set, the data from ``RegisterFile_WritePort`` is saved. If this value is unequal to `Init_Value`, the value can not be overwritten until the SW reads it out. If latching condition is met and register is set as `Is_Interrupt_Register`, and interrupt is thrown. |
| latchValue_clearOnWrite   | Status/Error   | ``Interrupt Capable`` Same as `latchValue_clearOnRead`, but it is only cleared by actively writing into this register. The written value is ignored. |
| latchHighBit_clearOnRead  | Status/Error   | ``Interrupt Capable`` By setting `Strobe`, the value of ``RegisterFile_WritePort`` is logically or-red together with the current register content. So a one-bit is always added to the value. By reading this register out, the software gets the value and clears it as well. |
| latchHighBit_clearOnWrite | Status/Error   | ``Interrupt Capable`` Same as `latchHighBit_clearOnRead `, but it is only cleared  by actively writing into this register. The written value is ignored. |
| latchLowBit_clearOnRead   | Status/Error   | ``Interrupt Capable`` For low-active signals. By setting `Strobe`, the value of ``RegisterFile_WritePort`` is logically and-ed together with the current register content. So a zero-bit is always added to the value. By reading this register out, the software gets the value and sets all bits as well. |
| latchLowBit_clearOnWrite  | Status/Error   | ``Interrupt Capable`` Same as `latchLowBit_clearOnRead `, but it is only cleared  by actively writing into this register. The written value is ignored. |

Usage
*****

Instantiation
=============

A minimal config with instance can look like this:

.. code-block:: vhdl

   my_Reg_blk : block
      constant CONFIG                              : T_AXI4_Register_Description_Vector := gen_config;

      signal RegisterFile_ReadPort             : T_SLVV(0 to CONFIG'Length - 1)(31 downto 0);
      --signal RegisterFile_ReadPort_hit         : std_logic_vector(0 to CONFIG'Length - 1);
      signal RegisterFile_WritePort            : T_SLVV(0 to CONFIG'Length - 1)(31 downto 0);
      --signal RegisterFile_WritePort_hit        : std_logic_vector(0 to CONFIG'Length - 1);
      --signal RegisterFile_WritePort_strobe     : std_logic_vector(0 to CONFIG'Length - 1) := get_strobeVector(CONFIG);
   begin

      Reg : entity PoC.AXI4Lite_Register
      generic map(
         CONFIG                            => (
            0 => to_AXI4_Register_Description(Address => 32x"0", rw_config => readWriteable),
            1 => to_AXI4_Register_Description(Address => 32x"4", rw_config => readable),
         )
      )
      port map(
         S_AXI_ACLK                        => Clock,
         S_AXI_ARESETN                     => not Reset,

         S_AXI_m2s                         => M00_AXI4L_m2s,
         S_AXI_s2m                         => M00_AXI4L_s2m,
         S_AXI_IRQ                         => open,

         RegisterFile_ReadPort             => RegisterFile_ReadPort        ,
         --RegisterFile_ReadPort_hit         => RegisterFile_ReadPort_hit    ,
         RegisterFile_WritePort            => RegisterFile_WritePort
         --RegisterFile_WritePort_hit        => RegisterFile_WritePort_hit,
         --RegisterFile_WritePort_strobe     => RegisterFile_WritePort_strobe
      );


For the basic usage, only the ``RegisterFile_ReadPort`` and ``RegisterFile_WritePort`` is needed.

Read to PL can be acheaved like this:
.. code-block:: vhdl

   my_slv_32_signal            <= RegisterFile_ReadPort(0);


To write into the register, this is enough:
.. code-block:: vhdl

   RegisterFile_WritePort(1)   <= my_slv_32_status;


Creation of Config
==================

The configuration can be created in many different ways. If the register is small, it can be done like above by directly setting the register in the generic. This approach has the disadvantage that the index of the read and write port is changing if an register is added later. This can easily create errors inside the design, if not each and every index is checked and updated if needed. This is why this approach **is not recomanded**.

The next step is to save the Config inside a constant. If done like this, the register can also use the `Name`-field. If all register are named, the index of the register can be calculated by helper-functions with its specific name (See next section `Helper Functions`). This helps to prevent from errors and allows easily to extend the register because the index is calculated new and updated apropriate. This approach is only suatable for mid-complex registers.


.. code-block:: vhdl

   function gen_config return T_AXI4_Register_Description_Vector is
      variable temp : T_AXI4_Register_Description_Vector(0 to 511);
      variable addr : natural := 0;
      variable pos  : natural := 0;
   begin
      temp(pos) := to_AXI4_Register_Description(Name => "System.Version", Address => to_unsigned(addr, 32), Init_Value => std_logic_vector(to_unsigned(3, 32)), rw_config => constant_fromInit);
      addr := addr +4; pos  := pos +1;
      temp(pos) := to_AXI4_Register_Description(Name => "System.Status",Address => to_unsigned(addr, 32), rw_config => readable);
      addr := addr +4; pos  := pos +1;

      addr := 256;
      temp(pos) := to_AXI4_Register_Description(Name => "System.Command",Address => to_unsigned(addr, 32), rw_config => readWriteable, Auto_Clear_Mask => x"FFFFFFFF");
      addr := addr +4; pos  := pos +1;
      return temp(0 to pos -1);
   end function;

   constant CONFIG                              : T_AXI4_Register_Description_Vector := gen_config;


This example configuration creates a total of three registers. After one register is created the index/position is incremented by one and the address by 4. The addresses are adapting automatically. As can be seen, the third register is shifted to address 0x100 by overwriting the addr variable. This creates an empty space between 0x4 and 0x100, which is creating a ``RESPONSE_ON_ERROR`` code while read or write access.

In this function registers can be created also as a loop:
.. code-block:: vhdl

	for i in 0 to Num_RTT -1 loop
		temp(pos) := to_AXI4_Register_Description(Name => "Data_Value(" & integer'image(i) & ")", Address => to_unsigned(addr, 32), rw_config => readable);
		pos := pos +1; addr := addr +4;
	end loop;

By giving each loop-register a different name dependent on the constant `i`, it can be refferenzed separately.

Helper Functions
================

For ease of use, functions are created to help for basic modifications of the configuration.
filter_Register_Description_Vector
----------------------------------

.. code-block:: vhdl

   function filter_Register_Description_Vector(str : string; description_vector : T_AXI4_Register_Description_Vector) return T_AXI4_Register_Description_Vector;

Removes all elements of ``description_vector`` where `description_vector(i).name(str'range) /= str`.

.. code-block:: vhdl

   function filter_Register_Description_Vector(char : character; description_vector : T_AXI4_Register_Description_Vector) return T_AXI4_Register_Description_Vector

Removes all elements of ``description_vector`` where `description_vector(i).name(1) /= char`.

add_Prefix
----------

.. code-block:: vhdl

   function add_Prefix(prefix : string; Config : T_AXI4_Register_Description_Vector; offset : unsigned(Address_Width -1 downto 0) := (others => '0')) return T_AXI4_Register_Description_Vector;

Adds the string prefix ``prefix`` to each Config(x).Name and adds the ``offset`` value to the Config(x).Address. This function can be used if multiple standerdized (as constant) register need to be put with a prefix into the big register. Here is an example:

.. code-block:: vhdl

   constant Config_Packetizer : T_AXI4_Register_Description_Vector := (
      0 => to_AXI4_Register_Description(Name => "CMD", Address => to_unsigned(0, 32), rw_config => readWriteable)
      1 => to_AXI4_Register_Description(Name => "CMD2", Address => to_unsigned(4, 32), rw_config => readWriteable)
      2 => to_AXI4_Register_Description(Name => "STATUS", Address => to_unsigned(8, 32), rw_config => readable));

   function gen_config return T_AXI4_Register_Description_Vector is
      variable temp : T_AXI4_Register_Description_Vector(0 to 511);
      variable addr : natural := 0;
      variable pos  : natural := 0;
   begin
      for i in 0 to 1 loop
         temp(pos to pos + Config_Packetizer'length -1) := add_prefix("Packetizer(" & integer'image(i) & ").", Config_Packetizer, to_unsigned(addr, 32));
         pos := pos   + Config_Packetizer'length;
         addr := addr + Config_Packetizer'length *4;
      end loop;
      return temp(0 to pos -1);
   end function;


This will result in a config that looks like this:

.. code-block:: vhdl

   0 => (Name => "Packetizer(0).CMD",    Address => 32x"0",  rw_config => readWriteable),
   1 => (Name => "Packetizer(0).CMD2",   Address => 32x"4",  rw_config => readWriteable),
   2 => (Name => "Packetizer(0).STATUS", Address => 32x"8",  rw_config => readable),
   3 => (Name => "Packetizer(1).CMD",    Address => 32x"C",  rw_config => readWriteable),
   4 => (Name => "Packetizer(1).CMD2",   Address => 32x"10", rw_config => readWriteable),
   5 => (Name => "Packetizer(1).STATUS", Address => 32x"14", rw_config => readable),


to_AXI4_Register_Description
----------------------------

{-TODO-}

get_addresses
-------------
{-TODO-}

get_InitValue
-------------
{-TODO-}

get_AutoClearMask
-----------------
{-TODO-}

get_index
---------
{-TODO-}

get_NumberOfIndexes
-------------------
{-TODO-}

get_indexRange
--------------
{-TODO-}

get_Address
-----------
{-TODO-}

get_Name
--------
{-TODO-}

get_strobeVector
----------------
{-TODO-}

## Write Register CSV File
A csv file can be written out of the configuration with the function `write_csv_file`. It is recomanded to use it with an enabled ``assert`` statement or writing it into a constant. With assert, you can also see in the synthesis log if everithing was successfull. ``PROJECT_DIR`` is a constant inside ``my_project.vhdl`` normaly located at `src/PoC/`.

.. code-block:: vhdl

   constant success : boolean := write_csv_file(PROJECT_DIR & "gen/Sampling_Register.csv", config);
   --or--
   assert write_csv_file(PROJECT_DIR & "gen/Sampling_Register.csv", config) report "Error in writing csv-File!" severity warning;


## Create C-Header File from CSV
A big advantage of this register is the automatic register handover to the Software. This is done by converting the freshly generaded csv file and converting it into a C-Header file. The registers specified in the config are combined into struct's. The final struct can than be layed over the AXI4Lite-Register Address.

The conversion is done by a python-script from `git@gitlab.plc2.de:PLC2Design/Tools/Vivado-PostProcessing/c-header-csv-register-parser.git`. This python script works but has currently a lot of limitations. **It is planed to extend this script and make it accessable to the CI-Runners for automatic conversions.**


## Naming of Registers
The Name field of the configuration is limmited to 64-characters. This needs to be a constant and was defined like this. The conversion to the C-Header file needs some properties to work. These properties are therefore defined gloabaly.

1. Each register needs to be named.
1. Eacht register needs to have a unique name.
1. The Addresses should monotonically increasing (Only for C-Header File).
1. Multiple Registers can be grouped together with a prefix. The prefix is separated by a dot.
1. ~~Multiple Prefixes can be made~~ {-This is currently not possible with the script.-}
1. A array of registers can be defined with parenthesis `(i)`. This will create and array in C-Header file.
1. ~~A array can be done as well on prefixes~~ {-This is currently not possible with the script.-}

Special Functionality
*********************

64-bit Mode
===========
The register has a 64-bit mode. If the Data-Size of the AXI4Lite record is 64-bit wide, the AXI4Lite-Register will automatically put into 64-bit mode. The SW can then write 64-bit alligned into two 32-bit register at once.


**IMPORTANT NOTE: The definition in the config is still done with 32-bit registers. Two 32-bit register are combined to one 64-bit register. The read and write is done in the same CC and is consistant. Note that two Hits will be set for both 32-bit register. If the software is making a read_32 it is not possible to know from PL which of these two registers was actually read out (or written to).**

## Interrupt
The ``AXI4Lite-Register`` is capable of creating interrupts. The ``rw_config`` needs to be a latch type to be interrupt capable (See section Register Mode (ReadWrite-Config)). In total, 32 registers can be set as interrupt register. This limitation is due to the ``interrupt match register`` width of 32 bits. If an interrupt register is latched, the interrupt is thrown. If the software registers an interrupt, it needs to read out the ``interrupt match register`` to figure out which interrupt occured. The order of the  bits here is equal to the order of the interrupt registers in the config.

E.g:
```
Config(i) ; Name ; Address ; Init_Value ; Auto_Clear_Mask ; rw_config ; Is_Interrupt_Register
0 ; System.Version ; 0x00000000 ; 0x00000003 ; 0x00000000 ; constant_fromInit ; false
1 ; System.Test; 0x00000004 ; 0x00000000 ; 0x00000000 ; latchLowBit_clearOnRead ; true
2 ; System.Command ; 0x00000028 ; 0x00000000 ; 0xFFFFFFFF ; readWriteable ; false
3 ; System.Status ; 0x0000002C ; 0x00000000 ; 0x00000000 ; latchLowBit_clearOnRead ; true
```
This configuration will create in total four registers of which two are interrupt registers. The ``interrupt match register`` bit zero is mapped to `System.Test`, bit one is mapped to `System.Status`. If one of these bits is set, the SW needs to look into the correct address for the value. This means, if after an interrupt bit zero is set from in the `interrupt match register`, the SW needs to read address ``0x00000004`` afterwards to get the interrupt-causing-value and clear the interrupt reason.

Beside the `interrupt match register`, there is also the `Interrupt enable register`. With this, you can switch on and off one specific register to through interrupts. The bit will still be set inside `interrupt match register`, but it will not create an interrupt.

The addresses of both registers are set through generics. See section Interface.Generics.

By using this feature, the internal configuration will add both registers in this configuration:
```
Config(i) ; Name ; Address ; Init_Value ; Auto_Clear_Mask ; rw_config ; Is_Interrupt_Register
N ; Interrupt_Enable_Register ; INTERRUPT_ENABLE_REGISTER_ADDRESS ; 0xFFFFFFFF ; 0x00000000 ; readWriteable; false
N+1 ; Interrupt_Match_Register; INTERRUPT_MATCH_REGISTER_ADDRESS ; 0x00000000 ; 0x00000000 ; latchHighBit_clearOnRead; true
```

Atomic Register
===============

An ``Atomic Register`` is an external wiring. This is used to avoid read-modify-write opperations from software by introducing a `clear-bit-register`, ``set-bit-register`` and `toggle-bit-register`. A constant is prepared for this register inside ``AXI4Lite.pkg.vhdl`` called `Atomic_RegisterDescription_Vector`. It can be mapped/created inside of the ``gen_config`` function like this:

.. code-block:: vhdl

   temp(pos to pos + Atomic_RegisterDescription_Vector'length -1) := add_prefix("My_Atomic_reg.", Atomic_RegisterDescription_Vector, to_unsigned(addr *4, 32));
      pos := pos   + Atomic_RegisterDescription_Vector'length;
      addr := addr + Atomic_RegisterDescription_Vector'length;

**Note: the Atomic Register should be at least 64bit alligned. If this is true, the set- and clear- mask can be written at the same time.**

Afterwords, the wiring needs to be created in the pl like this:

.. code-block:: vhdl
   atomic_blk : block
      constant low  : natural := get_index("My_Atomic_reg.ATOMIC_Value", config);
      constant high : natural := get_index("My_Atomic_reg.ATOMIC_BitClr", config);
      signal Atomic_Value     : std_logic_vector(31 downto 0) := (others => '0');
      signal nextAtomic_Value : std_logic_vector(31 downto 0);
   begin
      procedure Make_AtomicRegister(
         Reset                     => Reset,
         RegisterFile_ReadPort     => RegisterFile_ReadPort(low to high),
         RegisterFile_WritePort    => RegisterFile_WritePort(low to high),
         RegisterFile_ReadPort_hit => RegisterFile_ReadPort_hit(low to high),
         PL_WriteValue             => Overwrite_from_PL_slv,
         PL_WriteStrobe            => Overwrite_from_PL_strb,
         Value_reg                 => Atomic_Value,
         nextValue_reg             => nextAtomic_Value
      );
      Atomic_Value <= nextAtomic_Value when rising_edge(Clock);
   end block;


I/O Register
============

The ``IO Register`` is used to connect a tri-state buffer directly to the register. It consists of two `atomic registers`. The first one for ``IO`` (Input/Output) and the second one for ``T`` (Tristate).

To add it into config:

.. code-block:: vhdl
   temp(pos to pos + IO_RegisterDescription_Vector'length -1) := add_prefix("My_IO_reg.", IO_RegisterDescription_Vector, to_unsigned(addr *4, 32));
      pos := pos   + IO_RegisterDescription_Vector'length;
      addr := addr + IO_RegisterDescription_Vector'length;


Afterwords, the wiring needs to be created in the pl like this:

.. code-block:: vhdl

   io_reg_blk : block
      constant low  : natural := get_index("My_IO_reg.IO.ATOMIC_Value", config);
      constant high : natural := get_index("My_IO_reg.T.ATOMIC_BitClr", config);
      signal IO_Value     : std_logic_vector(31 downto 0) := (others => '0');
      signal nextIO_Value : std_logic_vector(31 downto 0);
      signal T_Value      : std_logic_vector(31 downto 0) := (others => '0');
      signal nextT_Value  : std_logic_vector(31 downto 0);
   begin
      procedure Make_IORegister(
         Reset                     => Reset,
         RegisterFile_ReadPort     => RegisterFile_ReadPort(low to high),
         RegisterFile_WritePort    => RegisterFile_WritePort(low to high),
         RegisterFile_ReadPort_hit => RegisterFile_ReadPort_hit(low to high),
         Input                     => Buffe_I_slv,
         Output                    => Buffe_O_slv,
         Tristate                  => Buffe_T_slv,
         IO_reg                    => IO_Value,
         nextIO_reg                => nextIO_Value,
         T_reg                     => T_Value,
         nextT_reg                 => nextT_Value,
      );
      IO_Value <= nextIO_Value when rising_edge(Clock);
      T_Value  <= nextT_Value  when rising_edge(Clock);
   end block;


AXI4Lite Register Split
=======================
The moduel ``AXI4Lite_Register_split`` is an addition to the normal register. It splits up a big register into multiple smaller ones, that can then better acheave timing. This is done by the Address-Demultiplexer `AXI4Lite_DeMux`.

This module adds the following generics:
| Name | Type | Default | Description |
|------|-------|---------|-------------|
| SPLIT_ON_ADDRESSBIT | natural | 0 | Split the register on this address-bit. If default (zero), it will split it up on address bit 6. This means every 0x40 will be split up. |
| PIPELINE_IN| natural | 0 | Adds N many pipeline-stages before the De-Mux |
| PIPELINE_OUT| natural | 0 | Adds N many pipeline-stages between De-Mux and all registers. |

{-Interrupts are currently not working for this module fully! It is only working if all interrupt-registers are in one sub-register and the Interrupt match and enable register addresses are located in the same sub-register.-}


## AXI4Lite Register Single-Access (BRAM AXI4Lite Register)
{-Experimental Module-}
This module is a variant with singel access from PL instead parallel. With this restriction, it is possible to put the register completally into Lut-Ram or BRAM and save a lot of ressources. 1 BRAM can store in total 1k registers without timing problems.

Because it uses a dual-port-ram it has a shared access with the PL-read/write and AXI4L-read/write. To simplify the access for an potential FSM out of the PL, the access for PL is prioritized. The first port is fully reservated for the read access out of PL. The Port ``RegisterFile_ReadData`` shows always the value of address `RegisterFile_ReadAddress`. The second port is shared and has the following prioritization:
1. PL Write
1. AXI4L Write
1. AXI4L Read

Currently it is not selectable if Lut-RAM or BRAM should be used. If this is needed, ask @sunrein for this feature.
