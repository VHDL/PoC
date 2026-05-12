.. _IP/AXI4Lite_Ocram_Adapter:
.. index::
   single: AXI4-Lite; AXI4Lite_Ocram_Adapter

AXI4Lite_Ocram_Adapter
###########################

.. todo::

.. _IP/AXI4Lite_Ocram_Adapter/goals:

.. topic:: Design Goals

   * *tbd*


.. _IP/AXI4Lite_Ocram_Adapter/features:

.. topic:: Features

   * *tbd*


.. _IP/AXI4Lite_Ocram_Adapter/instantiation:

Instantiation
*************

.. _IP/AXI4Lite_Ocram_Adapter/inst/Simple:

.. grid:: 2

   .. grid-item::
      :columns: 5

      .. todo:: needs documentation

   .. grid-item-card::
      :columns: 7

      .. code-block:: vhdl

         Ocram_Adapter : entity PoC.AXI4Lite_Ocram_Adapter
         generic map (
            OCRAM_ADDRESS_BITS    => 10,
            OCRAM_DATA_BITS       => 32
         ) port map (
           Clock                 => Clock,
           Reset                 => Reset,

           AXI4Lite_m2s          => AXI4Lite_m2s,
           AXI4Lite_s2m          => AXI4Lite_s2m,

           Write_En              => Write_En,
           Address               => Address,
           Data_In               => Data_In,
           Data_Out              => Data_Out
         );

.. _IP/AXI4Lite_Ocram_Adapter/inst/Xilinx:


Interface
*********

.. _IP/AXI4Lite_Ocram_Adapter/generics:

Generics
========

.. _IP/AXI4Lite_Ocram_Adapter/gen/OCRAM_ADDRESS_BITS:

:generic:`OCRAM_ADDRESS_BITS`
----------------------------

:Name:          :generic:`OCRAM_ADDRESS_BITS`
:Type:          :type:`positive`
:Default Value: — — — —
:Description:   *tbd*


.. _IP/AXI4Lite_Ocram_Adapter/gen/OCRAM_DATA_BITS:

:generic:`OCRAM_DATA_BITS`
---------------------------

:Name:          :generic:`OCRAM_DATA_BITS`
:Type:          :type:`positive`
:Default Value: — — — —
:Description:   *tbd*


.. _IP/AXI4Lite_Ocram_Adapter/gen/PREFFERED_READ_ACCESS:

:generic:`PREFFERED_READ_ACCESS`
--------------------------

:Name:          :generic:`PREFFERED_READ_ACCESS`
:Type:          :type:`boolean`
:Default Value: TRUE
:Description:   *tbd*


.. _IP/AXI4Lite_Ocram_Adapter/ports:

Ports
=====

.. _IP/AXI4Lite_Ocram_Adapter/port/Clock:

:port:`Clock`
-------------

:Name:          :port:`Clock`
:Type:          :type:`std_logic`
:Mode:          in
:Default Value: — — — —
:Description:   Clock


.. _IP/AXI4Lite_Ocram_Adapter/port/Reset:

:port:`Reset`
-------------

:Name:          :port:``Reset`
:Type:          :type:`std_logic`
:Mode:          in
:Default Value: — — — —
:Description:   synchronous high-active reset


.. _IP/AXI4Lite_Ocram_Adapter/port/AXI4Lite_M2S:

:port:`AXI4Lite_M2S`
--------------------

:Name:          :port:`AXI4Lite_M2S`
:Type:          :type:`axi4lite.T_AXI4Lite_Bus_m2s`
:Mode:          in
:Default Value: — — — —
:Description:   AXI4-Lite manager to subordinate signals.


.. _IP/AXI4Lite_Ocram_Adapter/port/AXI4Lite_s2m:

:port:`AXI4Lite_s2m`
--------------------

:Name:          :port:`AXI4Lite_s2m`
:Type:          :type:`axi4lite.T_AXI4Lite_Bus_s2m`
:Mode:          out
:Default Value: — — — —
:Description:   AXI4-Lite subordinate to manager signals.


.. _IP/AXI4Lite_Ocram_Adapter/port/Write_En:

:port:`Write_En`
--------------------

:Name:          :port:`Write_En`
:Type:          :type:`std_logic`
:Mode:          out
:Default Value: — — — —
:Description:   Write enable.


.. _IP/AXI4Lite_Ocram_Adapter/port/Address:

:port:`Address`
--------------------

:Name:          :port:`Address`
:Type:          :type:`unsigned(OCRAM_ADDRESS_BITS-1 downto 0)`
:Mode:          out
:Default Value: — — — —
:Description:   *tbd*


.. _IP/AXI4Lite_Ocram_Adapter/port/Data_In:

:port:`Data_In`
--------------------

:Name:          :port:`Data_In`
:Type:          :type:`unsigned(OCRAM_ADDRESS_BITS-1 downto 0)`
:Mode:          in
:Default Value: — — — —
:Description:   *tbd*


.. _IP/AXI4Lite_Ocram_Adapter/port/Data_Out:

:port:`Data_Out`
--------------------

:Name:          :port:`Data_Out`
:Type:          :type:`unsigned(OCRAM_ADDRESS_BITS-1 downto 0)`
:Mode:          out
:Default Value: — — — —
:Description:   *tbd*


.. _IP/AXI4Lite_Ocram_Adapter/configuration:

Configuration
*************

.. _IP/AXI4Lite_Ocram_Adapter/config/User:

User defined Word
=================

.. todo:: tbd

Related Files
*************

*None*
