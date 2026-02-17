.. _IP/axi4lite_HighResolutionClock:
.. index::
   single: AXI4-Lite; axi4lite_HighResolutionClock

axi4lite_HighResolutionClock
###########################

Based on :ref:`IP/axi4lite_Register`, :ref:`IP/clock_highresolution`

.. todo::

.. _IP/axi4lite_HighResolutionClock/goals:

.. topic:: Design Goals

   * *tbd*


.. _IP/axi4lite_HighResolutionClock/features:

.. topic:: Features

   * *tbd*


.. _IP/axi4lite_HighResolutionClock/instantiation:

Instantiation
*************

.. _IP/axi4lite_HighResolutionClock/inst/Simple:

.. grid:: 2

   .. grid-item::
      :columns: 5

      .. todo:: needs documentation

   .. grid-item-card::
      :columns: 7

      .. code-block:: vhdl

         HRC : entity PoC.axi4lite_HighResolutionClock
         generic map (
            CLOCK_FREQUENCY => 100 MHz
         ) port map (
           Clock        => Clock,
           Reset        => Reset,
           Nanoseconds  => Nanoseconds,
           Datetime     => Datetime,

           AXI_clock    => AXI_clock,
           AXI_reset    => AXI_reset,
           AXI4Lite_m2s => AXI4Lite_m2s,
           AXI4Lite_s2m => AXI4Lite_s2m
         );

.. _IP/axi4lite_HighResolutionClock/inst/Xilinx:


Interface
*********

.. _IP/axi4lite_HighResolutionClock/generics:

Generics
========

.. _IP/axi4lite_HighResolutionClock/gen/CLOCK_FREQUENCY:

:generic:`CLOCK_FREQUENCY`
----------------------------

:Name:          :generic:`CLOCK_FREQUENCY`
:Type:          :type:`FREQ`
:Default Value: — — — —
:Description:   Frequency of input clock signal used by internal time counters.


.. _IP/axi4lite_HighResolutionClock/gen/USE_CDC:

:generic:`USE_CDC`
---------------------------

:Name:          :generic:`USE_CDC`
:Type:          :type:`boolean`
:Default Value: False
:Description:   Enable/disable CDC FIFO.


.. _IP/axi4lite_HighResolutionClock/gen/REGISTER_NANOSECONDS:

:generic:`REGISTER_NANOSECONDS`
--------------------------

:Name:          :generic:`REGISTER_NANOSECONDS`
:Type:          :type:`natural`
:Default Value: 0
:Description:   Amount of pipelining stages.


.. _IP/axi4lite_HighResolutionClock/gen/SECOND_RESOLUTION:

:generic:`SECOND_RESOLUTION`
--------------------------------

:Name:          :generic:`SECOND_RESOLUTION`
:Type:          :type:`T_SECOND_RESOLUTION`
:Default Value: ``NANOSECONDS``
:Description:   Set unit for `Time_sec_res` register (``NANOSECONDS``, ``MICROSECONDS`` or ``MILLISECONDS``).


.. _IP/axi4lite_HighResolutionClock/ports:

Ports
=====

.. _IP/axi4lite_HighResolutionClock/port/Clock:

:port:`Clock`
-------------

:Name:          :port:`Clock`
:Type:          :type:`std_logic`
:Mode:          in
:Default Value: — — — —
:Description:   Clock


.. _IP/axi4lite_HighResolutionClock/port/Reset:

:port:`Reset`
-------------

:Name:          :port:`Reset`
:Type:          :type:`std_logic`
:Mode:          in
:Default Value: — — — —
:Description:   synchronous high-active reset


.. _IP/axi4lite_HighResolutionClock/port/Nanoseconds:

:port:`Nanoseconds`
--------------------

:Name:          :port:`Nanoseconds`
:Type:          :type:`unsigned(63 downto 0)`
:Mode:          out
:Default Value: — — — —
:Description:   Current time in nanoseconds.


.. _IP/axi4lite_HighResolutionClock/port/Datetime:

