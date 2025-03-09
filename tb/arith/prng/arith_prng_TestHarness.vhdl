-- =============================================================================
-- Authors:
--   Jonas Schreiner
--
-- License:
-- =============================================================================
-- Copyright (c) 2024 PLC2 Design GmbH - All Rights Reserved
-- Unauthorized copying of this file, via any medium is strictly prohibited.
-- Proprietary and confidential
-- =============================================================================

library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;

library osvvm;
context osvvm.OsvvmContext;


entity arith_prng_TestHarness is
end entity;


architecture TestHarness of arith_prng_TestHarness is
	constant TPERIOD_CLOCK : time := 10 ns;

	constant BITS : positive := 8;
	constant SEED : std_logic_vector := x"12";

	signal Clock_100 : std_logic := '1';
	signal Reset_100 : std_logic := '1';

	signal Got   : std_logic;
	signal Value : std_logic_vector(BITS - 1 downto 0);


	component arith_prng_TestController is
		port (
			Clock : in  std_logic;
			Reset : in  std_logic;
			Got   : out std_logic;
			Value : in  std_logic_vector
		);
	end component;

begin
	Osvvm.TbUtilPkg.CreateClock(
		Clk    => Clock_100,
		Period => TPERIOD_CLOCK
	);

	Osvvm.TbUtilPkg.CreateReset(
		Reset       => Reset_100,
		ResetActive => '1',
		Clk         => Clock_100,
		Period      => 5 * TPERIOD_CLOCK,
		tpd         => 0 ns
	);

	DUT : entity PoC.arith_prng
		generic map (
			BITS		     => BITS,
			SEED		     => SEED
		)
		port map (
			Clock        => Clock_100,
			Reset        => Reset_100,

			InitialValue => SEED,
			Got          => Got,
			Value        => Value
		);

	TestCtrl: component arith_prng_TestController
		port map (
			Clock => Clock_100,
			Reset => Reset_100,
			Got   => Got,
			Value => Value
		);
end architecture;
