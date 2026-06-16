-- =============================================================================
-- Authors:
--  Stefan Unrein (PLC2 Design GmbH)
--
--
-- License:
-- =============================================================================
-- Copyright 2025-2026 The PoC-Library Authors
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE ;
use     IEEE.std_logic_1164.all ;
use     IEEE.numeric_std.all ;

library PoC;
use     PoC.config.all;
use     PoC.stream.all;
use     PoC.vectors.all;
use     PoC.strings.all;
use     PoC.utils.all;

library OSVVM ;
context OSVVM.OsvvmContext ;
use     OSVVM.ScoreBoardPkg_slv.all;

library OSVVM_AXI4;
context OSVVM_AXI4.AxiStreamContext;


-- entity TestControl is
	-- generic (
		-- MIN_PACKET_SIZE    : positive := 1;
		-- MAX_PACKET_SIZE    : positive := 500;
		-- NUM_PACKETS        : positive := 15;
		-- MIN_WAIT_CYCLE     : natural  := 1;
		-- MAX_WAIT_CYCLE     : natural  := 1000;
		-- MIN_BACKPRESS_CYCLE: natural  := 1;
		-- MAX_BACKPRESS_CYCLE: natural  := 500
	-- );
	-- port (
		-- -- Global Signal Interface
		-- Clock_sys           : In    std_logic ;
		-- Reset_sys           : In    std_logic ;

		-- Stream_RX_Pause     : out std_logic_vector;
		-- Hit_Vector          : out std_logic_vector

		-- Stream_TX_Transaction       : inout StreamRecType;
		-- Stream_RX_Transaction       : inout StreamRecType_Vector
	-- );
-- end entity;

