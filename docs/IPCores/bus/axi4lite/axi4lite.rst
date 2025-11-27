.. _PKG/axi4lite:
.. index::
   single: AXI4-Lite; axi4lite Package

axi4lite Package
################

Enumerations
************

* ``T_AXI4Lite_RegisterModes``

  * ``ConstantValue``
  * ``ReadOnly``
  * ``ReadOnly_NotRegistered``
  * ``ReadWrite``
  * ``ReadWrite_NotRegistered``
  * ``LatchValue_ClearOnRead``
  * ``LatchValue_ClearOnWrite``
  * ``LatchHighBit_ClearOnRead``
  * ``LatchHighBit_ClearOnWrite``
  * ``LatchLowBit_ClearOnRead``
  * ``LatchLowBit_ClearOnWrite``
  * ``Reserved``


Types
*****

.. topic:: AXI4-Lite Bus

   * ``T_AXI4Lite_Bus_m2s``
   * ``T_AXI4Lite_Bus_s2m``
   * ``T_AXI4Lite_Bus_m2s_VECTOR``
   * ``T_AXI4Lite_Bus_s2m_VECTOR``

.. topic:: AXI4-Lite Register Descriptions

   * ``T_AXI4_Register``
   * ``T_AXI4_Register_Vector``


Constants
*********

.. topic:: AXI4 response codes

   * ``C_AXI4_RESPONSE_OKAY``
   * ``C_AXI4_RESPONSE_EX_OKAY``
   * ``C_AXI4_RESPONSE_SLAVE_ERROR``
   * ``C_AXI4_RESPONSE_DECODE_ERROR``
   * ``C_AXI4_RESPONSE_INIT``

.. topic:: AXI4 Cache settings

   * ``C_AXI4_CACHE_INIT``

.. topic:: AXI4 Protect settings

   * ``C_AXI4_PROTECT_INIT``


Subprograms
***********

.. topic:: Register Description

   * ``to_AXI4_Register``

.. topic:: Helper Functions

   * ``get_Index``
