.. _IP/axi4lite_FIFO_cdc:
.. index::
   single: AXI4-Lite; axi4lite_FIFO_cdc

axi4lite_FIFO_cdc
#################


Based on :ref:`IP/fifo_ic_got`


.. _IP/axi4lite_FIFO_cdc/goals:

.. topic:: Design Goals

   * tbd


.. _IP/axi4lite_FIFO_cdc/features:

.. topic:: Features

   * tbd


.. _IP/axi4lite_FIFO_cdc/instantiation:

Instantiation
*************

.. grid:: 2

   .. grid-item::
      :columns: 5

      .. todo:: needs documentation

   .. grid-item-card::
      :columns: 7

      .. code-block:: vhdl

         FIFO : entity PoC.axi4lite_FIFO_cdc
         generic map (
           TRANSACTIONS => 64
         )
         port map (
           In_Clock  => Source_Clock,
           In_Reset  => Source_Reset,
           In_m2s    => Source_m2s,
           In_s2m    => Source_s2m.

           Out_Clock => FIFO_Clock,
           Out_Reset => FIFO_Reset,
           Out_m2s   => FIFO_m2s,
           Out_s2m   => FIFO_s2m
         );


.. _IP/axi4lite_FIFO_cdc/interface:

Interface
*********

.. _IP/axi4lite_FIFO_cdc/generics:

Generics
========

.. _IP/axi4lite_FIFO_cdc/gen/TRANSACTIONS:

:generic:`TRANSACTIONS`
-----------------------

:Name:          :generic:`TRANSACTIONS`
:Type:          :type:`positive`
:Default Value: ``2``
:Description:   tbd


.. _IP/axi4lite_FIFO_cdc/gen/DATA_REG:

:generic:`DATA_REG`
-----------------------

:Name:          :generic:`DATA_REG`
:Type:          :type:`boolean`
:Default Value: ``false``
:Description:   tbd


.. _IP/axi4lite_FIFO_cdc/gen/OUTPUT_REG:

:generic:`OUTPUT_REG`
-----------------------

:Name:          :generic:`OUTPUT_REG`
:Type:          :type:`boolean`
:Default Value: ``false``
:Description:   tbd


.. _IP/axi4lite_FIFO_cdc/ports:

Ports
=====

.. _IP/axi4lite_FIFO_cdc/port/In_Clock:

:port:`In_Clock`
----------------

:Name:          ``In_Clock``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   Clock


.. _IP/axi4lite_FIFO_cdc/port/In_Reset:

:port:`In_Reset`
----------------

:Name:          ``In_Reset``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   synchronous high-active reset


.. _IP/axi4lite_FIFO_cdc/port/In_m2s:

:port:`In_m2s`
--------------

:Name:          ``In_m2s``
:Type:          ``axi4lite.T_AXI4Lite_Bus_m2s``
:Mode:          in
:Default Value: — — — —
:Description:   AXI4-Lite manager to subordinate signals.


.. _IP/axi4lite_FIFO_cdc/port/In_s2m:

:port:`In_s2m`
--------------

:Name:          ``In_s2m``
:Type:          ``axi4lite.T_AXI4Lite_Bus_s2m``
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.


.. _IP/axi4lite_FIFO_cdc/port/Out_Clock:

:port:`Out_Clock`
-----------------

:Name:          ``Out_Clock``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   Clock


.. _IP/axi4lite_FIFO_cdc/port/Out_Reset:

:port:`Out_Reset`
-----------------

:Name:          ``Out_Reset``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   synchronous high-active reset


.. _IP/axi4lite_FIFO_cdc/port/Out_m2s:

:port:`Out_m2s`
---------------

:Name:          ``Out_m2s``
:Type:          ``axi4lite.T_AXI4Lite_Bus_m2s``
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite manager to subordinate signals.


.. _IP/axi4lite_FIFO_cdc/port/Out_s2m:

:port:`Out_s2m`
---------------

:Name:          ``Out_s2m``
:Type:          ``axi4lite.T_AXI4Lite_Bus_s2m``
:Mode:          in
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.


.. _IP/axi4lite_FIFO_cdc/configuration:

Configuration
*************

.. todo:: tbd


.. _IP/axi4lite_FIFO_cdc/UsedIn:

Use in
******

* tbd
