-- EDITOR Settings
-- emacs: -*- tab-width:2 -*-
-- kate: tab-width=2
-- vim: set tabstop=2

LIBRARY IEEE;
USE		IEEE.STD_LOGIC_1164.ALL;
USE		IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE		PoC.config.ALL;
USE		PoC.sata.ALL;
USE		PoC.utils.ALL;
USE		PoC.vectors.ALL;
USE		PoC.strings.ALL;
USE		PoC.sata_TransceiverTypes.ALL;

entity sata_Transceiver_S2GX_GXB is
	generic (
		CLOCK_IN_FREQ_MHZ	: REAL	:= 150.0;	-- 150 MHz
		PORTS			: POSITIVE:= 2;	-- Number of Ports per Transceiver
		INITIAL_SATA_GENERATIONS	: T_SATA_GENERATION_VECTOR	:= T_SATA_GENERATION_VECTOR'(SATA_GENERATION_3, SATA_GENERATION_3)	-- intial SATA Generation
	);
	port (
		SATA_Clock		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		ResetDone		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		ClockNetwork_Reset	: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		ClockNetwork_ResetDone	: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		RP_Reconfig		: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_ReconfigComplete	: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_ConfigReloaded	: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_Lock			: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		RP_Locked		: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		SATA_Generation		: IN	T_SATA_GENERATION_VECTOR(PORTS - 1 DOWNTO 0);
		OOB_HandshakingComplete	: IN	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		Command		: IN	T_SATA_TRANSCEIVER_COMMAND_VECTOR(PORTS - 1 DOWNTO 0);
		Status		: OUT	T_SATA_TRANSCEIVER_STATUS_VECTOR(PORTS - 1 DOWNTO 0);
		RX_Error	: OUT	T_SATA_TRANSCEIVER_RX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);
		TX_Error	: OUT	T_SATA_TRANSCEIVER_TX_ERROR_VECTOR(PORTS - 1 DOWNTO 0);

		RX_OOBStatus	: OUT	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
		RX_Data		: OUT	T_SLVV_32(PORTS - 1 DOWNTO 0);
		RX_CharIsK	: OUT	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);
		RX_IsAligned	: OUT STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

		TX_OOBCommand	: IN	T_SATA_OOB_VECTOR(PORTS - 1 DOWNTO 0);
		TX_OOBComplete	: OUT	STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
		TX_Data		: IN	T_SLVV_32(PORTS - 1 DOWNTO 0);
		TX_CharIsK	: IN	T_SATA_CIK_VECTOR(PORTS - 1 DOWNTO 0);

--		DebugPortOut 	: OUT T_DBG_TRANSOUT_VECTOR(PORTS-1 DOWNTO 0);

		-- Altera specific GXB ports
		-- needs to be split in IN and OUT
		VSS_Common_In	: IN	T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS;
		VSS_Private_In	: IN	T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR(PORTS - 1 DOWNTO 0);
		VSS_Private_Out	: OUT	T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR(PORTS - 1 DOWNTO 0)
	);
end;

ARCHITECTURE rtl OF sata_Transceiver_S2GX_GXB IS

	CONSTANT NO_DEVICE_TIMEOUT_MS						: REAL					:= 50.0;		-- simulation: 20 us, synthesis: 50 ms
	CONSTANT NEW_DEVICE_TIMEOUT_MS						: REAL					:= 0.001;		-- FIXME: not used -> remove ???

	CONSTANT C_DEVICE_INFO										: T_DEVICE_INFO		:= DEVICE_INFO;

	signal reconf_clk	: std_logic;
	signal refclk		: std_logic;
	
