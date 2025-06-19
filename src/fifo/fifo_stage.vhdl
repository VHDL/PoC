-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- =============================================================================
-- Authors:         Thomas B. Preusser
--                  Stefan Unrein
--
-- Entity:          Minimal FIFO, common clock (cc), pipelined interface, first-word-fall-through mode
--
-- Description:
-- -------------------------------------
-- Its primary use is the decoupling of enable domains in a processing
-- pipeline. Data storage is limited to two words only so as to allow both
-- the ``ful``  and the ``vld`` indicators to be driven by registers.
--
-- License:
-- =============================================================================
-- Copyright 2025-2025 The PoC-Library Authors
-- Copyright 2007-2016 Technische Universitaet Dresden - Germany
--                     Chair of VLSI-Design, Diagnostics and Architecture
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--    http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use IEEE.std_logic_1164.all;

entity fifo_Stage is
	generic (
		D_BITS       : positive;
		STAGES       : natural := 1;    -- 0 creates a passthrough, all values above creates one pipeline stage of the set depth
		LIGHT_WEIGHT : boolean := FALSE -- This option uses half of registers but oszilates between full and empty! Use only when restriction is acceptable (e.g. for Address channel in AXI)
	);
	port (
		-- Control
		clk : in std_logic; -- Clock
		rst : in std_logic; -- Synchronous Reset

		-- Input
		put : in std_logic;                             -- Put Value
		di  : in std_logic_vector(D_BITS - 1 downto 0); -- Data Input
		ful : out std_logic;                            -- Full

		-- Output
		vld : out std_logic;                             -- Data Available
		do  : out std_logic_vector(D_BITS - 1 downto 0); -- Data Output
		got : in std_logic                               -- Data Consumed
	);
end entity fifo_Stage;
architecture rtl of fifo_Stage is
begin

	passthroughGen : if STAGES > 0 generate
		subtype T_slv_d is std_logic_vector(D_BITS - 1 downto 0);
		type T_slvv_d is array(natural range <>) of T_slv_d;

		signal di_v : T_slvv_d(0 to STAGES - 1);-- := (others => (others => '0'));
		signal do_v : T_slvv_d(0 to STAGES - 1);-- := (others => (others => '0'));

		signal Avail_v : std_logic_vector(0 to STAGES - 1);
		signal Full_v  : std_logic_vector(0 to STAGES - 1);

		signal put_v : std_logic_vector(0 to STAGES - 1);
		signal got_v : std_logic_vector(0 to STAGES - 1);
	begin
		ful               <= Full_v(0);
		vld               <= Avail_v(Avail_v'high);
		do                <= do_v(do_v'high);
		di_v(0)           <= di;
		put_v(0)          <= put;
		got_v(got_v'high) <= got;

		connect_gen : for i in 1 to STAGES - 1 generate
			di_v(i)      <= do_v(i - 1);
			got_v(i - 1) <= not Full_v(i);
			put_v(i)     <= Avail_v(i - 1);
		end generate;

		LIGHT_WEIGHT_gen : if not LIGHT_WEIGHT generate
			genStage : for i in 0 to STAGES - 1 generate
				signal A : T_slv_d := (others => '0');
				signal B : T_slv_d := (others => '0');

				signal Avail : std_logic := '0';
				signal Full  : std_logic := '0';
			begin

				process (clk)
				begin
					if rising_edge(clk) then
						if rst = '1' then
							Full  <= '0';
							Avail <= '0';
						else
							Avail <= put_v(i) or (Avail and not got_v(i)) or Full;
							Full  <= Avail and not got_v(i) and (Full or put_v(i));
						end if;
					end if;
					if rising_edge(clk) then
						if Full = '0' then
							A <= di_v(i);
						end if;

						if (got_v(i) or not Avail) = '1' then
							if Full = '1' then
								B <= A;
							else
								B <= di_v(i);
							end if;
						end if;
					end if;
				end process;

				Full_v(i)  <= Full;
				Avail_v(i) <= Avail;
				do_v(i)    <= B;
			end generate;
		else generate
				genStage : for i in 0 to STAGES - 1 generate
					signal A : T_slv_d := (others => '0');
					signal B : T_slv_d := (others => '0');

					signal Avail : std_logic := '0';
					signal Full  : std_logic := '0';
				begin

					process (clk)
					begin
						if rising_edge(clk) then
							if rst = '1' then
								Avail <= '0';
							else
								if Avail = '1' then
									Avail <= not got_v(i);
								else
									Avail <= put_v(i);
								end if;
							end if;
						end if;
					end process;

					B <= di_v(i) when rising_edge(clk) and Avail = '0';

					Full_v(i)  <= Avail;
					Avail_v(i) <= Avail;
					do_v(i)    <= B;
				end generate;
			end generate;
		else generate
				ful <= not got;
				vld <= put;
				do  <= di;
			end generate;

		end architecture;
