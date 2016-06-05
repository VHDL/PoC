library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library UNISIM;
use			UNISIM.VcomponentS.all;

library L_Global;
use			PoC.GlobalTypes.all;

library L_SATAController;
use			L_SATAController.SATATypes.all;

entity SATATransceiver_Virtex6_ClockNetwork is
	generic (
		CLOCK_IN_FREQ_MHZ					: REAL													:= 150.0;							-- 150 MHz
		PORTS											: POSITIVE											:= 1
	);
	port (
		ClockIn_150MHz						: in	STD_LOGIC;																			--

		ClockNetwork_Reset				: in	STD_LOGIC;																			-- @async:
		ClockNetwork_ResetDone		:	OUT	STD_LOGIC;																			-- @ClockIn_150MHz:

		SATA_Generation						: in	T_SATA_GENERATION;		-- _VECTOR(PORTS - 1 downto 0);

		GTX_Clock_2X							: out	STD_LOGIC;		-- _VECTOR(PORTS - 1 downto 0);
		GTX_Clock_4X							: out	STD_LOGIC		-- _VECTOR(PORTS - 1 downto 0)
	);
end;

architecture rtl of SATATransceiver_Virtex6_ClockNetwork is
	attribute KEEP											: BOOLEAN;

	signal ClkNet_Reset_i								: STD_LOGIC;
	signal ClkNet_Reset_r1							: STD_LOGIC													:= '0';
	signal ClkNet_Reset_r2							: STD_LOGIC													:= '0';
	signal ClkNet_Reset									: STD_LOGIC;

	signal MMCM_Reset										: STD_LOGIC;
	signal MMCM_Locked_i								: STD_LOGIC;
	signal MMCM_Locked_d1								: STD_LOGIC													:= '0';
	signal MMCM_Locked_d2								: STD_LOGIC													:= '0';
	signal MMCM_Locked									: STD_LOGIC;

	signal MMCM_ClockFB									: STD_LOGIC;
	signal MMCM_Clock_150MHz						: STD_LOGIC;
	signal MMCM_Clock_75MHz							: STD_LOGIC;
	signal MMCM_Clock_37_5MHz						: STD_LOGIC;

	signal MMCM_ClockFB_BUFG						: STD_LOGIC;
	signal MMCM_Clock_150MHz_BUFG				: STD_LOGIC;
	signal MMCM_Clock_75MHz_BUFG				: STD_LOGIC;
	signal MMCM_Clock_37_5MHz_BUFG			: STD_LOGIC;

	attribute KEEP OF MMCM_Clock_150MHz_BUFG		: signal IS CHIPSCOPE_KEEP;
	attribute KEEP OF MMCM_Clock_75MHz_BUFG			: signal IS CHIPSCOPE_KEEP;
	attribute KEEP OF MMCM_Clock_37_5MHz_BUFG		: signal IS CHIPSCOPE_KEEP;

	attribute KEEP OF ClockIn_150MHz						: signal IS CHIPSCOPE_KEEP;

	function IsSupportedGeneration(SATAGen : T_SATA_GENERATION) return BOOLEAN is
	begin
		case SATAGen is
			when SATA_GENERATION_1 =>			return TRUE;
			when SATA_GENERATION_2 =>			return TRUE;
			when others =>								return FALSE;
		end case;
	end;

begin
	-- reset generation
	-- ======================================================================
	-- clock network resets
	ClkNet_Reset_i							<= ClockNetwork_Reset;																					-- @async:

	-- D-FF @ClockIn_150MHz with async reset
	process(ClockIn_150MHz)
	begin
		if ((ClkNet_Reset_r2 = '1') AND (MMCM_Locked = '0')) then
			ClkNet_Reset_r1			<= '0';
			ClkNet_Reset_r2			<= '0';
		else
			if rising_edge(ClockIn_150MHz) then
				ClkNet_Reset_r1		<= ClkNet_Reset_i;
				ClkNet_Reset_r2		<= ClkNet_Reset_r1;
			end if;
		end if;
	end process;

	ClkNet_Reset								<= ClkNet_Reset_r2;																							-- @ClockIn_150MHz:
	MMCM_Reset									<= ClkNet_Reset;																								-- @ClockIn_150MHz:

	-- resetdone evaluation
	-- ======================================================================
	MMCM_Locked_d1							<= MMCM_Locked_i		when rising_edge(ClockIn_150MHz);
	MMCM_Locked_d2							<= MMCM_Locked_d1		when rising_edge(ClockIn_150MHz);
	MMCM_Locked									<= MMCM_Locked_d2;																							-- @ClockIn_150MHz:

	ClockNetwork_ResetDone			<= MMCM_Locked;																									-- @ClockIn_150MHz:

	-- ==================================================================
	-- ClockBuffers
	-- ==================================================================
	-- Feedback BUFG
	BUFG_ClockFB : BUFG
		port map (
			I		=> MMCM_ClockFB,
			O		=> MMCM_ClockFB_BUFG
		);

	gen1 : for i in 0 to 0 generate
		signal SATA_Generation_d	: T_SATA_GENERATION			:= SATA_GENERATION_2;		-- FIXME: use INITIAL_SATA_GENERATION !!!!
		signal MuxControl					: STD_LOGIC;
	begin