BEGIN
-- ==================================================================
-- Assert statements
-- ==================================================================
	ASSERT (C_DEVICE_INFO.VENDOR = VENDOR_ALTERA)						REPORT "Vendor not yet supported."				SEVERITY FAILURE;
	ASSERT (C_DEVICE_INFO.DEVFAMILY = DEVICE_FAMILY_STRATIX)	REPORT "Device family not yet supported."	SEVERITY FAILURE;
	ASSERT (C_DEVICE_INFO.DEVICE = DEVICE_STRATIX2)					REPORT "Device not yet supported."				SEVERITY FAILURE;
	ASSERT (PORTS <= 2)			REPORT "To many ports per transceiver."		SEVERITY FAILURE;

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
		signal rx_electricalidle : std_logic;
		signal rx_errdetect	: std_logic_vector(3 downto 0);
		signal rx_errin		: std_logic_vector(3 downto 0);
		signal rx_oob_status	: T_SATA_OOB;
		signal rx_signaldetect	: std_logic;

		signal sata_rx_ctrl	: std_logic_vector(3 downto 0);
		signal sata_rx_data	: std_logic_vector(31 downto 0);
		signal sata_syncstatus  : std_logic;
		signal sata_tx_ctrl	: std_logic_vector(3 downto 0);
		signal sata_tx_data	: std_logic_vector(31 downto 0);

		signal sata_gen		: std_logic_vector(1 downto 0) := to_slv(INITIAL_SATA_GENERATIONS(i));
		signal config_state	: std_logic_vector(15 downto 0) := (others => '0');

		signal nodevice		: std_logic;
		signal newdevice	: std_logic;
		signal ll_newdevice	: std_logic;
		
	begin
		SATA_Clock(i) <= ll_clk;
		ResetDone(i) <= '1';
		ClockNetwork_ResetDone(i) <= '1';

		-- rx & tx bit signal
		VSS_Private_Out(i).TX <= sfp_tx;
		sfp_rx <= VSS_Private_In(i).RX;

		RP_Locked(i) <= '0';
		RP_ReconfigComplete(i) <= config_state(14);
		RP_ConfigReloaded(i) <= config_state(15);
		
		--	TODO ? : Status Statemachine -> see SATATransceiver_Virtex5_GTP.vhd
		Status(i) <=	SATA_TRANSCEIVER_STATUS_RESETING when Command(i) = SATA_TRANSCEIVER_CMD_RESET else
				SATA_TRANSCEIVER_STATUS_RECONFIGURING when gxb_busy = '1' or pll_busy = '1' else
				SATA_TRANSCEIVER_STATUS_NEW_DEVICE when ll_newdevice = '1' else
				SATA_TRANSCEIVER_STATUS_NO_DEVICE when nodevice = '1' else
				SATA_TRANSCEIVER_STATUS_READY;

		RX_Error(i) <= SATA_TRANSCEIVER_RX_ERROR_NONE;
		TX_Error(i) <= SATA_TRANSCEIVER_TX_ERROR_NONE;

		RX_OOBStatus(i) <= rx_oob_status;
		RX_Data(i) 	<= sata_rx_data;
		RX_CharIsK(i)	<= sata_rx_ctrl;
		RX_IsAligned(i)	<= sata_syncstatus;

		tx_oob_command 		<= TX_OOBCommand(i);
		TX_OOBComplete(i) 	<= tx_oob_complete;
		sata_tx_data 		<= TX_Data(i);
		sata_tx_ctrl		<= TX_CharIsK(i);

		rx_errin(0) <= not pll_locked or not gxb_locked or pll_busy or gxb_busy or rx_errdetect(0);
		rx_errin(1) <= not pll_locked or not gxb_locked or pll_busy or gxb_busy or rx_errdetect(1);
		rx_errin(2) <= not pll_locked or not gxb_locked or pll_busy or gxb_busy or rx_errdetect(2);
		rx_errin(3) <= not pll_locked or not gxb_locked or pll_busy or gxb_busy or rx_errdetect(3);

		-- 7seg
--		DebugPortOut(i).seg7 <= sata_rx_data(15 downto 0);

		-- leds
--		DebugPortOut(i).leds(0) <= rx_signaldetect;
--		DebugPortOut(i).leds(1) <= sata_syncstatus;
--		DebugPortOut(i).leds(2) <= sata_rx_ctrl(0);
--		DebugPortOut(i).leds(3) <= sata_rx_ctrl(1);
--		DebugPortOut(i).leds(4) <= sata_rx_ctrl(2);
--		DebugPortOut(i).leds(5) <= sata_rx_ctrl(3);
--		DebugPortOut(i).leds(6) <= sata_gen(0);
--		DebugPortOut(i).leds(7) <= sata_gen(1);

		rx_electricalidle <= not rx_signaldetect;

		-- speed reconfiguration (link layer interface)
		process(ll_clk) begin
			if rising_edge(ll_clk) then
				if RP_Reconfig(i) = '1' then
					sata_gen <= to_slv(SATA_Generation(i));
				end if;
				if gxb_busy = '0' and pll_busy = '0' then
					config_state <= config_state(14 downto 0) & RP_Reconfig(i);
				end if;
			end if;
		end process;
		
		config_sync : entity PoC.EventSyncVector
		generic map (
			BITS => 2,
			INIT => to_slv(SATA_GENERATION_3)
		)
		port map (
			Clock1 => ll_clk,
			Clock2 => reconf_clk,
			src => sata_gen,
			strobe => reconf
		);

		device_sync : entity PoC.EventSync
		port map (
			Clock1 => refclk,
			Clock2 => ll_clk,
			src => newdevice,
			strobe => ll_newdevice
		);
		
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
			reset => '0',--reset,
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

		dev_detect : entity PoC.sata_DeviceDetector
		generic map (
			CLOCK_FREQ_MHZ => CLOCK_IN_FREQ_MHZ,		-- 150 MHz
			NO_DEVICE_TIMEOUT_MS => NO_DEVICE_TIMEOUT_MS,	-- 1,0 ms
			NEW_DEVICE_TIMEOUT_MS => NEW_DEVICE_TIMEOUT_MS	-- 1,0 ms
		)
		port map (
			Clock => refclk,
			ElectricalIDLE => rx_electricalidle,
			NoDevice => nodevice,
			NewDevice => newdevice
		);

	end generate;
END;
