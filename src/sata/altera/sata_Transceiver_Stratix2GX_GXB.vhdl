-- EDITOR Settings
-- emacs: -*- tab-width:2 -*-
-- kate: tab-width=2
-- vim: set tabstop=2

library IEEE;
use		IEEE.STD_LOGIC_1164.all;
use		IEEE.NUMERIC_STD.all;

library PoC;
use		PoC.config.all;
use		PoC.sata.all;
use		PoC.utils.all;
use		PoC.vectors.all;
use		PoC.strings.all;
use		PoC.physical.all;
use		PoC.sata_TransceiverTypes.all;
use		PoC.satadbg.all;


entity sata_Transceiver_Stratix2GX_GXB is
	generic (
		CLOCK_IN_FREQ							: FREQ											:= 150 MHz;
		PORTS											: positive									:= 2;			-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR	:= (0 => C_SATA_GENERATION_MAX, 1 => C_SATA_GENERATION_MAX)	-- intial SATA Generation
	);
	port (
		ClockNetwork_Reset			: in	std_logic_vector(PORTS - 1 downto 0);
		ClockNetwork_ResetDone	: out	std_logic_vector(PORTS - 1 downto 0);
		Reset										: in	std_logic_vector(PORTS - 1 downto 0);
		ResetDone								: out	std_logic_vector(PORTS - 1 downto 0);

		PowerDown		: in	std_logic_vector(PORTS - 1 downto 0);
		Command			: in	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 downto 0);
		Status			: out	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 downto 0);
		Error				: out	T_SATA_TRANSCEIVER_ERROR_VECTOR(PORTS - 1 downto 0);

		-- debug ports
--		DebugPortIn		: in	T_SATADBG_TRANSCEIVER_IN_VECTOR(PORTS	- 1 downto 0);
--		DebugPortOut		: out	T_SATADBG_TRANSCEIVER_OUT_VECTOR(PORTS	- 1 downto 0);

		SATA_Clock		: out	std_logic_vector(PORTS - 1 downto 0);
		SATA_Clock_Stable	: out	std_logic_vector(PORTS - 1 downto 0);

		RP_Reconfig		: in	std_logic_vector(PORTS - 1 downto 0);
		RP_SATAGeneration	: in	T_SATA_GENERATION_VECTOR(PORTS - 1 downto 0);
		RP_ReconfigComplete	: out	std_logic_vector(PORTS - 1 downto 0);
		RP_ConfigReloaded	: out	std_logic_vector(PORTS - 1 downto 0);
		RP_Lock			: in	std_logic_vector(PORTS - 1 downto 0);
		RP_Locked		: out	std_logic_vector(PORTS - 1 downto 0);

		OOB_TX_Command		: in	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
		OOB_TX_Complete		: out	std_logic_vector(PORTS - 1 downto 0);
		OOB_RX_Received		: out	T_SATA_OOB_VECTOR(PORTS - 1 downto 0);
		OOB_HandshakeComplete	: in	std_logic_vector(PORTS - 1 downto 0);

		TX_Data			: in	T_SLVV_32(PORTS - 1 downto 0);
		TX_CharIsK		: in	T_SLVV_4(PORTS - 1 downto 0);

		RX_Data			: out	T_SLVV_32(PORTS - 1 downto 0);
		RX_CharIsK		: out	T_SLVV_4(PORTS - 1 downto 0);
		RX_Valid		: out	std_logic_vector(PORTS - 1 downto 0);

		-- Altera specific GXB ports
		-- needs to be split in IN and OUT
		VSS_Common_In		: in	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In		: in	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS - 1 downto 0);
		VSS_Private_Out		: out	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS - 1 downto 0)
	);
end;

architecture rtl of sata_Transceiver_Stratix2GX_GXB is

	constant C_DEVICE_INFO			: T_DEVICE_INFO		:= DEVICE_INFO;

	signal reconf_clk	: std_logic;
	signal refclk		: std_logic;