--		SATA_Generation_d(I)	<= SATA_Generation(I) when rising_edge(ClockIn_150MHz);
--		MuxControl						<= to_sl(SATA_Generation_d(I) = SATA_GENERATION_2);
		SATA_Generation_d	<= SATA_Generation when rising_edge(ClockIn_150MHz);
		MuxControl						<= to_sl(SATA_Generation_d = SATA_GENERATION_2);

		-- half SATA-Word-Clock (GTX 16/20 bit internal interfaces)
		MUX_Clock_2X : BUFGMUX
			port map (
				S		=> MuxControl,
				I0	=> MMCM_Clock_75MHz,
				I1	=> MMCM_Clock_150MHz,
				O		=> GTX_Clock_2X
			);

		-- SATA-Word-Clock (GTX 32 bit interface)
		MUX_Clock_4X : BUFGMUX
			port map (
				S		=> MuxControl,
				I0	=> MMCM_Clock_37_5MHz,
				I1	=> MMCM_Clock_75MHz,
				O		=> GTX_Clock_4X
			);
	end generate;

	-- ==================================================================
	-- Mixed-Mode Clock Manager (MMCM)
	-- ==================================================================
	GTX_MMCM : MMCM_ADV
		generic map (
			BANDWIDTH								=> "LOW",																	-- LOW = Jitter Filter
			COMPENSATION						=> "ZHOLD",
			CLOCK_HOLD							=> TRUE,
			STARTUP_WAIT						=> FALSE,

			CLKIN1_PERIOD						=> Freq_MHz2Real_ns(CLOCK_IN_FREQ_MHZ),
			CLKIN2_PERIOD						=> Freq_MHz2Real_ns(100.0),								-- Not used

			CLKFBOUT_MULT_F					=> 8.0,
			CLKFBOUT_PHASE					=> 0.0,
			CLKFBOUT_USE_FINE_PS		=> FALSE,

			DIVCLK_DIVIDE						=> 1,

			CLKOUT0_DIVIDE_F				=> 8.0,
			CLKOUT0_PHASE						=> 0.0,
			CLKOUT0_DUTY_CYCLE			=> 0.500,
			CLKOUT0_USE_FINE_PS			=> FALSE,

			CLKOUT1_DIVIDE					=> 16,
			CLKOUT1_PHASE						=> 0.0,
			CLKOUT1_DUTY_CYCLE			=> 0.500,
			CLKOUT1_USE_FINE_PS			=> FALSE,

			CLKOUT2_DIVIDE					=> 32,
			CLKOUT2_PHASE						=> 0.0,
			CLKOUT2_DUTY_CYCLE			=> 0.500,
			CLKOUT2_USE_FINE_PS			=> FALSE,

			CLKOUT3_DIVIDE					=> 1,
			CLKOUT3_PHASE						=> 0.0
		)
		port map (
			RST									=> MMCM_Reset,

			CLKIN1							=> ClockIn_150MHz,
			CLKIN2							=> ClockIn_150MHz,
			CLKINSEL						=> '1',
			CLKINSTOPPED				=> open,

			CLKFBOUT						=> MMCM_ClockFB,
			CLKFBOUTB						=> open,
			CLKFBIN							=> MMCM_ClockFB_BUFG,
			CLKFBSTOPPED				=> open,

			CLKOUT0							=> MMCM_Clock_150MHz,
			CLKOUT0B						=> open,
			CLKOUT1							=> MMCM_Clock_75MHz,
			CLKOUT1B						=> open,
			CLKOUT2							=> MMCM_Clock_37_5MHz,
			CLKOUT2B						=> open,
			CLKOUT3							=> open,
			CLKOUT3B						=> open,
			CLKOUT4							=> open,
			CLKOUT5							=> open,
			CLKOUT6							=> open,

			-- Dynamic Reconfiguration Port
			DO									=>	open,
			DRDY								=>	open,
			DADDR								=>	"0000000",
			DCLK								=>	'0',
			DEN									=>	'0',
			DI									=>	x"0000",
			DWE									=>	'0',

			PWRDWN							=>	'0',
			LOCKED							=>	MMCM_Locked_i,

			PSCLK								=>	'0',
			PSEN								=>	'0',
			PSINCDEC						=>	'0',
			PSDONE							=>	open
		);

end;
