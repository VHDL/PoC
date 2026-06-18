# =============================================================================
# Authors: Iqbal Asif (PLC2 Design GmbH)
#          Patrick Lehmann (PLC2 Design GmbH)
#
# License:
# =============================================================================
# Copyright 2025-2026 The PoC-Library Authors
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

include ./FIFO/RunAllTests.pro
include ./FIFO_CDC/RunAllTests.pro
include ./DeMux/RunAllTests.pro
include ./Mux/RunAllTests.pro
disabled ./Delay/RunAllTests.pro
disabled ./Splitter/RunAllTests.pro
disabled ./Realign/RunAllTests.pro
