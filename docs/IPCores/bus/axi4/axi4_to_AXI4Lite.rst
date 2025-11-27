.. _IP/axi4_to_AXI4Lite:
.. index::
   single: AXI4; axi4_to_AXI4Lite

axi4_to_AXI4Lite
################



.. _IP/axi4_to_AXI4Lite/goals:

.. topic:: Design Goals

   * tbd


.. _IP/axi4_to_AXI4Lite/features:

.. topic:: Features

   * tbd


.. _IP/axi4_to_AXI4Lite/instantiation:

Instantiation
*************

.. grid:: 2

   .. grid-item::
      :columns: 5

      .. todo:: needs documentation

   .. grid-item-card::
      :columns: 7

      .. code-block:: vhdl

         FIFO : entity PoC.axi4_to_AXI4Lite
         port map (
           Clock   => Clock,
           Reset   => Reset,

           In_m2s  => Source_m2s,
           In_s2m  => Source_s2m

           Out_m2s => Config_m2s,
           Out_s2m => Config_s2m
         );


.. _IP/axi4_to_AXI4Lite/interface:

Interface
*********

.. _IP/axi4_to_AXI4Lite/generics:

Generics
========

.. _IP/axi4_FIFO_cdc/gen/RESPONSE_FIFO_DEPTH:

:generic:`RESPONSE_FIFO_DEPTH`
------------------------------

:Name:          :generic:`RESPONSE_FIFO_DEPTH`
:Type:          :type:`positive`
:Default Value: ``16``
:Description:   tbd


.. _IP/axi4_to_AXI4Lite/ports:

Ports
=====

.. _IP/axi4_to_AXI4Lite/port/Clock:

:port:`Clock`
-------------

:Name:          ``Clock``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   Clock


.. _IP/axi4_to_AXI4Lite/port/Reset:

:port:`Reset`
-------------

:Name:          ``Reset``
:Type:          ``std_logic``
:Mode:          in
:Default Value: — — — —
:Description:   synchronous high-active reset


.. _IP/axi4_to_AXI4Lite/port/In_m2s:

:port:`In_m2s`
--------------

:Name:          ``In_m2s``
:Type:          ``axi4.T_AXI4_Bus_m2s``
:Mode:          in
:Default Value: — — — —
:Description:   AXI4 manager to subordinate signals.


.. _IP/axi4_to_AXI4Lite/port/In_s2m:

:port:`In_s2m`
--------------

:Name:          ``In_s2m``
:Type:          ``axi4.T_AXI4_Bus_s2m``
:Mode:          out
:Default Value: — — — —
:Description:   AXI4 subordinate to manager signals.


.. _IP/axi4_to_AXI4Lite/port/Out_m2s:

:port:`Out_m2s`
---------------

:Name:          ``Out_m2s``
:Type:          ``axi4lite.T_AXI4Lite_Bus_m2s``
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite manager to subordinate signals.


.. _IP/axi4_to_AXI4Lite/port/Out_s2m:

:port:`Out_s2m`
---------------

:Name:          ``Out_s2m``
:Type:          ``axi4lite.T_AXI4Lite_Bus_s2m``
:Mode:          in
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.


.. _IP/axi4_to_AXI4Lite/configuration:

Configuration
*************

.. todo:: tbd


.. _IP/axi4_to_AXI4Lite/UsedIn:

Use in
******

* tbd
