# =============================================================================
# Authors:
#  Gustavo Martin
#
# Description:
#  RunAllTests.pro for PoC.fifo OSVVM testbench suite
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

# FIFO with Common Clock (cc), pipelined interface
include ./fifo_cc_got/RunAllTests.pro

# FIFO with Common Clock (cc), temporary put with commit/rollback
# include ./fifo_cc_got_tempput/RunAllTests.pro

# # FIFO with Independent Clocks (ic), address-based stream assembly
# include ./fifo_ic_assembly/RunAllTests.pro

# # FIFO with Independent Clocks (ic), first-word-fall-through
# include ./fifo_ic_got/RunAllTests.pro
