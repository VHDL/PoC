.. _IP/axi4lite_FIFO:
.. index::
   single: AXI4-Lite; axi4lite_FIFO

axi4lite_FIFO
#############


Based on :ref:`IP/fifo_cc_got`


.. _IP/axi4lite_FIFO/goals:

.. topic:: Design Goals

   * tbd


.. _IP/axi4lite_FIFO/features:

.. topic:: Features

   * tbd


.. _IP/axi4lite_FIFO/instantiation:

Instantiation
*************

.. grid:: 2

   .. grid-item::
      :columns: 5

      .. todo:: needs documentation

   .. grid-item-card::
      :columns: 7

      .. code-block:: vhdl

         FIFO : entity PoC.axi4lite_FIFO
         generic map (
           TRANSACTIONS => 1024
         )
         port map (
           Clock   => Clock,
           Reset   => Reset,

           In_m2s  => Source_m2s,
           In_s2m  => Source_s2m

           Out_m2s => FIFO_m2s,
           Out_s2m => FIFO_s2m
         );


.. _IP/axi4lite_FIFO/interface:

Interface
*********

.. _IP/axi4lite_FIFO/generics:

Generics
========

.. _IP/axi4lite_FIFO/gen/TRANSACTIONS:

:generic:`TRANSACTIONS`
-----------------------

:Name:          :generic:`TRANSACTIONS`
:Type:          :type:`positive`
:Default Value: ``2``
:Description:   tbd


.. _IP/axi4lite_FIFO/ports:

Ports
=====

.. _IP/axi4lite_FIFO/port/Clock:

:port:`Clock`
-------------

:Name:          ``Clock``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   Clock


.. _IP/axi4lite_FIFO/port/Reset:

:port:`Reset`
-------------

:Name:          ``Reset``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   synchronous high-active reset


.. _IP/axi4lite_FIFO/port/In_m2s:

:port:`In_m2s`
--------------

:Name:          ``In_m2s``
:Type:          ``axi4lite.T_AXI4Lite_Bus_m2s``
:Mode:          in
:Default Value: — — — —
:Description:   AXI4-Lite manager to subordinate signals.


.. _IP/axi4lite_FIFO/port/In_s2m:

:port:`In_s2m`
--------------

:Name:          ``In_s2m``
:Type:          ``axi4lite.T_AXI4Lite_Bus_s2m``
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.


.. _IP/axi4lite_FIFO/port/Out_m2s:

:port:`Out_m2s`
---------------

:Name:          ``Out_m2s``
:Type:          ``axi4lite.T_AXI4Lite_Bus_m2s``
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite manager to subordinate signals.


.. _IP/axi4lite_FIFO/port/Out_s2m:

:port:`Out_s2m`
---------------

:Name:          ``Out_s2m``
:Type:          ``axi4lite.T_AXI4Lite_Bus_s2m``
:Mode:          in
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.


.. _IP/axi4lite_FIFO/configuration:

Configuration
*************

.. todo:: tbd


.. _IP/axi4lite_FIFO/UsedIn:

Use in
******

* tbd
