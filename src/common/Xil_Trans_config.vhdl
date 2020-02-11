-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:					Stefan Unrein
--
-- Package:					Global configuration settings.
--
-- Description:
-- -------------------------------------
--		This file evaluates the settings declared in the project specific package my_config.
--		See also template file my_config.vhdl.template.
--
-- License:
-- =============================================================================
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany,
--										 Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use     PoC.utils.all;
use			PoC.physical.all;

package Xil_Trans_config is
  subtype T_CPLL_FACT_M       is integer range 1 to 2;
  subtype T_CPLL_FACT_N2      is integer range 1 to 5;
  subtype T_CPLL_FACT_N1      is integer range 4 to 5;
  subtype T_CPLL_FACT_D_ROOT  is integer range 0 to 3;
  
  subtype T_QPLL_FACT_M       is integer range 1 to 4;
  subtype T_QPLL_FACT_D_ROOT  is integer range 0 to 4;
  subtype T_QPLL_FACT_N       is integer range 1 to 8;
  constant C_QPLL_FACT_N_VEC : integer_vector := (16, 20, 32, 40, 64, 66, 80, 100);
  
  type T_FACTORS is record
    M  : integer;
    N1 : integer;
    N2 : integer;
    D  : integer;
  end record;

  type T_GTX_GTH_PLL_SOURCE is (
    QPLL,
    CPLL
  );
  function to_slv(sel : T_GTX_GTH_PLL_SOURCE) return std_logic_vector;  
  
  type T_IS_GTH_GTX is (
    GTH,
    GTX
  );
  function check_pll_freq_is_in_bound(trans : T_IS_GTH_GTX; pll_freq : real; pll : T_GTX_GTH_PLL_SOURCE) return boolean;
  
  
  type T_GTX_GTH_REFCLOCK_SOURCE is (
    GTREFCLK0,
    GTREFCLK1,
    GTNORTHREFCLK0,
    GTNORTHREFCLK1,
    GTSOUTHREFCLK0,
    GTSOUTHREFCLK1,
    GTGREFCLK
  );
  function to_slv(sel : T_GTX_GTH_REFCLOCK_SOURCE) return std_logic_vector;

  type T_GTX_GTH_TXOUTCLKSEL is (
    Static_1,
    TXOUTCLKPCS,
    TXOUTCLKPMA,
    TXPLLREFCLK_DIV1,
    TXPLLREFCLK_DIV2
  );
  function to_slv(sel : T_GTX_GTH_TXOUTCLKSEL) return std_logic_vector;
  
  function calc_PLL_clk(f_in: real; factors: T_FACTORS; pll: T_GTX_GTH_PLL_SOURCE; trans : T_IS_GTH_GTX) return real;

end package;


package body Xil_Trans_config is
  
  function check_pll_freq_is_in_bound(trans : T_IS_GTH_GTX; pll_freq : real; pll : T_GTX_GTH_PLL_SOURCE) return boolean is
  begin
    if pll = QPLL then
      if trans = GTH then
        if (pll_freq > 8.0e9) and (pll_freq < 13.1e9) then
          return true;
        else
          return false;
        end if;
      else
        if (pll_freq > 5.93e9) and (pll_freq < 8.0e9) then
          return true;
        elsif (pll_freq > 9.8e9) and (pll_freq < 12.5e9) then
          return true;
        else
          return false;
        end if;
      end if;
    else
      if trans = GTH then
        if (pll_freq > 1.6e9) and (pll_freq < 5.16e9) then
          return true;
        else
          return false;
        end if;
      else
        if (pll_freq > 1.6e9) and (pll_freq < 3.3e9) then
          return true;
        else
          return false;
        end if;
      end if;
    end if;
  end function;
  
  function to_slv(sel : T_GTX_GTH_PLL_SOURCE) return std_logic_vector is
  begin
    case sel is
      when QPLL   => return "11";
      when CPLL   => return "00";
    end case;
  end function;

  function to_slv(sel : T_GTX_GTH_REFCLOCK_SOURCE) return std_logic_vector is
  begin
    case sel is
      when GTREFCLK0      => return "001";
      when GTREFCLK1      => return "010";
      when GTNORTHREFCLK0 => return "011";
      when GTNORTHREFCLK1 => return "100";
      when GTSOUTHREFCLK0 => return "101";
      when GTSOUTHREFCLK1 => return "110";
      when GTGREFCLK      => return "111";
    end case;
  end function;


  function to_slv(sel : T_GTX_GTH_TXOUTCLKSEL) return std_logic_vector is
  begin
    case sel is
      when TXOUTCLKPCS      => return "001";
      when TXOUTCLKPMA      => return "010";
      when TXPLLREFCLK_DIV1 => return "011";
      when TXPLLREFCLK_DIV2 => return "100";
      when others           => return "000";
    end case;
  end function;
  
  function calc_PLL_clk(f_in: real; factors: T_FACTORS; pll: T_GTX_GTH_PLL_SOURCE; trans : T_IS_GTH_GTX) return real is
  begin
    return f_in * (real(factors.N1) / (2.0 * real(factors.M)));
  end function;

end package body;
