# =============================================================================
# Authors:
#  Gustavo Martin
#
# Description:
#  RunAllTests.pro for fifo_cc_got OSVVM testbench
#  Uses Verification Components with Transaction interfaces
#  Uses FifoFillPkg for sophisticated burst patterns
#
# License:
# =============================================================================
# Copyright 2025-2025 The PoC-Library Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

TestSuite PoC.fifo.cc.got
library tb_fifo_cc_got

# Analyze Verification Component packages and entities
# Note: FifoCcGotTransactionPkg is no longer needed - using OSVVM's StreamRecType
analyze FifoCcGotComponentPkg.vhdl
analyze FifoCcGotTransmitter.vhdl
analyze FifoCcGotReceiver.vhdl

# Analyze Test Controller package and entity
analyze fifo_cc_got_TestController_pkg.vhdl
analyze fifo_cc_got_TestController.vhdl

# Analyze Test Harness (instantiates DUT and VCs)
analyze fifo_cc_got_TestHarness.vhdl

# Run all tests for each configuration (CONFIG_INDEX 0 to 7)
# CONFIG_INDEX bits: [2]=OUTPUT_REG, [1]=STATE_REG, [0]=DATA_REG
for {set config 0} {$config < 8} {incr config} {

  # Run Simple test
  TestCase fifo_cc_got_Simple_Config_$config
  RunTest fifo_cc_got_Simple.vhdl [generic CONFIG_INDEX $config]
  
  # Run Flags test
  TestCase fifo_cc_got_Flags_Config_$config
  RunTest fifo_cc_got_FullEmpty_Flags.vhdl [generic CONFIG_INDEX $config]
  
  # Run Burst test
  TestCase fifo_cc_got_Burst_Config_$config
  RunTest fifo_cc_got_Burst.vhdl [generic CONFIG_INDEX $config]
  
  # Run Random test
  TestCase fifo_cc_got_Random_Config_$config
  RunTest fifo_cc_got_Random.vhdl [generic CONFIG_INDEX $config]
  
}