:port:`Datetime`
--------------------

:Name:          :port:`Datetime`
:Type:          :type:`T_CLOCK_DATETIME`
:Mode:          out
:Default Value: — — — —
:Description:   Curent time in datetime.


.. _IP/axi4lite_HighResolutionClock/port/AXI_clock:

:port:`AXI_clock`
--------------------

:Name:          :port:`AXI_clock`
:Type:          :type:`std_logic`
:Mode:          in
:Default Value: — — — —
:Description:   AXI clock.


.. _IP/axi4lite_HighResolutionClock/port/AXI_reset:

:port:`AXI_reset`
--------------------

:Name:          :port:`AXI_reset`
:Type:          :type:`std_logic`
:Mode:          in
:Default Value: — — — —
:Description:   AXI reset.


.. _IP/axi4lite_HighResolutionClock/port/AXI4Lite_m2s:

:port:`AXI4Lite_m2s`
--------------------

:Name:          :port:`AXI4Lite_m2s`
:Type:          :type:`axi4lite.T_AXI4Lite_Bus_m2s`
:Mode:          in
:Default Value: — — — —
:Description:   AXI4-Lite manager to subordinate signals.


.. _IP/axi4lite_HighResolutionClock/port/AXI4Lite_s2m:

:port:`AXI4Lite_s2m`
--------------------

:Name:          :port:`AXI4Lite_s2m`
:Type:          :type:`axi4lite.T_AXI4Lite_Bus_s2m`
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.


.. _IP/axi4lite_HighResolutionClock/configuration:

Configuration
*************

.. todo:: tbd


.. _IP/axi4lite_HighResolutionClock/RegisterMap:

Register Map
************

+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Offset  | R/W Config               |             Name                |                       Description                                                                                                                                  |
+=========+==========================+=================================+====================================================================================================================================================================+
| 0x0000  |  —                       |    Reserved                     | Dummy register for later use                                                                                                                                       |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x0004  | ReadWrite                |    `Config_reg`                 | Configuration register for correction counter: |br| `Config_reg[31]`: `enable` |br| `Config_reg[30]`: `increment` |br| `Config_reg[29..0]`: `correction_threshold` |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x0008  | ReadOnly                 |    `Nanoseconds_lower`          | Current time in nanoseconds (lower 32-bit)                                                                                                                         |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x000C  | ReadOnly                 |    `Nanoseconds_upper`          | Current time in nanoseconds (upper 32-bit)                                                                                                                         |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x0010  | ReadOnly                 |    `Time_HMS`                   | current time: |br| `Time_HMS(31..17)`: reserved |br| `Time_HMS(16..12)`: `hours` |br| `Time_HMS(11..6)`: `minutes` |br| `Time_HMS(5..0)`: `seconds`                |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x0014  | ReadOnly                 |    `Date_Ymd`                   | current date: |br| `Date_Ymd(31..22)`: reserved |br| `Date_Ymd(21..9)`: `year` |br| `Date_Ymd(8..5)`: `month` |br| `Date_Ymd(4..0)`: `day`                         |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x0018  | ReadOnly                 |    `Time_sec_res`               | Counter in ms, us or ns (specified by user with a generic)                                                                                                         |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x001C  | —                        |    Reserved                     | Reserved                                                                                                                                                           |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x0020  | ReadWrite_NotRegistered  |    `Nanoseconds_to_load_lower`  | Nanoseconds to load (lower 32-bit)                                                                                                                                 |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x0024  | ReadWrite_NotRegistered  |    `Nanoseconds_to_load_uppper` | Nanoseconds to load (upper 32-bit)                                                                                                                                 |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x0028  | ReadWrite_NotRegistered  |    `Datetime_to_load_HMS`       | Time to load (as described for `Time_HMS`)                                                                                                                         |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x002C  | ReadWrite_NotRegistered  |    `Datetime_to_load_Ymd`       | Date to load (as described for `Date_Ymd`)                                                                                                                         |
+---------+--------------------------+---------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+

Related Files
*************

*None*
