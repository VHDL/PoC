.. _IP/axi4lite_Register:
.. index::
   single: AXI4-Lite; axi4lite_Register

axi4lite_Register
#################

The :comp:`axi4lite_Register` is a generic implementation of :term:`memory-mapped-registers (MMR) <MMR>` providing an
:term:`AXI4-Lite` communication interface. The register layout is describe by a generic constant called
:ref:`IP/axi4lite_Register/gen/CONFIG`. This constant is :ref:`constructed <IP/axi4lite_Register/configuration>` by
various helper functions as described in the following sections.


.. _IP/axi4lite_Register/goals:

.. topic:: Design Goals

   * The register is described completely within VHDL.

     * Pure VHDL code offers the single-source of truth.
     * VHDL language constructs (function, loop, if-then-else, ...) can be utilized to describe register layouts.
     * A register description in YAML format is exported at :term:`elaboration time` (synthesis or simulation).

   * The register supports 32/64-bit AXI4-Lite buses.
   * Support optimized registers within the same register structure:

     * Support constant read-only registers for fixed values like generic parameters.
     * Support fall-through registers to provide access e.g. to transmit and receive :term:`FIFOs <FIFO>`.

   * The register can generate interrupts

.. _IP/axi4lite_Register/features:

.. topic:: Features

   * Supports 32-bit (4-byte aligned) and 64-bit registers (8-byte aligned).
   * Supports 32-bit and 64-bit AXI4-Lite interface.
   * Indicate register access from AXI4-Lite as a *hit* signal.
   * Sparse register address support (address range can have unaccessible addresses).
   * Generate interrupt requests depending on register configurations.

     * Configurable IRQ pattern: :term:`strobe` vs. :term:`flag`.
     * Provide interrupt reason and interrupt enable registers if interrupt causing registers are configured.
     * Configurable interrupt reason register address.
     * Configurable interrupt enable register address.

   * AXI4 error handling and response codes:

     * Generate negative AXI4 response on permission errors (e.g. writing on a readonly register)
     * Generate negative AXI4 response on addressing errors (e.g. access to non-existing address)
     * Configurable AXI4 response code in case of access errors.

   * Configurable reset behavior:

     * Reload initial register values on reset.

   * If in debug mode, mark important signals as ``debug`` and write register configuration and internal calculations
     into synthesis log.


.. _IP/axi4lite_Register/instantiation:

Instantiation
*************

Depending on the complexity of the register (number of registers, register modes, repeated groups), various VHDL coding
styles (also with vary complexity) can be used to configure the axi4lite_Register completely in VHDL. No external
scripting or code generation is needed to describe and use the AXI4-Lite register.


.. _IP/axi4lite_Register/inst/Simple:

Simple Register
===============

.. grid:: 2

   .. grid-item::
      :columns: 5

      The example code on the right side demonstrates a simple 32-bit AXI4-Lite register offering two registers at
      addresses :vhdlcode:`0x00` and :vhdlcode:`0x04`. The first register is configured in read-write mode, the second
      one is in read-only mode. The register description array is provided directly in the *generic map* to the
      :ref:`IP/axi4lite_Register/gen/CONFIG` parameter within the register instantiation.

      The *port map* connect the system signals :ref:`IP/axi4lite_Register/port/Clock` and
      :ref:`IP/axi4lite_Register/port/Reset` as well as the AXI4-Lite interface consisting of
      :ref:`IP/axi4lite_Register/port/AXI4Lite_m2s`, :ref:`IP/axi4lite_Register/port/AXI4Lite_s2m` and
      :ref:`IP/axi4lite_Register/port/AXI4Lite_irq` to the AXI4-Lite infrastructure.

      For this simple read and write use-model, only ports :ref:`IP/axi4lite_Register/port/RegisterFile_ReadPort` and
      :ref:`IP/axi4lite_Register/port/RegisterFile_WritePort` are required.

      .. hint::

         The naming is chosen from **fabric view**, thus writing is from fabric to register and reading is from register
         to fabric.

      The following code accesses a single register by it's configuration index according to the configuration generic
      (this is not the register offset).

      .. code-block:: vhdl

         signal my_Value32Bit : std_logic_vector(31 downto 0);

         my_Value32Bit <= ReadPort(0);      -- register 'Value'

      A register value can be provided from VHDL code as follows:

      .. code-block:: vhdl

         signal my_Status32Bit : std_logic_vector(31 downto 0);

         WritePort(1) <= my_Status32Bit;    -- register 'Status'


   .. grid-item-card::
      :columns: 7

      .. code-block:: vhdl

         myReg_blk : block
           signal ReadPort  : T_SLVV(0 to 1)(31 downto 0);
           signal WritePort : T_SLVV(0 to 1)(31 downto 0);
         begin
           Reg : entity PoC.axi4lite_Register
           generic map (
             CONFIG => (
               0 => to_AXI4_Register(Name => "Value",  Address => 32x"0", rw_config => ReadWrite),
               1 => to_AXI4_Register(Name => "Status", Address => 32x"4", rw_config => ReadOnly)
             )
           )
           port map (
             Clock                         => Clock,
             Reset                         => Reset,

             AXI4Lite_m2s                  => ConfigRegister_m2s,
             AXI4Lite_s2m                  => ConfigRegister_s2m,
             AXI4Lite_irq                  => open,

             RegisterFile_ReadPort         => ReadPort,  -- read from fabric
             RegisterFile_WritePort        => WritePort  -- write from fabric
           );