begin
-- ==================================================================
-- Assert statements
-- ==================================================================
	assert (C_DEVICE_INFO.Vendor = VENDOR_ALTERA)							report "Vendor not yet supported."				severity FAILURE;
	assert (C_DEVICE_INFO.DevFamily = DEVICE_FAMILY_STRATIX)	report "Device family not yet supported."	severity FAILURE;
	assert (C_DEVICE_INFO.Device = DEVICE_STRATIX2)						report "Device not yet supported."				severity FAILURE;
	assert (PORTS <= 2)			report "To many ports per transceiver."		severity FAILURE;

-- 	Common modules shared by all ports
	clk_div : clock_div
	port map (
		clk => refclk,
		clk2 => open,
		clk4 => reconf_clk
	);
	cal_unit : gxb_calib
	port map (
		clk => reconf_clk
	);

	refclk <= VSS_Common_In.RefClockIn_150_MHz;

-- 	Port specific modules
	gen_ports : for i in 0 to PORTS-1 generate
		signal ll_clk		: std_logic;
		signal reconf		: std_logic;

		signal gxb_busy		: std_logic;
		signal gxb_locked	: std_logic;
		signal pll_busy		: std_logic;
		signal pll_locked	: std_logic;

		signal sfp_rx		: std_logic;
		signal sfp_tx		: std_logic;

		signal tx_ctrlin        : std_logic_vector(3 downto 0);
		signal tx_datain	: std_logic_vector(31 downto 0);
		signal tx_forceelecidle	: std_logic;
		signal tx_oob_command	: T_SATA_OOB := SATA_OOB_NONE;
		signal tx_oob_complete 	: std_logic;

		signal rx_clkout	: std_logic;
		signal rx_ctrlout	: std_logic_vector(3 downto 0);
		signal rx_dataout	: std_logic_vector(31 downto 0);
		signal rx_signaldetect  : std_logic;
		signal rx_errdetect	: std_logic_vector(3 downto 0);
		signal rx_errin		: std_logic_vector(3 downto 0);
		signal rx_oob_status	: T_SATA_OOB;

		signal sata_rx_ctrl	: std_logic_vector(3 downto 0);
		signal sata_rx_data	: std_logic_vector(31 downto 0);
		signal sata_syncstatus  : std_logic;
		signal sata_tx_ctrl	: std_logic_vector(3 downto 0);
		signal sata_tx_data	: std_logic_vector(31 downto 0);

		signal sata_gen		: std_logic_vector(1 downto 0) := to_slv(INITIAL_SATA_GENERATIONS(i),2);
		signal config_state	: std_logic_vector(15 downto 0) := (others => '0');
		signal gxb_locked_sync	: std_logic_vector(1 downto 0) := (others => '0');

	begin
		SATA_Clock(i) <= ll_clk;
		ClockNetwork_ResetDone(i) <= pll_locked and gxb_locked;

		-- rx & tx bit signal
		VSS_Private_Out(i).TX <= sfp_tx;
		sfp_rx <= VSS_Private_In(i).RX;

		RP_Locked(i) <= '0';
		RP_ReconfigComplete(i) <= config_state(14);
		RP_ConfigReloaded(i) <= config_state(15);

		-- TODO ? : Status Statemachine
		Status(i) <=	SATA_TRANSCEIVER_STATUS_RECONFIGURING when config_state /= (config_state'range => '0') else
				SATA_TRANSCEIVER_STATUS_INIT when gxb_locked_sync(1) = '0' else
				SATA_TRANSCEIVER_STATUS_READY;

		Error(i).RX <= SATA_TRANSCEIVER_RX_ERROR_NONE;
		Error(i).TX <= SATA_TRANSCEIVER_TX_ERROR_NONE;

		OOB_RX_Received(i) <= rx_oob_status;
		RX_Data(i) 	<= sata_rx_data;
		RX_CharIsK(i)	<= sata_rx_ctrl;
		RX_Valid(i)	<= sata_syncstatus;

		tx_oob_command 		<= OOB_TX_Command(i);
		OOB_TX_Complete(i) 	<= tx_oob_complete;
		sata_tx_data 		<= TX_Data(i);
		sata_tx_ctrl		<= TX_CharIsK(i);

		rx_errin(0) <= not gxb_locked or gxb_busy or rx_errdetect(0);
		rx_errin(1) <= not gxb_locked or gxb_busy or rx_errdetect(1);
		rx_errin(2) <= not gxb_locked or gxb_busy or rx_errdetect(2);
		rx_errin(3) <= not gxb_locked or gxb_busy or rx_errdetect(3);

		-- speed reconfiguration (link layer interface)
		process(ll_clk) begin
			if rising_edge(ll_clk) then
				if RP_Reconfig(i) = '1' then
					sata_gen <= to_slv(RP_SATAGeneration(i),2);
				end if;
				if gxb_busy = '0' and pll_busy = '0' then
					config_state <= config_state(14 downto 0) & RP_Reconfig(i);
				end if;
				gxb_locked_sync <= gxb_locked_sync(0) & gxb_locked;
			end if;
		end process;

		config_sync : entity PoC.EventSyncVector
		generic map (
			BITS => 2,
			INIT => to_slv(SATA_GENERATION_3,2)
		)
		port map (
			Clock1 => ll_clk,
			Clock2 => reconf_clk,
			src => sata_gen,
			strobe => reconf
		);

--		device_sync : entity PoC.EventSync
--		port map (
--			Clock1 => refclk,
--			Clock2 => ll_clk,
--			src => newdevice,
--			strobe => ll_newdevice
--		);

		sata_oob_unit : entity PoC.sata_oob
		port map (
			clk => refclk,
			rx_oob_status => rx_oob_status,
			rx_signaldetect => rx_signaldetect,
			tx_forceelecidle => tx_forceelecidle,
			tx_oob_command => tx_oob_command,
			tx_oob_complete => tx_oob_complete
		);

		output_adapter : sata_tx_adapter
		port map (
			tx_datain => sata_tx_data,
			tx_ctrlin => sata_tx_ctrl,
			tx_clkout => refclk,
			tx_ctrlout => tx_ctrlin,
			tx_dataout => tx_datain,
			sata_gen => sata_gen
		);

		input_adapter : sata_rx_adapter
		port map (
			rx_clkin => rx_clkout,
			rx_ctrlin => rx_ctrlout,
			rx_datain => rx_dataout,
			rx_errin => rx_errin,
			rx_clkout => ll_clk,
			rx_ctrlout => sata_rx_ctrl,
			rx_dataout => sata_rx_data,
			rx_syncout => sata_syncstatus,
			sata_gen => sata_gen
		);

		sata_io : sata_basic
		port map (
			inclk => refclk,
			reset => '0', --reset,
			locked => gxb_locked,
			rx_clkout => rx_clkout,
			rx_dataout => rx_dataout,
			rx_ctrlout => rx_ctrlout,
			rx_errdetect => rx_errdetect,
			rx_signaldetect => rx_signaldetect,
			rx_datain => sfp_rx,
			tx_clkin => refclk,
			tx_ctrlin => tx_ctrlin,
			tx_datain => tx_datain,
			tx_forceelecidle => tx_forceelecidle,
			tx_dataout => sfp_tx,
			reconf_clk => reconf_clk,
			reconfig => reconf,
			sata_gen => sata_gen,
			busy => gxb_busy
		);

		sata_clk : sata_pll
		port map (
			inclk => refclk,
			reset => '0', --reset,
			outclk => ll_clk,
			locked => pll_locked,
			reconf_clk => reconf_clk,
			reconfig => reconf,
			sata_gen => sata_gen,
			busy => pll_busy
		);

		-- ======================================================================
		-- Use generic module to generate SATA_Clock_Stable and ResetDone
		-- requires a MAXSKEW constraint of the signal driving Async_Reset
		-- ======================================================================
		ClockStable: entity work.sata_Transceiver_ClockStable
			port map (
				PLL_Locked		=> pll_locked,
				SATA_Clock		=> ll_clk,
				Kill_Stable		=> RP_Reconfig(i),
				ResetDone		=> ResetDone(i),
				SATA_Clock_Stable	=> SATA_Clock_Stable(i)
			);

	end generate;
end;