architecture TC_a4 of TestControl is
	constant NUMBER_PORTS    : positive := Stream_RX_Transaction'length;

	signal TestDone          : integer_barrier := 1 ;

	signal GenTX0_tgl        : std_logic := '0';
	signal GenTX0_done_tgl   : std_logic := '0';
	signal GenTX1_tgl        : std_logic := '0';
	signal GenTX1_done_tgl   : std_logic := '0';

	signal AXI4Stream_SB : ScoreboardIDArrayType(1 to NUMBER_PORTS);

	function mask_data(slv : std_logic_vector; be : std_logic_vector) return std_logic_vector is
		variable temp : std_logic_vector(slv'length -1 downto 0);
	begin
		assert slv'length / 8 = be'length report "mask_data-size dosnt match!" severity failure;
		for i in 0 to be'length -1 loop
			if be(i + be'low) = '1' then
				temp(i * 8 +7 downto i*8) := slv(i * 8 +7 + slv'low downto i*8 + slv'low);
			else
				temp(i * 8 +7 downto i*8) := (others => 'X');
			end if;
		end loop;
		return temp;
	end function;

begin

	BaseProc : process
	begin
		-- Initialization of test
		SetAlertLogName("TC_DeMux_a4") ;
		TranscriptOpen;
		SetTranscriptMirror(TRUE);
		AXI4Stream_SB <= NewID("AXI4Stream_SB", NUMBER_PORTS);
		LOG("PoC.Bus/AXI/AXI4Stream/DeMux Testbench.");
		LOG("Start of Test 4: Random transfer multi Dest, ADD_MIRROR_MODE => true, ADD_OUTPUT_GLUE => true, ENABLE_REVERSE_USER => false");

		SetLogEnable(PASSED, false);    -- Enable PASSED logs
		SetLogEnable(INFO,   false);    -- Enable INFO logs

		-- Wait for testbench initialization
		wait for 0 ns ;

		-- Wait for Design Reset
		wait until Reset_sys = '0';
		ClearAlerts ;
		LOG("Start of Transactions");

		wait for 1 us;

		-- Wait for test to finish
		WaitForBarrier(TestDone, 10 ms);

		wait for 1 us;

		AlertIf(NOW >= 10 ms, "Simulation finished due to timeout!");
		AlertIf(GetAffirmCount < 50, "Test is not Self-Checking");

		print("") ;
		EndOfTestReports;--(ReportAll => true);
		print("") ;
		TranscriptClose;
		std.env.stop;
		wait ;
	end process;

	Axi4Stream_TX : process
		variable OpRV      : RandomPType ;
		variable NoOpRV    : RandomPType ;
		variable BytesRV   : RandomPType ;
		variable GapRV     : RandomPType ;
		variable Bytes     : natural;

		variable Data : std_logic_vector(63 downto 0) ;
		variable SData : std_logic_vector(71 downto 0) ;
		variable Keep : std_logic_vector(7 downto 0) ;
	begin

		OpRV.InitSeed(OpRv'instance_name);
		NoOpRV.InitSeed(NoOpRV'instance_name);
		BytesRV.InitSeed(BytesRV'instance_name);
		GapRV.InitSeed(GapRV'instance_name);
		Hit_Vector <= (others => '0');

		wait until Reset_sys = '0' ;
		wait for 50 ns;

		for index in 0 to NUM_PACKETS -1 loop
			Bytes := BytesRV.RandInt(MIN_PACKET_SIZE, MAX_PACKET_SIZE);
			Hit_Vector <= BytesRV.RandSlv(size => NUMBER_PORTS);
			wait for 0 ns;

			for i in 0 to (Bytes +7) / 8 -2 loop
				Data   := OpRV.RandSlv(size => 64);
				Keep   := x"FF";
				SData := Keep & Data;
				for j in Hit_Vector'range loop
					if Hit_Vector(j) = '1' then
						Push(AXI4Stream_SB(j +1), '0' & mask_data(Data, Keep));
						wait for 0 ns;
					end if;
				end loop;
				Send(Stream_TX_Transaction, SData);
				wait for 0 ns;
			end loop;
			Data   := OpRV.RandSlv(size => 64);
			Keep   := genmask_low(ite((Bytes mod 8) = 0, 8, (Bytes mod 8)), 8);
			SData := Keep & Data;

			for j in Hit_Vector'range loop
				if Hit_Vector(j) = '1' then
					Push(AXI4Stream_SB(j +1), '1' & mask_data(Data, Keep));
				end if;
			end loop;
			Send(Stream_TX_Transaction, SData, "1");
			wait for NoOpRV.RandInt(MIN_WAIT_CYCLE, MAX_WAIT_CYCLE) * ns;
		end loop;

		wait for 1 us;

		WaitForBarrier(TestDone);
		wait;
	end process;

	RX_gen : for index in 1 to NUMBER_PORTS generate
		AXI4Stream_RX : process
			variable OpRV      : RandomPType ;
			variable NoOpRV    : RandomPType ;

			variable SData : std_logic_vector(71 downto 0) ;
			variable Data : std_logic_vector(63 downto 0) ;
			variable Keep : std_logic_vector(7 downto 0) ;
			variable Last : std_logic_vector(3 downto 0);
		begin
			OpRV.InitSeed(OpRv'instance_name);
			NoOpRV.InitSeed(NoOpRV'instance_name);
			Stream_RX_Pause(index -1) <= '0';

			wait until Reset_sys = '0' ;
			while true loop
				for i in 0 to OpRV.RandInt(1, 5) loop
					Get(Stream_RX_Transaction(index -1), SData, Last);
					Data   := SData(63 downto 0);
					Keep   := SData(71 downto 64);
					Check(AXI4Stream_SB(index), Last(0) & mask_data(Data, Keep));
				end loop;

				Stream_RX_Pause(index -1) <= '1';
				wait for NoOpRV.RandInt(MIN_BACKPRESS_CYCLE, MAX_BACKPRESS_CYCLE) * 1 ns;
				Stream_RX_Pause(index -1) <= '0';
			end loop;
		end process;
	end generate;

end architecture;


Configuration TC_DeMux_a4 of DeMux_Harness is
	for Harness
		for TestControl_inst : TestControl
			use entity work.TestControl(TC_a4)
			generic map(
				MIN_PACKET_SIZE     => 1,
				MAX_PACKET_SIZE     => 500,
				NUM_PACKETS         => 1500,
				MIN_WAIT_CYCLE      => 0,
				MAX_WAIT_CYCLE      => 4,
				MIN_BACKPRESS_CYCLE => 1,
				MAX_BACKPRESS_CYCLE => 5
			);
		end for;
		for DUT : axi4stream_DeMux
			use entity PoC.axi4stream_DeMux
			generic map(
				ADD_MIRROR_MODE     =>  true,
				OUTPUT_STAGES       =>  1,
				ENABLE_REVERSE_USER =>  false
			);
		end for;
	end for;
end Configuration;