.. _IP/axi4lite_Register/inst/GenConfig:

Register Description from Generator Function
============================================

.. grid:: 2

   .. grid-item::
      :columns: 5

      A register description is an array of type :type:`T_AXI4_Register_Vector`. Such an array can be constructed by an
      aggregate expression (see :ref:`IP/axi4lite_Register/inst/Simple`), by calling a user-defined helper function or
      by concatenating results from multiple user-defined helper functions.

      The example code on the right side demonstrates how local signals can be sized based on a :vhdlcode:`CONFIG`
      constant.The constant itself is computed by a user-defined function. See section
      :ref:`IP/axi4lite_Register/configuration` for details.

      When a register is access from AXI4-Lite side, a hit event (:term:`strobe`) is generated. In case an AXI4-Lite
      read operation was executed and a matching register offset was decoded, a corresponding bit is active for one
      clock cycle in :ref:`IP/axi4lite_Register/port/RegisterFile_WritePort_hit`. Similarly, in case an AXI4-Lite write
      operation was executed and a matching register offset was decoded, a corresponding bit within
      :ref:`IP/axi4lite_Register/port/RegisterFile_ReadPort_hit` is asserted for one clock cycle.

      .. admonition:: Advantages of a generator function

         Employing a user-defined helper function offer multiple advantages:

         * Encapsulate register description generation in a local or global VHDL function.
         * Use VHDL language constructs like concatenation, loops, if-then-else or other subprogram to construct a
           description.
         * Automate register names and register offset incrementation.
         * Generate registers based on function parameters (e.g. from generics).
         * Store the register description in a constant.
         * Lookup register indices by name.

   .. grid-item::
      :columns: 7

      .. code-block:: vhdl

         myReg_blk : block
           constant CONFIG         : T_AXI4_Register_Vector                   := genConfig;

           signal ReadPort         : T_SLVV(          0 to CONFIG'length - 1)(31 downto 0);
           signal ReadPort_hit     : std_logic_vector(0 to CONFIG'length - 1);
           signal WritePort        : T_SLVV(          0 to CONFIG'length - 1)(31 downto 0);
           signal WritePort_hit    : std_logic_vector(0 to CONFIG'length - 1);
           signal WritePort_strobe : std_logic_vector(0 to CONFIG'length - 1) := get_StrobeVector(CONFIG);
         begin
           Reg : entity PoC.axi4lite_Register
           generic map (
             CONFIG => CONFIG
           )
           port map (
             Clock                         => Clock,
             Reset                         => Reset,

             AXI4Lite_m2s                  => ConfigRegister_m2s,
             AXI4Lite_s2m                  => ConfigRegister_s2m,
             AXI4Lite_irq                  => open,

             RegisterFile_ReadPort         => ReadPort,
             RegisterFile_ReadPort_hit     => ReadPort_hit,
             RegisterFile_WritePort        => WritePort
             RegisterFile_WritePort_hit    => WritePort_hit,
             RegisterFile_WritePort_strobe => WritePort_strobe
           );






.. _IP/axi4lite_Register/interface:

Interface
*********

The IP core offers a system interface (clock, reset), the AXI4-Lite interface and access to the internal registers from
fabric.

.. attention::

   The naming of fabric ports is from fabric point-of-view. However, the naming of register modes like ``ReadOnly`` is
   from AXI4-Lite manger (CPU, software) point-of-view.

.. _IP/axi4lite_Register/generics:

Generics
========

.. _IP/axi4lite_Register/gen/CONFIG:

:generic:`CONFIG`
-----------------

:Name:          :generic:`CONFIG`
:Type:          :type:`AXI4Lite:T_AXI4_Register_Vector`
:Default Value: — — — —
:Description:   Register description as an array of :type:`AXI4Lite:T_AXI4_Register` values. Usually, these array
                elements are constructed by the helper function :subprog:`to_AXI4_Register`.

                See :ref:`IP/axi4lite_Register/configuration`


.. _IP/axi4lite_Register/gen/INTERRUPT_IS_STROBE:

:generic:`INTERRUPT_IS_STROBE`
------------------------------

:Name:          :generic:`INTERRUPT_IS_STROBE`
:Type:          :type:`boolean`
:Default Value: ``true``
:Description:   Define the behavior of the interrupt request port :ref:`IP/axi4lite_Register/port/AXI4Lite_irq`.

                If this generic is ``true``, a :term:`edge (strobe) <strobe>` interrupt is generated, otherwise a
                :term:`level (flag) <flag>` interrupt.

                .. todo::

                   With this generic, it can be selected if the Interrupt-pin should through an interrupt as ``Strobe``
                   or ``Value``. By selecting ``Strobe``, the module will block a new interrupt until the
                   ``INTERRUPT_MATCH_REGISTER`` is read out.


.. _IP/axi4lite_Register/gen/INTERRUPT_ENABLE_REGISTER_ADDRESS:

:generic:`INTERRUPT_ENABLE_REGISTER_ADDRESS`
--------------------------------------------

:Name:          :generic:`INTERRUPT_ENABLE_REGISTER_ADDRESS`
:Type:          :type:`unsigned`
:Default Value: ``x"00"``
:Description:   If Interrupts are used, this generic selects the address of the internal ``INTERRUPT_ENABLE_REGISTER``.


.. _IP/axi4lite_Register/gen/INTERRUPT_MATCH_REGISTER_ADDRESS:

:generic:`INTERRUPT_MATCH_REGISTER_ADDRESS`
-------------------------------------------

:Name:          :generic:`INTERRUPT_MATCH_REGISTER_ADDRESS`
:Type:          :type:`unsigned`
:Default Value: ``x"04"``
:Description:   If Interrupts are used, this generic selects the address of the internal ``INTERRUPT_MATCH_REGISTER``.


.. _IP/axi4lite_Register/gen/INIT_ON_RESET:

:generic:`INIT_ON_RESET`
------------------------

:Name:          :generic:`INIT_ON_RESET`
:Type:          :type:`boolean`
:Default Value: ``true``
:Description:   The Init-value of the registers, that is set by the ``Config``, is set by default with the Reset. This
                can be disabled here. This helps with reducing control-sets and therefore helps by CLB utilization.


.. _IP/axi4lite_Register/gen/IGNORE_HIGH_ADDRESS:

:generic:`IGNORE_HIGH_ADDRESS`
------------------------------

:Name:          :generic:`IGNORE_HIGH_ADDRESS`
:Type:          :type:`boolean`
:Default Value: ``true``
:Description:   The module will calculate based on the configuration how many bits are needed to address every specified
                register. If this generic is set, it will ignore every bit which is coming after the needed address-bits.
                These bits are considered as base address. By setting this value, you can pass the full 40/32bit from
                Zynq, and it will filter out the base address for it.


.. _IP/axi4lite_Register/gen/RESPONSE_ON_ERROR:

:generic:`RESPONSE_ON_ERROR`
----------------------------

:Name:          :generic:`RESPONSE_ON_ERROR`
:Type:          :type:`AXI4Lite:T_AXI4_Response`
:Default Value: ``C_AXI4_RESPONSE_DECODE_ERROR``
:Possible Values: ``C_AXI4_RESPONSE_OKAY``, ``C_AXI4_RESPONSE_EX_OKAY``, ``C_AXI4_RESPONSE_SLAVE_ERROR`` or ``C_AXI4_RESPONSE_DECODE_ERROR``
:Description:   With this generic can be selected which response code should be sent out if an address is accessed that
                is not handled by ``Config``.


.. _IP/axi4lite_Register/gen/DISABLE_ADDRESS_CHECK:

:generic:`DISABLE_ADDRESS_CHECK`
--------------------------------

:Name:          :generic:`DISABLE_ADDRESS_CHECK`
:Type:          :type:`boolean`
:Default Value: ``false``
:Description:   The module is internally calculating if any registers have overlapping addresses and will create an
                error if so. This check takes a bit of synthesis time that depends on the size of ``Config``. This check
                can be disabled.

                .. attention:: This is not recommended!


.. _IP/axi4lite_Register/gen/DEBUG:

:generic:`DEBUG`
----------------

:Name:          :generic:`DEBUG`
:Type:          :type:`boolean`
:Default Value: ``false``
:Description:   If set to true, the module will print the configuration and settings into the synthesis-log with
                ``assert``.

:Description:   If set to true, the module sets specific internal signals as mark-debug. These signals are the
                hit-vectors, decoded addresses, and interrupt signals.


.. _IP/axi4lite_Register/ports:

Ports
=====

.. _IP/axi4lite_Register/port/Clock:

:port:`Clock`
-------------

:Name:          ``Clock``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   Clock


.. _IP/axi4lite_Register/port/Reset:

:port:`Reset`
-------------

:Name:          ``Reset``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   synchronous high-active reset


.. _IP/axi4lite_Register/port/AXI4Lite_m2s:

:port:`AXI4Lite_m2s`
--------------------

:Name:          ``AXI4Lite_m2s``
:Type:          ``axi4lite.T_AXI4Lite_Bus_m2s``
:Mode:          in
:Default Value: — — — —
:Description:   AXI4-Lite manager to subordinate signals.


.. _IP/axi4lite_Register/port/AXI4Lite_s2m:

:port:`AXI4Lite_s2m`
--------------------

:Name:          ``AXI4Lite_s2m``
:Type:          ``axi4lite.T_AXI4Lite_Bus_s2m``
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.


.. _IP/axi4lite_Register/port/AXI4Lite_irq:

:port:`AXI4Lite_irq`
--------------------

:Name:          ``AXI4Lite_irq``
:Type:          ``std_logic``
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite interrupt request. |br|
                Functionality depends on configured generics.


.. _IP/axi4lite_Register/port/RegisterFile_ReadPort:

:port:`RegisterFile_ReadPort`
-----------------------------

:Name:          ``RegisterFile_ReadPort``
:Type:          ``T_SLVV(0 to CONFIG'length - 1)(31 downto 0)``
:Mode:          out
:Default Value: — — — —
:Description:   Read-Port for register values (to fabric). |br|
                An array of 32-bit words; one 32-bit word per register.


.. _IP/axi4lite_Register/port/RegisterFile_ReadPort_hit:

:port:`RegisterFile_ReadPort_hit`
---------------------------------

:Name:          ``RegisterFile_ReadPort_hit``
:Type:          ``std_logic_vector(0 to CONFIG'length - 1)``
:Mode:          out
:Default Value: — — — —
:Description:   Hit-vector to fabric. A bit is asserted if the a AXI4-Lite manager has written a specific register and
                therefore changed the value in the corresponding register.


.. _IP/axi4lite_Register/port/RegisterFile_WritePort:

:port:`RegisterFile_WritePort`
------------------------------

:Name:          ``RegisterFile_WritePort``
:Type:          ``T_SLVV(0 to CONFIG'length - 1)(31 downto 0)``
:Mode:          in
:Default Value: — — — —
:Description:   Write-Port for register values (from fabric). |br|
                An array of 32-bit words; one 32-bit word per register.


.. _IP/axi4lite_Register/port/RegisterFile_WritePort_hit:

:port:`RegisterFile_WritePort_hit`
----------------------------------

:Name:          ``RegisterFile_WritePort_hit``
:Type:          ``std_logic_vector(0 to CONFIG'length - 1)``
:Mode:          out
:Default Value: — — — —
:Description:   Hit-vector to fabric. A bit is asserted if the a AXI4-Lite manager has read a specific register and
                therefore fetched the value in the corresponding register.


.. _IP/axi4lite_Register/port/RegisterFile_WritePort_strobe:

:port:`RegisterFile_WritePort_strobe`
-------------------------------------

:Name:          ``RegisterFile_WritePort_strobe``
:Type:          ``std_logic_vector(0 to CONFIG'length - 1)``
:Mode:          in
:Default Value: — — — —
:Description:   By asserting a bit to ``'1'``, the corresponding value at ``RegisterFile_WritePort`` is captured into
                the corresponding register. |br|
                The default value is set by the function ``get_strobeVector(CONFIG)``.

                .. todo:: Overwrite is mostly needed if ``rw_config`` is set to `readWriteable`.


.. _IP/axi4lite_Register/configuration:

Configuration
*************

.. _IP/axi4lite_Register/config/Registers:

Register Description
====================

The configuration can be created in many different ways. If the register is small, it can be done like above by directly
setting the register in the generic. This approach has the disadvantage that the index of the read and write port is
changing if an register is added later. This can easily create errors inside the design, if not each and every index is
checked and updated if needed. This is why this approach **is not commanded**.

The next step is to save the Config inside a constant. If done like this, the register can also use the `Name`-field.
If all register are named, the index of the register can be calculated by helper-functions with its specific name (See
next section `Helper Functions`). This helps to prevent from errors and allows easily to extend the register because the
index is calculated new and updated appropriate. This approach is only suitable for mid-complex registers.


.. code-block:: vhdl

   function genConfig return T_AXI4_Register_Vector is
     variable temp : T_AXI4_Register_Vector(0 to 511);
     variable addr : natural := 0;
     variable pos  : natural := 0;
   begin
     temp(pos) := to_AXI4_Register(Name => "System.Version", Address => to_unsigned(addr, 32), Init_Value => std_logic_vector(to_unsigned(3, 32)), rw_config => constant_fromInit);
     addr := addr +4; pos  := pos +1;
     temp(pos) := to_AXI4_Register(Name => "System.Status",Address => to_unsigned(addr, 32), rw_config => readable);
     addr := addr +4; pos  := pos +1;

     addr := 256;
     temp(pos) := to_AXI4_Register(Name => "System.Command",Address => to_unsigned(addr, 32), rw_config => readWriteable, Auto_Clear_Mask => x"FFFFFFFF");
     addr := addr +4; pos  := pos +1;

     return temp(0 to pos -1);
   end function;

   constant CONFIG : T_AXI4_Register_Vector := gen_config;


This example configuration creates a total of three registers. After one register is created the index/position is
incremented by one and the address by 4. The addresses are adapting automatically. As can be seen, the third register is
shifted to address 0x100 by overwriting the addr variable. This creates an empty space between 0x4 and 0x100, which is
creating a ``RESPONSE_ON_ERROR`` code while read or write access.

In this function registers can be created also as a loop:

.. code-block:: vhdl

   for i in 0 to Num_RTT -1 loop
     temp(pos) := to_AXI4_Register(Name => "Data_Value(" & integer'image(i) & ")", Address => to_unsigned(addr, 32), rw_config => readable);
	  pos := pos +1; addr := addr +4;
	end loop;

By giving each loop-register a different name dependent on the constant `i`, it can be referenced separately.



Record Data Structure
---------------------

The configuration specified via :ref:`IP/axi4lite_Register/gen/CONFIG` generic determines the functionality of the
register. It's an array of the ``AXI4Lite.pkg:T_AXI4_Register_Description``. This record has the following elements:

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


.. _IP/axi4lite_Register/config/Modes:

Register Modes
==============

For each register, a mode can be selected with the field `rw_config`. This mode depends on the functionality that should
be achieved. Possible modes are:


:value:`ConstantValue`
----------------------

:Mode:        :value:`ConstantValue`
:Behavior:    constant value
:Description: This Mode connects the ``Init_Value`` directly to the read-mux. No Flip-Flop is created and the Read and
              Write Port is unconnected.


:value:`ReadOnly`
-----------------

:Mode:        :value:`ReadOnly`
:Description: This Mode is used to provide a Status register.


:value:`ReadOnly_NotRegistered`
-------------------------------

:Mode:        :value:`ReadOnly_NotRegistered`
:Description: As ``readable`` but does not create flip-flops internally. The WritePort is directly connected to the
              read-mux. Can be used if data is already driven by registers or if path is not time-critical.


:value:`ReadWrite`
------------------

:Mode:        :value:`ReadWrite`
:Description: This Mode can be used to configure or control the PL form SW. Software can write into this register, and
              it will be visible through `RegisterFile_ReadPort`. The PL can also overwrite the Value by setting the
              corresponding bit in port `RegisterFile_WritePort_strobe`. In this mode, the field ``Auto_Clear_Mask`` is
              active. It can be used to control FSM's with a command, that is set only for one CC.


:value:`ReadWrite_NotRegistered`
--------------------------------

:Mode:        :value:`ReadWrite_NotRegistered`
:Description: This mode is used only for special use-cases. It provides the internal read- and write-mux connections
              directly to the ports, so any external functionality can be implemented. **Data on the
              ``RegisterFile_ReadPort`` is only valid if ``RegisterFile_WritePort_strobe`` is set!** See also chapter
              `Special Functionality`.


:value:`LatchValue_ClearOnRead`
-------------------------------

:Mode:        :value:`LatchValue_ClearOnRead`
:Description: ``Interrupt Capable`` After Reset or boot-up, this latch is cleared and can accept new data. If Stobe is
              then set, the data from ``RegisterFile_WritePort`` is saved. If this value is unequal to `Init_Value`, the
              value can not be overwritten until the SW reads it out. If latching condition is met and register is set
              as `Is_Interrupt_Register`, and interrupt is thrown.


:value:`LatchValue_ClearOnWrite`
--------------------------------

:Mode:        :value:`LatchValue_ClearOnWrite`
:Description: ``Interrupt Capable`` Same as `latchValue_clearOnRead`, but it is only cleared by actively writing into
              this register. The written value is ignored.


:value:`LatchHighBit_ClearOnRead`
---------------------------------

:Mode:        :value:`LatchHighBit_ClearOnRead`
:Description: ``Interrupt Capable`` By setting `Strobe`, the value of ``RegisterFile_WritePort`` is logically or-red
              together with the current register content. So a one-bit is always added to the value. By reading this
              register out, the software gets the value and clears it as well.


:value:`LatchHighBit_ClearOnWrite`
----------------------------------

:Mode:        :value:`LatchHighBit_ClearOnWrite`
:Description: ``Interrupt Capable`` Same as `latchHighBit_clearOnRead `, but it is only cleared  by actively writing
              into this register. The written value is ignored.


:value:`LatchLowBit_ClearOnRead`
--------------------------------

:Mode:        :value:`LatchLowBit_ClearOnRead`
:Description: ``Interrupt Capable`` For low-active signals. By setting `Strobe`, the value of ``RegisterFile_WritePort``
              is logically and-ed together with the current register content. So a zero-bit is always added to the
              value. By reading this register out, the software gets the value and sets all bits as well.


:value:`LatchLowBit_ClearOnWrite`
---------------------------------

:Mode:        :value:`LatchLowBit_ClearOnWrite`
:Description: ``Interrupt Capable`` Same as `latchLowBit_clearOnRead `, but it is only cleared  by actively writing into
              this register. The written value is ignored.


:value:`Reserved`
-----------------


.. #
   | Mode                      | Used for |
   | constant_fromInit         | constant       |
   | readable                  | Read-only-Reg  |
   | readable_non_reg          | Read-only-Reg  |
   | readWriteable             | Read-Write-Reg |
   | readWriteable_non_reg     | Special        |
   | latchValue_clearOnRead    | Status/Error   |
   | latchValue_clearOnWrite   | Status/Error   |
   | latchHighBit_clearOnRead  | Status/Error   |
   | latchHighBit_clearOnWrite | Status/Error   |
   | latchLowBit_clearOnRead   | Status/Error   |
   | latchLowBit_clearOnWrite  | Status/Error   |


Helper Functions
================

For ease of use, functions are created to help for basic modifications of the configuration.

filter_Register_Vector
----------------------

.. code-block:: vhdl

   function filter_Register_Vector(str : string; description_vector : T_AXI4_Register_Vector) return T_AXI4_Register_Vector;

Removes all elements of ``description_vector`` where `description_vector(i).name(str'range) /= str`.

.. code-block:: vhdl

   function filter_Register_Vector(char : character; description_vector : T_AXI4_Register_Vector) return T_AXI4_Register_Vector

Removes all elements of ``description_vector`` where `description_vector(i).name(1) /= char`.

add_Prefix
----------

.. code-block:: vhdl

   function add_Prefix(prefix : string; Config : T_AXI4_Register_Vector; offset : unsigned(Address_Width -1 downto 0) := (others => '0')) return T_AXI4_Register_Vector;

Adds the string prefix ``prefix`` to each Config(x).Name and adds the ``offset`` value to the Config(x).Address. This
function can be used if multiple standardized (as constant) register need to be put with a prefix into the big register.
Here is an example:

.. code-block:: vhdl

   constant Config_Packetizer : T_AXI4_Register_Vector := (
     0 => to_AXI4_Register(Name => "CMD", Address => to_unsigned(0, 32), rw_config => readWriteable)
     1 => to_AXI4_Register(Name => "CMD2", Address => to_unsigned(4, 32), rw_config => readWriteable)
     2 => to_AXI4_Register(Name => "STATUS", Address => to_unsigned(8, 32), rw_config => readable));

   function gen_config return T_AXI4_Register_Vector is
     variable temp : T_AXI4_Register_Vector(0 to 511);
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


to_AXI4_Register
----------------

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





.. _IP/axi4lite_Register/config/64BitRegister:

64-bit Registers
================

The register has a 64-bit register mode. If the Data-Size of the AXI4Lite record is 64-bit wide, the AXI4Lite-Register
will automatically put into 64-bit mode. The SW can then write 64-bit aligned into two 32-bit register at once.

.. important::

   The definition in the config is still done with 32-bit registers. Two 32-bit register are combined to one 64-bit
   register. The read and write is done in the same CC and is consistent. Note that two Hits will be set for both 32-bit
   register. If the software is making a read_32 it is not possible to know from PL which of these two registers was
   actually read out (or written to).


.. _IP/axi4lite_Register/config/Interrupts:

Interrupts
==========

The :comp:`axi4lite_Register` is capable of creating interrupts. The ``rw_config`` needs to be a latch type to be interrupt
capable (See section Register Mode (ReadWrite-Config)). In total, 32 registers can be set as interrupt register. This
limitation is due to the ``interrupt match register`` width of 32 bits. If an interrupt register is latched, the
interrupt is thrown. If the software registers an interrupt, it needs to read out the ``interrupt match register`` to
figure out which interrupt occurred. The order of the  bits here is equal to the order of the interrupt registers in the
config.

Example:

.. code-block::

   Config(i) ; Name ; Address ; Init_Value ; Auto_Clear_Mask ; rw_config ; Is_Interrupt_Register
   0 ; System.Version ; 0x00000000 ; 0x00000003 ; 0x00000000 ; constant_fromInit ; false
   1 ; System.Test; 0x00000004 ; 0x00000000 ; 0x00000000 ; latchLowBit_clearOnRead ; true
   2 ; System.Command ; 0x00000028 ; 0x00000000 ; 0xFFFFFFFF ; readWriteable ; false
   3 ; System.Status ; 0x0000002C ; 0x00000000 ; 0x00000000 ; latchLowBit_clearOnRead ; true

This configuration will create in total four registers of which two are interrupt registers. The
``interrupt match register`` bit zero is mapped to `System.Test`, bit one is mapped to `System.Status`. If one of these
bits is set, the SW needs to look into the correct address for the value. This means, if after an interrupt bit zero is
set from in the `interrupt match register`, the SW needs to read address ``0x00000004`` afterwards to get the
interrupt-causing-value and clear the interrupt reason.

Beside the `interrupt match register`, there is also the `Interrupt enable register`. With this, you can switch on and
off one specific register to through interrupts. The bit will still be set inside `interrupt match register`, but it
will not create an interrupt.

The addresses of both registers are set through generics. See section Interface.Generics.

By using this feature, the internal configuration will add both registers in this configuration:

.. code-block::

   Config(i) ; Name ; Address ; Init_Value ; Auto_Clear_Mask ; rw_config ; Is_Interrupt_Register
   N ; Interrupt_Enable_Register ; INTERRUPT_ENABLE_REGISTER_ADDRESS ; 0xFFFFFFFF ; 0x00000000 ; readWriteable; false
   N+1 ; Interrupt_Match_Register; INTERRUPT_MATCH_REGISTER_ADDRESS ; 0x00000000 ; 0x00000000 ; latchHighBit_clearOnRead; true


.. _IP/axi4lite_Register/config/Atomic:

Atomic Register
===============

An ``Atomic Register`` is an external wiring. This is used to avoid read-modify-write operations from software by
introducing a `clear-bit-register`, ``set-bit-register`` and `toggle-bit-register`. A constant is prepared for this
register inside ``AXI4Lite.pkg.vhdl`` called `Atomic_RegisterDescription_Vector`. It can be mapped/created inside of the
``gen_config`` function like this:

.. code-block:: vhdl

   temp(pos to pos + Atomic_RegisterDescription_Vector'length -1) := add_prefix("My_Atomic_reg.", Atomic_RegisterDescription_Vector, to_unsigned(addr *4, 32));
     pos := pos   + Atomic_RegisterDescription_Vector'length;
     addr := addr + Atomic_RegisterDescription_Vector'length;

.. note::

   The Atomic Register should be at least 64bit aligned. If this is true, the set- and clear- mask can be written at
   the same time.

Afterwards, the wiring needs to be created in the pl like this:

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


.. _IP/axi4lite_Register/Usage:

Usage
*****

.. _IP/axi4lite_Register/Use/CSE:

Command-Status-Error Interface
==============================



.. _IP/axi4lite_Register/Use/IO:

I/O Register
============

The ``IO Register`` is used to connect a tri-state buffer directly to the register. It consists of two
`atomic registers`. The first one for ``IO`` (Input/Output) and the second one for ``T`` (Tristate).

To add it into config:

.. code-block:: vhdl

   temp(pos to pos + IO_RegisterDescription_Vector'length -1) := add_prefix("My_IO_reg.", IO_RegisterDescription_Vector, to_unsigned(addr *4, 32));
     pos := pos   + IO_RegisterDescription_Vector'length;
     addr := addr + IO_RegisterDescription_Vector'length;


Afterwards, the wiring needs to be created in the pl like this:

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


.. _IP/axi4lite_Register/Export:

Export Configuration
********************

.. _IP/axi4lite_Register/Export/Naming:

Naming Convention of Registers
==============================

The Name field of the configuration is limited to 64-characters. This needs to be a constant and was defined like this.
The conversion to the C-Header file needs some properties to work. These properties are therefore defined globally.

#. Each register needs to be named.
#. Each register needs to have a unique name.
#. The Addresses should monotonically increasing (Only for C-Header File).
#. Multiple Registers can be grouped together with a prefix. The prefix is separated by a dot.
#. :strike:`Multiple Prefixes can be made` :red:`This is currently not possible with the script.`
#. A array of registers can be defined with parenthesis `(i)`. This will create and array in C-Header file.
#. :strike:`An array can be done as well on prefixes` :red:`This is currently not possible with the script.`

.. _IP/axi4lite_Register/Export/YAML:

Export as YAML
==============



.. _IP/axi4lite_Register/Export/CSV:

Write Register CSV File (deprecated)
====================================

A csv file can be written out of the configuration with the function `write_csv_file`. It is commanded to use it with an
enabled ``assert`` statement or writing it into a constant. With assert, you can also see in the synthesis log if
everything was successfully. ``PROJECT_DIR`` is a constant inside ``my_project.vhdl`` normally located at `src/PoC/`.

.. code-block:: vhdl

   constant success : boolean := write_csv_file(PROJECT_DIR & "gen/Sampling_Register.csv", config);
   --or--
   assert write_csv_file(PROJECT_DIR & "gen/Sampling_Register.csv", config) report "Error in writing csv-File!" severity warning;


.. _IP/axi4lite_Register/Export/Convert:

Create C-Header File from CSV
=============================

A big advantage of this register is the automatic register handover to the Software. This is done by converting the
freshly generated csv file and converting it into a C-Header file. The registers specified in the config are combined
into struct's. The final struct can than be layed over the AXI4Lite-Register Address.

The conversion is done by a python-script from *************************. This python script works but has currently a
lot of limitations.
**It is planed to extend this script and make it accessible to the CI-Runners for automatic conversions.**










.. #
   AXI4Lite Register Split
   =======================

   The moduel ``axi4lite_Register_split`` is an addition to the normal register. It splits up a big register into multiple smaller ones, that can then better acheave timing. This is done by the Address-Demultiplexer `AXI4Lite_DeMux`.

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

.. _IP/axi4lite_Register/UsedIn:

Use in
******

* :ref:`IP/axi4lite_GitVersionRegister`
