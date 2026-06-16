# =============================================================================
# Authors:         Stefan Unrein
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

analyze ./iic.pkg.vhdl
analyze ./iic_BusController.vhdl
analyze ./iic_Controller.vhdl
# analyze ./iic_Controller_SFF8431.vhdl # Curently not working
# analyze ./iic_IICSwitch_PCA9548A.vhdl # Curently not working
# analyze ./iic_IOB_Pad.vhdl            # Curently not working
analyze ./iic_Passthrough.vhdl
analyze ./iic_RawDemux.vhdl
analyze ./iic_RawMux.vhdl
