.. _IP/AXI4Lite_UART:
.. index::
   single: AXI4-Lite; AXI4Lite_UART

AXI4Lite_UART
###########################

Based on :ref:`IP/axi4lite_Register`, :ref:`IP/uart_fifo`

.. todo::

.. _IP/AXI4Lite_UART/goals:

.. topic:: Design Goals

   * *tbd*


.. _IP/AXI4Lite_UART/features:

.. topic:: Features

   * *tbd*


.. _IP/AXI4Lite_UART/instantiation:

Instantiation
*************

.. _IP/AXI4Lite_UART/inst/Simple:

.. grid:: 2

   .. grid-item::
      :columns: 5

      .. todo:: needs documentation

   .. grid-item-card::
      :columns: 7

      .. code-block:: vhdl

         UART : entity PoC.AXI4Lite_UART
         generic map (
            CLOCK_FREQ => 100 MHz,
            BAUDRATE   => 115.200 kBd
         )
         port map (
           Clock        => Clock,
           Reset        => Reset,

           AXI4Lite_m2s => AXI4Lite_m2s,
           AXI4Lite_s2m => AXI4Lite_s2m,
           Config_irq   => Config_irq,

           UART_TX      => UART_TX,
           UART_RX      => UART_RX,
           UART_RTS     => UART_RTS,
           UART_CTS     => UART_CTS
         );

.. _IP/AXI4Lite_UART/inst/Xilinx:


Interface
*********

.. _IP/AXI4Lite_UART/generics:

Generics
========

.. _IP/AXI4Lite_UART/gen/CLOCK_FREQ:

:generic:`CLOCK_FREQ`
----------------------------

:Name:          :generic:`CLOCK_FREQ`
:Type:          :type:`FREQ`
:Default Value: — — — —
:Description:   Frequency of input clock.


.. _IP/AXI4Lite_UART/gen/BAUDRATE:

:generic:`BAUDRATE`
----------------------------

:Name:          :generic:`BAUDRATE`
:Type:          :type:`BAUD`
:Default Value: 115.200 kBd
:Description:   *tbd*

.. _IP/AXI4Lite_UART/gen/PARITY:

:generic:`PARITY`
---------------------------

:Name:          :generic:`PARITY`
:Type:          :type:`T_UART_PARITY_MODE`
:Default Value: ``PARITY_NONE``
:Description:   ``PARITY_EVEN``, ``PARITY_ODD``, ``PARITY_NONE``


.. _IP/AXI4Lite_UART/gen/PARITY_ERROR_HANDLING:

:generic:`PARITY_ERROR_HANDLING`
--------------------------

:Name:          :generic:`PARITY_ERROR_HANDLING`
:Type:          :type:`T_UART_PARITY_ERROR_HANDLING`
:Default Value: ``PASSTHROUGH_ERROR_BYTE``
:Description:   ``PASSTHROUGH_ERROR_BYTE``, ``REPLACE_ERROR_BYTE``, ``DROP_ERROR_BYTE``


.. _IP/AXI4Lite_UART/gen/PARITY_ERROR_IDENTIFIER:

:generic:`PARITY_ERROR_IDENTIFIER`
--------------------------------

:Name:          :generic:`PARITY_ERROR_IDENTIFIER`
:Type:          :type:`std_logic_vector(7 downto 0)`
:Default Value: ``x"15"``
:Description:   *tbd*


.. _IP/AXI4Lite_UART/gen/ADD_INPUT_SYNCHRONIZERS:

:generic:`ADD_INPUT_SYNCHRONIZERS`
--------------------------------

:Name:          :generic:`ADD_INPUT_SYNCHRONIZERS`
:Type:          :type:`boolean`
:Default Value: ``TRUE``
:Description:   *tbd*


.. _IP/AXI4Lite_UART/gen/TX_FIFO_DEPTH:

:generic:`TX_FIFO_DEPTH`
--------------------------------

:Name:          :generic:`TX_FIFO_DEPTH`
:Type:          :type:`positive`
:Default Value: 16
:Description:   *tbd**


.. _IP/AXI4Lite_UART/gen/RX_FIFO_DEPTH:

:generic:`RX_FIFO_DEPTH`
--------------------------------

:Name:          :generic:`RX_FIFO_DEPTH`
:Type:          :type:`positive`
:Default Value: 16
:Description:   *tbd*


.. _IP/AXI4Lite_UART/gen/FLOWCONTROL:

:generic:`FLOWCONTROL`
--------------------------------

:Name:          :generic:`FLOWCONTROL`
:Type:          :type:`T_IO_UART_FLOWCONTROL_KIND`
:Default Value: ``UART_FLOWCONTROL_NONE``
:Description:   *tbd*


.. _IP/AXI4Lite_UART/gen/SWFC_XON_CHAR:

:generic:`SWFC_XON_CHAR`
--------------------------------

:Name:          :generic:`SWFC_XON_CHAR`
:Type:          :type:`std_logic_vector(7 downto 0)`
:Default Value: ``x"11"``
:Description:   *tbd*


.. _IP/AXI4Lite_UART/gen/SWFC_XOFF_CHAR:

:generic:`SWFC_XOFF_CHAR`
--------------------------------

:Name:          :generic:`SWFC_XOFF_CHAR`
:Type:          :type:`std_logic_vector(7 downto 0)`
:Default Value: ``x"13"``
:Description:   *tbd*


.. _IP/AXI4Lite_UART/ports:

Ports
=====

.. _IP/AXI4Lite_UART/port/Clock:

:port:`Clock`
-------------

:Name:          :port:`Clock`
:Type:          :type:`std_logic`
:Mode:          in
:Default Value: — — — —
:Description:   Clock


.. _IP/AXI4Lite_UART/port/Reset:

:port:`Reset`
-------------

:Name:          :port:`Reset`
:Type:          :type:`std_logic`
:Mode:          in
:Default Value: — — — —
:Description:   synchronous high-active reset


.. _IP/AXI4Lite_UART/port/AXI4Lite_m2s:

:port:`AXI4Lite_m2s`
--------------------

:Name:          :port:`AXI4Lite_m2s`
:Type:          :type:`axi4lite.T_AXI4Lite_Bus_m2s`
:Mode:          in
:Default Value: — — — —
:Description:   AXI4-Lite manager to subordinate signals.


.. _IP/AXI4Lite_UART/port/AXI4Lite_s2m:

:port:`AXI4Lite_s2m`
--------------------

:Name:          :port:`AXI4Lite_s2m`
:Type:          :type:`axi4lite.T_AXI4Lite_Bus_s2m`
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.


.. _IP/AXI4Lite_UART/port/Config_irq:

:port:`Config_irq`
--------------------

:Name:          :port:`Config_irq`
:Type:          :type:`std_logic`
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.


.. _IP/AXI4Lite_UART/port/UART_TX:

:port:`UART_TX`
--------------------

:Name:          :port:`UART_TX`
:Type:          :type:`std_logic`
:Mode:          out
:Default Value: — — — —
:Description:   *tbd*.


.. _IP/AXI4Lite_UART/port/UART_RX:

:port:`UART_RX`
--------------------

:Name:          :port:`UART_RX`
:Type:          :type:`std_logic`
:Mode:          in
:Default Value: — — — —
:Description:   *tbd*.


.. _IP/AXI4Lite_UART/port/UART_RTS:

:port:`UART_RTS`
--------------------

:Name:          :port:`UART_RTS`
:Type:          :type:`std_logic`
:Mode:          out
:Default Value: — — — —
:Description:   *tbd*.


.. _IP/AXI4Lite_UART/port/UART_CTS:

:port:`UART_CTS`
--------------------

:Name:          :port:`UART_CTS`
:Type:          :type:`std_logic`
:Mode:          in
:Default Value: — — — —
:Description:   *tbd*.


.. _IP/AXI4Lite_UART/configuration:

Configuration
*************

.. _IP/AXI4Lite_UART/config/User:

User defined Word
=================

.. todo:: tbd


.. _IP/AXI4Lite_UART/RegisterMap:

Register Map
************

+---------+--------------------------+---------------------+-------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| Offset  | R/W Config               |      Default        |           Name                |                       Description                                                                                                                                  |
+=========+==========================+=====================+===============================+====================================================================================================================================================================+
| 0x0000  | ReadOnly_NotRegistered   | ``x"00000000"``     |  Rx                           | Read from receive buffer.                                                                                                                                          |
+---------+--------------------------+---------------------+-------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x0004  | ReadWrite_NotRegistered  | ``x"00000000"``     |  Tx                           | Write into transmit buffer.                                                                                                                                        |
+---------+--------------------------+---------------------+-------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x0008  | ReadOnly                 | ``x"00000000"``     |  Status                       | Receive status.                                                                                                                                                    |
+---------+--------------------------+---------------------+-------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| 0x000C  | ReadWrite                | ``x"00000000"``     |  Control                      | Command byte                                                                                                                                                       |
+---------+--------------------------+---------------------+-------------------------------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------+

Related Files
*************

*None*
