library	ieee;
use			ieee.std_logic_1164.all;

library	unisim;
use			unisim.vcomponents.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.physical.all;


entity eth_TEMAC_TRANS_Virtex5 is
	generic (
		DEBUG														: BOOLEAN					:= FALSE;
		PORTS														: POSITIVE				:= 1;
		PCS_MDIO_ADDRESS								: T_SLVV_8;

		SUPPORT_JUMBO_FRAMES						: T_BOOLVEC;
		TX_INSERT_CROSSCLOCK_FIFO				: T_BOOLVEC;
		TX_FIFO_DEPTHS									: T_POSVEC;
		TX_ENABLE_UNDERRUN_PROTECTION		: T_BOOLVEC;
		RX_INSERT_CROSSCLOCK_FIFO				: T_BOOLVEC;
		RX_FIFO_DEPTHS									: T_POSVEC
	);
	port(
		-- clock interface
		TX_Clock											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_Clock											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Eth_TX_Clock									: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Eth_RX_Clock									: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RS_TX_Clock										: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RS_RX_Clock										: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

		TX_Reset											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_Reset											: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Eth_TX_Reset									: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Eth_RX_Reset									: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RS_TX_Reset										: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RS_RX_Reset										: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

		Ethernet_Clock								: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Ethernet_ClockStable					: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

		Reset													: in	STD_LOGIC;				-- @async:	Reset

		-- PoC.Stream interface
		TX_Valid											: in STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		TX_Data												: in T_SLVV_8(PORTS - 1 downto 0);
		TX_SOF												: in STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		TX_EOF												: in STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		TX_Ack												: out STD_LOGIC_VECTOR(PORTS - 1 downto 0);

		RX_Valid											: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_Data												: out	T_SLVV_8(PORTS - 1 downto 0);
		RX_SOF												: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_EOF												: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		RX_Ack												: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

		-- Management interface
		MDIO_Clock_i									: in	STD_LOGIC;
		MDIO_Data_i										: in	STD_LOGIC;
		MDIO_Data_o										: out	STD_LOGIC;

		-- TRANS interface
		Trans_PowerDown								: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Trans_TX_Reset								: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Trans_RX_Reset								: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Trans_LoopBack								: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);										-- perform loopback testing
		Trans_EnableCommaAlign				: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);						-- enable comma alignment

		-- TRANS TX interface
		Trans_TX_Data									: out	T_SLVV_8(PORTS - 1 downto 0);
		Trans_TX_CharIsK							: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Trans_TX_DisparityMode				: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Trans_TX_DisparityValue				: out	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Trans_TX_BufferError					: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);

		-- TRANS RX interface
		Trans_RX_Data									: in	T_SLVV_8(PORTS - 1 downto 0);
		Trans_RX_CharIsK							: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Trans_RX_CharIsComma					: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Trans_RX_DisparityError				: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Trans_RX_NotInTable						: in	STD_LOGIC_VECTOR(PORTS - 1 downto 0);
		Trans_RX_BufferStatus					: in	T_SLVV_2(PORTS - 1 downto 0);
		Trans_RX_ClockCorrectionCount	: in	T_SLVV_3(PORTS - 1 downto 0)
	);
end;


architecture rtl of eth_TEMAC_TRANS_Virtex5 is

	signal TEMAC_TX_Ack							: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal TX_FSM_Valid							: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal TX_FSM_Data							: T_SLVV_8(PORTS - 1 downto 0);
	signal TX_FSM_UnderrunDetected	: STD_LOGIC_VECTOR(PORTS - 1 downto 0);

	signal TEMAC_RX_Valid						: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal TEMAC_RX_Data						: T_SLVV_8(PORTS - 1 downto 0);
	signal TEMAC_RX_GoodFrame				: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal TEMAC_RX_BadFrame				: STD_LOGIC_VECTOR(PORTS - 1 downto 0);
	signal RX_FSM_OverflowDetected	: STD_LOGIC_VECTOR(PORTS - 1 downto 0);

begin

	genFIFOChain : for i in 0 to PORTS - 1 generate
		constant SOF_BIT						: NATURAL			:= 8;
		constant EOF_BIT						: NATURAL			:= 9;

		signal XClk_TX_FIFO_Valid		: STD_LOGIC;
		signal XClk_TX_FIFO_DataOut	: STD_LOGIC_VECTOR(9 downto 0);
		signal XClk_TX_FIFO_got			: STD_LOGIC;

		signal TX_FIFO_DataOut			: STD_LOGIC_VECTOR(9 downto 0);
		signal TX_FIFO_Full					: STD_LOGIC;

		signal TX_FIFO_Valid				: STD_LOGIC;
		signal TX_FIFO_Data					: T_SLV_8;
		signal TX_FIFO_SOF					: STD_LOGIC;
		signal TX_FIFO_EOF					: STD_LOGIC;
		signal TX_FSM_Commit				: STD_LOGIC;
		signal TX_FSM_Rollback			: STD_LOGIC;

		signal TX_FSM_Ack						: STD_LOGIC;

		signal RX_FSM_Valid					: STD_LOGIC;
		signal RX_FSM_Data					: T_SLV_8;
		signal RX_FSM_SOF						: STD_LOGIC;
		signal RX_FSM_EOF						: STD_LOGIC;
		signal RX_FSM_Commit				: STD_LOGIC;
		signal RX_FSM_Rollback			: STD_LOGIC;

		signal RX_FIFO_put					: STD_LOGIC;
		signal RX_FIFO_DataIn				: STD_LOGIC_VECTOR(9 downto 0);
		signal RX_FIFO_Full					: STD_LOGIC;
		signal RX_FIFO_got					: STD_LOGIC;
		signal RX_FIFO_Valid				: STD_LOGIC;
		signal RX_FIFO_DataOut			: STD_LOGIC_VECTOR(9 downto 0);
		signal RX_FIFO_Ack					: STD_LOGIC;

		signal XClk_RX_FIFO_Full		: STD_LOGIC;


	begin
		-- ==========================================================================================================================================================
		-- assert statements
		-- ==========================================================================================================================================================
		assert ((TX_FIFO_DEPTHS(i) * 1 Byte) >= ite(TX_ENABLE_UNDERRUN_PROTECTION(i),	ite(SUPPORT_JUMBO_FRAMES(i), 10 KiB, 1522 Byte), 0 Byte))	report "TX-FIFO is to small" severity ERROR;
		assert ((RX_FIFO_DEPTHS(i) * 1 Byte) >=																				ite(SUPPORT_JUMBO_FRAMES(i), 10 KiB, 1522 Byte))					report "RX-FIFO is to small" severity ERROR;

		-- ==========================================================================================================================================================
		-- TX path
		-- ==========================================================================================================================================================
		genTX_XClk0 : if (TX_INSERT_CROSSCLOCK_FIFO(i) = FALSE) generate
			XClk_TX_FIFO_Valid											<= TX_Valid(i);
			XClk_TX_FIFO_DataOut(TX_Data(i)'range)	<= TX_Data(i);
			XClk_TX_FIFO_DataOut(SOF_BIT)						<= TX_SOF(i);
			XClk_TX_FIFO_DataOut(EOF_BIT)						<= TX_EOF(i);
			TX_Ack(i)																<= XClk_TX_FIFO_got;
		end generate;
		genTX_XClk1 : if (TX_INSERT_CROSSCLOCK_FIFO(i) = TRUE) generate
			signal XClk_TX_FIFO_DataIn		: STD_LOGIC_VECTOR(9 downto 0);
			signal XClk_TX_FIFO_Full			: STD_LOGIC;
		begin
			XClk_TX_FIFO_DataIn(TX_Data(i)'range)		<= TX_Data(i);
			XClk_TX_FIFO_DataIn(SOF_BIT)						<= TX_SOF(i);
			XClk_TX_FIFO_DataIn(EOF_BIT)						<= TX_EOF(i);

			XClk_TX_FIFO : entity PoC.fifo_ic_got
				generic map (
					D_BITS							=> XClk_TX_FIFO_DataIn'length,
					MIN_DEPTH						=> 16,
					DATA_REG						=> TRUE,
					OUTPUT_REG					=> FALSE,
					ESTATE_WR_BITS			=> 0,
					FSTATE_RD_BITS			=> 0
				)
				port map (
					-- Write Interface
					clk_wr							=> TX_Clock(i),
					rst_wr							=> TX_Reset(i),
					put									=> TX_Valid(i),
					din									=> XClk_TX_FIFO_DataIn,
					full								=> XClk_TX_FIFO_Full,
					estate_wr						=> open,

					-- Read Interface
					clk_rd							=> RS_TX_Clock(i),
					rst_rd							=> RS_TX_Reset(i),
					got									=> XClk_TX_FIFO_got,
					valid								=> XClk_TX_FIFO_Valid,
					dout								=> XClk_TX_FIFO_DataOut,
					fstate_rd						=> open
				);

			TX_Ack(i)	<= NOT XClk_TX_FIFO_Full;
		end generate;

		XClk_TX_FIFO_got	<= not TX_FIFO_Full;

		-- TX-Buffer Underrun Protection (configured by: TX_DISABLE_UNDERRUN_PROTECTION)
		-- ========================================================================================================================================================
		--	transactional behaviour:
		--	-	enabled:	each frame is committed when EOF is set (*_FIFO_Out(EOF_BIT))
		--	-	disabled:	each word is immediately committed, so incomplete frames can be consumed by the TX-MAC-statemachine
		--
		--	impact an FIFO_DEPTH:
		--	-	enabled:	FIFO_DEPTH must be greater than max. frame size (normal frames: ca. 1550 bytes; JumboFrames: ca. 9100 bytes)
		--	-	disabled:	TX-FIFO becomes optional; set FIFO_DEPTH to 0 to disable TX-FIFO
		-- ========================================================================================================================================================
		gen0 : if (TX_ENABLE_UNDERRUN_PROTECTION(i) = FALSE) generate
			TX_FIFO : entity PoC.fifo_cc_got_tempgot
				generic map (
					D_BITS							=> XClk_TX_FIFO_DataOut'length,
					MIN_DEPTH						=> TX_FIFO_DEPTHS(i),
					ESTATE_WR_BITS			=> 0,
					FSTATE_RD_BITS			=> 0,
					DATA_REG						=> FALSE,
					STATE_REG						=> TRUE,
					OUTPUT_REG					=> FALSE
				)
				port map (
					clk									=> RS_TX_Clock(i),
					rst									=> RS_TX_Reset(i),

					-- Write Interface
					put									=> XClk_TX_FIFO_Valid,
					din									=> XClk_TX_FIFO_DataOut,
					full								=> TX_FIFO_Full,
					estate_wr						=> open,

					-- Temporary put control
					commit							=> TX_FSM_Commit,
					rollback						=> TX_FSM_Rollback,

					-- Read Interface
					got									=> TX_FSM_Ack,
					valid								=> TX_FIFO_Valid,
					dout								=> TX_FIFO_DataOut,
					fstate_rd						=> open
				);
		end generate;
		gen1 : if (TX_ENABLE_UNDERRUN_PROTECTION(i) = TRUE) generate
			signal Commit			: STD_LOGIC;
		begin
			Commit		<= XClk_TX_FIFO_Valid and XClk_TX_FIFO_DataOut(EOF_BIT);

			TX_FIFO : entity PoC.fifo_cc_got_tempput
				generic map (
					D_BITS							=> XClk_TX_FIFO_DataOut'length,
					MIN_DEPTH						=> TX_FIFO_DEPTHS(i),
					ESTATE_WR_BITS			=> 0,
					FSTATE_RD_BITS			=> 0,
					DATA_REG						=> FALSE,
					STATE_REG						=> TRUE,
					OUTPUT_REG					=> FALSE
				)
				port map (
					clk									=> RS_TX_Clock(i),
					rst									=> RS_TX_Reset(i),

					-- Write Interface
					put									=> XClk_TX_FIFO_Valid,
					din									=> XClk_TX_FIFO_DataOut,
					full								=> TX_FIFO_Full,
					estate_wr						=> open,

					-- Temporary put control
					commit							=> Commit,
					rollback						=> '0',

					-- Read Interface
					got									=> TX_FSM_Ack,
					valid								=> TX_FIFO_Valid,
					dout								=> TX_FIFO_DataOut,
					fstate_rd						=> open
				);
		end generate;

		TX_FIFO_Data		<= TX_FIFO_DataOut(TX_FIFO_Data'range);
		TX_FIFO_SOF			<= TX_FIFO_DataOut(SOF_BIT);
		TX_FIFO_EOF			<= TX_FIFO_DataOut(EOF_BIT);

		TX_FSM : entity PoC.eth_TEMAC_TX_FSM
			port map (
				Clock							=> Eth_TX_Clock(i),
				Reset							=> Eth_TX_Reset(i),

				Valid							=> TX_FIFO_Valid,
				Data							=> TX_FIFO_Data,
				EOF								=> TX_FIFO_EOF,
				Ack								=> TX_FSM_Ack,
				Commit						=> TX_FSM_Commit,
				Rollback					=> TX_FSM_Rollback,

				UnderrunDetected	=> TX_FSM_UnderrunDetected(i),

				TEMAC_Valid				=> TX_FSM_Valid(i),
				TEMAC_Data				=> TX_FSM_Data(i),
				TEMAC_Ack					=> TEMAC_TX_Ack(i)
			);

		-- =========================================================================
		-- RX path
		-- =========================================================================
		RXFSM : entity PoC.eth_TEMAC_RX_FSM
			port map (
				Clock							=> Eth_TX_Clock(i),
				Reset							=> Eth_TX_Reset(i),

				TEMAC_Valid				=> TEMAC_RX_Valid(i),
				TEMAC_Data				=> TEMAC_RX_Data(i),
				TEMAC_GoodFrame		=> TEMAC_RX_GoodFrame(i),
				TEMAC_BadFrame		=> TEMAC_RX_BadFrame(i),

				OverflowDetected	=> RX_FSM_OverflowDetected(i),

				Valid							=> RX_FSM_Valid,
				Data							=> RX_FSM_Data,
				SOF								=> RX_FSM_SOF,
				EOF								=> RX_FSM_EOF,
				Ack								=> RX_FIFO_Ack,
				Commit						=> RX_FSM_Commit,
				Rollback					=> RX_FSM_Rollback
			);

		RX_FIFO_put												<= RX_FSM_Valid;
		RX_FIFO_DataIn(RX_FSM_Data'range)	<= RX_FSM_Data;
		RX_FIFO_DataIn(SOF_BIT)						<= RX_FSM_SOF;
		RX_FIFO_DataIn(EOF_BIT)						<= RX_FSM_EOF;
		RX_FIFO_Ack												<= not RX_FIFO_Full;

		RX_FIFO : entity PoC.fifo_cc_got_tempput
			generic map (
				D_BITS							=> RX_FIFO_DataIn'length,
				MIN_DEPTH						=> RX_FIFO_DEPTHS(i),
				ESTATE_WR_BITS			=> 0,
				FSTATE_RD_BITS			=> 0,
				DATA_REG						=> FALSE,
				STATE_REG						=> TRUE,
				OUTPUT_REG					=> FALSE
			)
			port map (
				clk									=> RS_RX_Clock(i),
				rst									=> RS_RX_Reset(i),

				-- Write Interface
				put									=> RX_FIFO_put,
				din									=> RX_FIFO_DataIn,
				full								=> RX_FIFO_Full,
				estate_wr						=> open,

				-- Temporary put control
				commit							=> RX_FSM_Commit,
				rollback						=> RX_FSM_Rollback,

				-- Read Interface
				got									=> RX_FIFO_got,
				valid								=> RX_FIFO_Valid,
				dout								=> RX_FIFO_DataOut,
				fstate_rd						=> open
			);

		RX_FIFO_got			<= not XClk_RX_FIFO_Full;

		genRX_XClk0 : if (RX_INSERT_CROSSCLOCK_FIFO(i) = FALSE) generate
			RX_Valid(i)							<= RX_FIFO_Valid;
			RX_Data(i)							<= RX_FIFO_DataOut(RX_Data(i)'range);
			RX_SOF(i)								<= RX_FIFO_DataOut(SOF_BIT);
			RX_EOF(i)								<= RX_FIFO_DataOut(EOF_BIT);
			XClk_RX_FIFO_Full				<= not RX_Ack(i);
		end generate;
		genRX_XClk1 : if (RX_INSERT_CROSSCLOCK_FIFO(i) = TRUE) generate
			signal XClk_RX_FIFO_DataOut		: STD_LOGIC_VECTOR(9 downto 0);
		begin
			XClk_RX_FIFO : entity PoC.fifo_ic_got
				generic map (
					D_BITS							=> RX_FIFO_DataOut'length,
					MIN_DEPTH						=> 16,
					DATA_REG						=> TRUE,
					OUTPUT_REG					=> FALSE,
					ESTATE_WR_BITS			=> 0,
					FSTATE_RD_BITS			=> 0
				)
				port map (
					-- Write Interface
					clk_wr							=> RS_RX_Clock(i),
					rst_wr							=> RS_RX_Reset(i),
					put									=> RX_FIFO_Valid,
					din									=> RX_FIFO_DataOut,
					full								=> XClk_RX_FIFO_Full,
					estate_wr						=> open,

					-- Read Interface
					clk_rd							=> RX_Clock(i),
					rst_rd							=> RX_Reset(i),
					got									=> RX_Ack(i),
					valid								=> RX_Valid(i),
					dout								=> XClk_RX_FIFO_DataOut,
					fstate_rd						=> open
				);

			RX_Data(i)	<= XClk_RX_FIFO_DataOut(RX_Data(i)'range);
			RX_SOF(i)		<= XClk_RX_FIFO_DataOut(SOF_BIT);
			RX_EOF(i)		<= XClk_RX_FIFO_DataOut(EOF_BIT);
		end generate;
	end generate;

	gen1 : if (PORTS = 1) generate
		signal TEMAC_MDIO_Clock_i			: STD_LOGIC_VECTOR(0 downto 0);
		signal TEMAC_MDIO_Data_i			: STD_LOGIC_VECTOR(0 downto 0);
		signal TEMAC_MDIO_Data_o			: STD_LOGIC_VECTOR(0 downto 0);
	begin

		TEMAC_MDIO_Clock_i		<= (others => MDIO_Clock_i);
		TEMAC_MDIO_Data_i			<= (others => MDIO_Data_i);
		MDIO_Data_o						<= slv_and(TEMAC_MDIO_Data_o);

		TEMAC_V5 : TEMAC
			generic map (
				EMAC0_ADDRFILTER_ENABLE			=> FALSE,
				EMAC0_BYTEPHY								=> TRUE,
				EMAC0_CONFIGVEC_79					=> TRUE,									-- reserved, set to TRUE
				EMAC0_DCRBASEADDR						=> x"00",									-- DCR interface - base address
				EMAC0_GTLOOPBACK						=> FALSE,
				EMAC0_HOST_ENABLE						=> FALSE,
				EMAC0_MDIO_ENABLE						=> TRUE,
				EMAC0_LINKTIMERVAL					=> (others => '0'),
				EMAC0_LTCHECK_DISABLE				=> TRUE,									-- disable the length/type field check
				EMAC0_PAUSEADDR							=> (others => '0'),
				EMAC0_PHYINITAUTONEG_ENABLE => FALSE,
				EMAC0_PHYISOLATE						=> FALSE,
				EMAC0_PHYLOOPBACKMSB				=> FALSE,
				EMAC0_PHYPOWERDOWN					=> FALSE,
				EMAC0_PHYRESET							=> TRUE,
				EMAC0_RGMII_ENABLE					=> FALSE,
				EMAC0_SGMII_ENABLE					=> FALSE,
				EMAC0_1000BASEX_ENABLE			=> FALSE,
				EMAC0_TX16BITCLIENT_ENABLE	=> FALSE,
				EMAC0_RX16BITCLIENT_ENABLE	=> FALSE,
				EMAC0_TXFLOWCTRL_ENABLE			=> FALSE,
				EMAC0_RXFLOWCTRL_ENABLE			=> FALSE,
				EMAC0_TXHALFDUPLEX					=> FALSE,
				EMAC0_RXHALFDUPLEX					=> FALSE,
				EMAC0_TXINBANDFCS_ENABLE		=> FALSE,									-- automatically add padding and FCS
				EMAC0_RXINBANDFCS_ENABLE		=> FALSE,									-- verify FCS field on pass through; truncate FCS field
				EMAC0_TXJUMBOFRAME_ENABLE		=> TRUE,
				EMAC0_RXJUMBOFRAME_ENABLE		=> TRUE,
				EMAC0_TXVLAN_ENABLE					=> TRUE,
				EMAC0_RXVLAN_ENABLE					=> TRUE,
				EMAC0_TX_ENABLE							=> TRUE,
				EMAC0_RX_ENABLE							=> TRUE,
				EMAC0_TXRESET								=> FALSE,
				EMAC0_RXRESET								=> FALSE,
				EMAC0_SPEED_MSB							=> TRUE,
				EMAC0_SPEED_LSB							=> FALSE,
				EMAC0_TXIFGADJUST_ENABLE		=> FALSE,									-- insert always the legal minimum IFG
				EMAC0_UNICASTADDR						=> x"000000000000",
				EMAC0_UNIDIRECTION_ENABLE		=> FALSE,
				EMAC0_USECLKEN							=> FALSE,

				EMAC1_ADDRFILTER_ENABLE			=> FALSE,
				EMAC1_BYTEPHY								=> TRUE,
				EMAC1_CONFIGVEC_79					=> TRUE,									-- reserved, set to TRUE
				EMAC1_DCRBASEADDR						=> x"00",									-- DCR interface - base address
				EMAC1_GTLOOPBACK						=> FALSE,
				EMAC1_HOST_ENABLE						=> FALSE,
				EMAC1_MDIO_ENABLE						=> TRUE,
				EMAC1_LINKTIMERVAL					=> (others => '0'),
				EMAC1_LTCHECK_DISABLE				=> TRUE,									-- disable the length/type field check
				EMAC1_PAUSEADDR							=> (others => '0'),
				EMAC1_PHYINITAUTONEG_ENABLE => FALSE,
				EMAC1_PHYISOLATE						=> FALSE,
				EMAC1_PHYLOOPBACKMSB				=> FALSE,
				EMAC1_PHYPOWERDOWN					=> FALSE,
				EMAC1_PHYRESET							=> TRUE,
				EMAC1_RGMII_ENABLE					=> FALSE,
				EMAC1_SGMII_ENABLE					=> FALSE,
				EMAC1_1000BASEX_ENABLE			=> FALSE,
				EMAC1_TX16BITCLIENT_ENABLE	=> FALSE,
				EMAC1_RX16BITCLIENT_ENABLE	=> FALSE,
				EMAC1_TXFLOWCTRL_ENABLE			=> FALSE,
				EMAC1_RXFLOWCTRL_ENABLE			=> FALSE,
				EMAC1_TXHALFDUPLEX					=> FALSE,
				EMAC1_RXHALFDUPLEX					=> FALSE,
				EMAC1_TXINBANDFCS_ENABLE		=> FALSE,									-- automatically add padding and FCS
				EMAC1_RXINBANDFCS_ENABLE		=> FALSE,									-- verify FCS field on pass through; truncate FCS field
				EMAC1_TXJUMBOFRAME_ENABLE		=> TRUE,
				EMAC1_RXJUMBOFRAME_ENABLE		=> TRUE,
				EMAC1_TXVLAN_ENABLE					=> TRUE,
				EMAC1_RXVLAN_ENABLE					=> TRUE,
				EMAC1_TX_ENABLE							=> TRUE,
				EMAC1_RX_ENABLE							=> TRUE,
				EMAC1_TXRESET								=> FALSE,
				EMAC1_RXRESET								=> FALSE,
				EMAC1_SPEED_MSB							=> TRUE,
				EMAC1_SPEED_LSB							=> FALSE,
				EMAC1_TXIFGADJUST_ENABLE		=> FALSE,									-- insert always the legal minimum IFG
				EMAC1_UNICASTADDR						=> x"000000000000",
				EMAC1_UNIDIRECTION_ENABLE		=> FALSE,
				EMAC1_USECLKEN							=> FALSE
			)
			port map (
				RESET												=> Reset,											-- @async:

				-- Generic Host Bus interface
				HOSTCLK											=> '0',
				HOSTOPCODE									=> "00",
				HOSTREQ											=> '0',
				HOSTADDR										=> (others => '0'),
				HOSTMIIMSEL									=> '0',
				HOSTEMAC1SEL								=> '0',
				HOSTWRDATA									=> (others => '0'),
				HOSTRDDATA									=> open,
				HOSTMIIMRDY									=> open,

				-- DCR interface
				DCREMACCLK									=> '0',
				DCREMACABUS									=> (others => '0'),					-- address bus
				DCREMACENABLE								=> '0',											-- bus enable:	'0' -> GHB interface; '1' -> DCR interface
				DCREMACREAD									=> '0',											-- read
				DCREMACWRITE								=> '0',											-- write
				DCREMACDBUS									=> (others => '0'),					-- data in
				EMACDCRDBUS									=> open,										-- data out
				EMACDCRACK									=> open,										-- ack
				DCRHOSTDONEIR								=> open,										-- interrupt (register access is complete)

				-- TEMAC - port 0
				CLIENTEMAC0TXCLIENTCLKIN		=> Eth_TX_Clock(0),
				CLIENTEMAC0RXCLIENTCLKIN		=> Eth_RX_Clock(0),
				EMAC0CLIENTTXCLIENTCLKOUT		=> open,
				EMAC0CLIENTRXCLIENTCLKOUT		=> open,
				PHYEMAC0TXGMIIMIICLKIN			=> RS_TX_Clock(0),
				PHYEMAC0RXCLK								=> RS_RX_Clock(0),
				EMAC0PHYTXCLK								=> open,
				PHYEMAC0GTXCLK							=> '0',
				EMAC0PHYTXGMIIMIICLKOUT			=> open,
				PHYEMAC0MIITXCLK						=> '0',

				CLIENTEMAC0DCMLOCKED				=> Ethernet_ClockStable(0),

				-- TX interface
				CLIENTEMAC0TXDVLD						=> TX_FSM_Valid(0),
				CLIENTEMAC0TXD							=> x"00" & TX_FSM_Data(0),
				CLIENTEMAC0TXDVLDMSW				=> '0',													-- indicate odd bytes in last transmit word
				EMAC0CLIENTTXACK						=> TEMAC_TX_Ack(0),
				CLIENTEMAC0TXFIRSTBYTE			=> '0',
				CLIENTEMAC0TXUNDERRUN				=> TX_FSM_UnderrunDetected(0),	-- tx buffer underrun - is not possible if fifo_cc_tempput is used
				EMAC0CLIENTTXCOLLISION			=> open,												-- always deasserted in full duplex mode
				EMAC0CLIENTTXRETRANSMIT			=> open,												-- always deasserted in full duplex mode
				CLIENTEMAC0TXIFGDELAY				=> (others => '0'),
				EMAC0CLIENTTXSTATS					=> open,												-- TX statistics
				EMAC0CLIENTTXSTATSVLD				=> open,												-- TX statistics
				EMAC0CLIENTTXSTATSBYTEVLD		=> open,												-- TX statistics

				-- RX interface
				EMAC0CLIENTRXDVLD						=> TEMAC_RX_Valid(0),
				EMAC0CLIENTRXD(7 downto 0)	=> TEMAC_RX_Data(0),
				EMAC0CLIENTRXDVLDMSW				=> open,											-- indicate odd bytes in last receive word
				EMAC0CLIENTRXGOODFRAME			=> TEMAC_RX_GoodFrame(0),
				EMAC0CLIENTRXBADFRAME				=> TEMAC_RX_BadFrame(0),
				EMAC0CLIENTRXFRAMEDROP			=> open,											-- indicate a address filter mismatch
				EMAC0CLIENTRXSTATS					=> open,											-- RX statistics
				EMAC0CLIENTRXSTATSVLD				=> open,											-- RX statistics
				EMAC0CLIENTRXSTATSBYTEVLD		=> open,											-- RX statistics

				-- PCS configuration
				PHYEMAC0PHYAD								=> PCS_MDIO_ADDRESS(0)(4 downto 0),

				-- Status interface
				EMAC0CLIENTANINTERRUPT			=> open,											-- interrupt upon auto-negotiation
				EMAC0SPEEDIS10100						=> open,											-- must be low in GbE mode
				EMAC0PHYSYNCACQSTATUS				=> open,											-- receiver's synchronization FSM state (IEEE 802.3, clause 36)

				-- MAC layer flow control - user interface
				CLIENTEMAC0PAUSEREQ					=> '0',
				CLIENTEMAC0PAUSEVAL					=> x"0000",

				-- MDIO interface
				EMAC0PHYMCLKOUT							=> open,
				PHYEMAC0MCLKIN							=> MDIO_Clock_i,
				PHYEMAC0MDIN								=> MDIO_Data_i,
				EMAC0PHYMDOUT								=> MDIO_Data_o,
				EMAC0PHYMDTRI								=> open,

				-- GMII interface
				PHYEMAC0RXDV								=> '0',
				PHYEMAC0RXER								=> '0',
				EMAC0PHYTXEN								=> open,
				EMAC0PHYTXER								=> open,

				PHYEMAC0COL									=> '0',		-- Collision Detect
				PHYEMAC0CRS									=> '0',		-- Carrier Sense

				-- TRANS interface
				EMAC0PHYPOWERDOWN						=> Trans_PowerDown(0),
				EMAC0PHYMGTTXRESET					=> Trans_TX_Reset(0),
				EMAC0PHYMGTRXRESET					=> Trans_RX_Reset(0),
				EMAC0PHYLOOPBACKMSB					=> Trans_LoopBack(0),										-- perform loopback testing
				EMAC0PHYENCOMMAALIGN				=> Trans_EnableCommaAlign(0),						-- enable comma alignment

				-- TRANS TX interface
				EMAC0PHYTXD									=> Trans_TX_Data(0),
				EMAC0PHYTXCHARISK						=> Trans_TX_CharIsK(0),
				EMAC0PHYTXCHARDISPMODE			=> Trans_TX_DisparityMode(0),
				EMAC0PHYTXCHARDISPVAL				=> Trans_TX_DisparityValue(0),
				PHYEMAC0TXBUFERR						=> Trans_TX_BufferError(0),

				-- TRANS RX interface
				PHYEMAC0RXD									=> Trans_RX_Data(0),
				PHYEMAC0RXCHARISK						=> Trans_RX_CharIsK(0),
				PHYEMAC0RXCHARISCOMMA				=> Trans_RX_CharIsComma(0),
				PHYEMAC0RXDISPERR						=> Trans_RX_DisparityError(0),
				PHYEMAC0RXNOTINTABLE				=> Trans_RX_NotInTable(0),
				PHYEMAC0RXBUFSTATUS					=> Trans_RX_BufferStatus(0),
				PHYEMAC0RXCLKCORCNT					=> Trans_RX_ClockCorrectionCount(0),

				-- reserved - tie to ground
				PHYEMAC0RXCHECKINGCRC				=> '0',
				PHYEMAC0RXCOMMADET					=> '0',
				PHYEMAC0RXBUFERR						=> '0',
				PHYEMAC0RXLOSSOFSYNC				=> "00",
				PHYEMAC0RXRUNDISP						=> '0',

				-- optical light detected in optical transceiver
				PHYEMAC0SIGNALDET						=> '1',											-- set to high for copper cables

				-- TEMAC - port 1
				CLIENTEMAC1TXCLIENTCLKIN		=> '0',
				CLIENTEMAC1RXCLIENTCLKIN		=> '0',
				EMAC1CLIENTTXCLIENTCLKOUT		=> open,
				EMAC1CLIENTRXCLIENTCLKOUT		=> open,
				PHYEMAC1TXGMIIMIICLKIN			=> '0',
				PHYEMAC1RXCLK								=> '0',
				EMAC1PHYTXCLK								=> open,
				PHYEMAC1GTXCLK							=> '0',
				EMAC1PHYTXGMIIMIICLKOUT			=> open,
				PHYEMAC1MIITXCLK						=> '0',

				CLIENTEMAC1DCMLOCKED				=> '0',

				-- TX interface
				CLIENTEMAC1TXDVLD						=> '0',
				CLIENTEMAC1TXD							=> x"0000",
				CLIENTEMAC1TXDVLDMSW				=> '0',												-- indicate odd bytes in last transmit word
				EMAC1CLIENTTXACK						=> open,
				CLIENTEMAC1TXFIRSTBYTE			=> '0',
				CLIENTEMAC1TXUNDERRUN				=> '0',												-- tx buffer underrun - is not possible if fifo_cc_tempput is used
				EMAC1CLIENTTXCOLLISION			=> open,											-- always deasserted in full duplex mode
				EMAC1CLIENTTXRETRANSMIT			=> open,											-- always deasserted in full duplex mode
				CLIENTEMAC1TXIFGDELAY				=> (others => '0'),
				EMAC1CLIENTTXSTATS					=> open,											-- TX statistics
				EMAC1CLIENTTXSTATSVLD				=> open,											-- TX statistics
				EMAC1CLIENTTXSTATSBYTEVLD		=> open,											-- TX statistics

				-- RX interface
				EMAC1CLIENTRXDVLD						=> open,
				EMAC1CLIENTRXD(7 downto 0)	=> open,
				EMAC1CLIENTRXDVLDMSW				=> open,											-- indicate odd bytes in last receive word
				EMAC1CLIENTRXGOODFRAME			=> open,
				EMAC1CLIENTRXBADFRAME				=> open,
				EMAC1CLIENTRXFRAMEDROP			=> open,											-- indicate a address filter mismatch
				EMAC1CLIENTRXSTATS					=> open,											-- RX statistics
				EMAC1CLIENTRXSTATSVLD				=> open,											-- RX statistics
				EMAC1CLIENTRXSTATSBYTEVLD		=> open,											-- RX statistics

				-- PCS configuration
				PHYEMAC1PHYAD								=> PCS_MDIO_ADDRESS(1)(4 downto 0),

				-- Status interface
				EMAC1CLIENTANINTERRUPT			=> open,											-- interrupt upon auto-negotiation
				EMAC1SPEEDIS10100						=> open,											-- must be low in GbE mode
				EMAC1PHYSYNCACQSTATUS				=> open,											-- receiver's synchronization FSM state (IEEE 802.3, clause 36)

				-- MAC layer flow control - user interface
				CLIENTEMAC1PAUSEREQ					=> '0',
				CLIENTEMAC1PAUSEVAL					=> x"0000",

				-- MDIO interface
				EMAC1PHYMCLKOUT							=> open,
				PHYEMAC1MCLKIN							=> '0',
				PHYEMAC1MDIN								=> '0',
				EMAC1PHYMDOUT								=> open,
				EMAC1PHYMDTRI								=> open,

				-- GMII interface
				PHYEMAC1RXD									=> (others => '0'),
				PHYEMAC1RXDV								=> '0',
				PHYEMAC1RXER								=> '0',
				EMAC1PHYTXD									=> open,
				EMAC1PHYTXEN								=> open,
				EMAC1PHYTXER								=> open,

				PHYEMAC1COL									=> '0',		-- Collision Detect
				PHYEMAC1CRS									=> '0',		-- Carrier Sense

				-- TRANS interface
				EMAC1PHYPOWERDOWN						=> open,
				EMAC1PHYMGTRXRESET					=> open,
				EMAC1PHYMGTTXRESET					=> open,
				EMAC1PHYLOOPBACKMSB					=> open,										-- perform loopback testing

				-- TRANS TX interface
				PHYEMAC1TXBUFERR						=> '0',
				EMAC1PHYTXCHARDISPMODE			=> open,
				EMAC1PHYTXCHARDISPVAL				=> open,
				EMAC1PHYTXCHARISK						=> open,

				-- TRANS RX interface
				PHYEMAC1RXCHARISCOMMA				=> '0',
				PHYEMAC1RXCHARISK						=> '0',
				PHYEMAC1RXDISPERR						=> '0',
				PHYEMAC1RXNOTINTABLE				=> '0',
				EMAC1PHYENCOMMAALIGN				=> open,										-- enable comma alignment
				PHYEMAC1RXCLKCORCNT					=> "000",
				PHYEMAC1RXBUFSTATUS					=> "00",

				-- reserved - tie to ground
				PHYEMAC1RXCHECKINGCRC				=> '0',
				PHYEMAC1RXCOMMADET					=> '0',
				PHYEMAC1RXBUFERR						=> '0',
				PHYEMAC1RXLOSSOFSYNC				=> "00",
				PHYEMAC1RXRUNDISP						=> '0',

				-- optical light detected in optical transceiver
				PHYEMAC1SIGNALDET						=> '1'											-- set to high for copper cables
			);
	end generate;

	gen2 : if (PORTS = 2) generate
		signal TEMAC_MDIO_Clock_i			: STD_LOGIC_VECTOR(1 downto 0);
		signal TEMAC_MDIO_Data_i			: STD_LOGIC_VECTOR(1 downto 0);
		signal TEMAC_MDIO_Data_o			: STD_LOGIC_VECTOR(1 downto 0);
	begin

		TEMAC_MDIO_Clock_i		<= (others => MDIO_Clock_i);
		TEMAC_MDIO_Data_i			<= (others => MDIO_Data_i);
		MDIO_Data_o						<= slv_and(TEMAC_MDIO_Data_o);

		TEMAC_V5 : TEMAC
			generic map (
				EMAC0_ADDRFILTER_ENABLE			=> FALSE,
				EMAC0_BYTEPHY								=> TRUE,
				EMAC0_CONFIGVEC_79					=> TRUE,									-- reserved, set to TRUE
				EMAC0_DCRBASEADDR						=> x"00",									-- DCR interface - base address
				EMAC0_GTLOOPBACK						=> FALSE,
				EMAC0_HOST_ENABLE						=> FALSE,
				EMAC0_MDIO_ENABLE						=> TRUE,
				EMAC0_LINKTIMERVAL					=> (others => '0'),
				EMAC0_LTCHECK_DISABLE				=> TRUE,									-- disable the length/type field check
				EMAC0_PAUSEADDR							=> (others => '0'),
				EMAC0_PHYINITAUTONEG_ENABLE => FALSE,
				EMAC0_PHYISOLATE						=> FALSE,
				EMAC0_PHYLOOPBACKMSB				=> FALSE,
				EMAC0_PHYPOWERDOWN					=> FALSE,
				EMAC0_PHYRESET							=> TRUE,
				EMAC0_RGMII_ENABLE					=> FALSE,
				EMAC0_SGMII_ENABLE					=> FALSE,
				EMAC0_1000BASEX_ENABLE			=> FALSE,
				EMAC0_TX16BITCLIENT_ENABLE	=> FALSE,
				EMAC0_RX16BITCLIENT_ENABLE	=> FALSE,
				EMAC0_TXFLOWCTRL_ENABLE			=> FALSE,
				EMAC0_RXFLOWCTRL_ENABLE			=> FALSE,
				EMAC0_TXHALFDUPLEX					=> FALSE,
				EMAC0_RXHALFDUPLEX					=> FALSE,
				EMAC0_TXINBANDFCS_ENABLE		=> FALSE,									-- automatically add padding and FCS
				EMAC0_RXINBANDFCS_ENABLE		=> FALSE,									-- verify FCS field on pass through; truncate FCS field
				EMAC0_TXJUMBOFRAME_ENABLE		=> TRUE,
				EMAC0_RXJUMBOFRAME_ENABLE		=> TRUE,
				EMAC0_TXVLAN_ENABLE					=> TRUE,
				EMAC0_RXVLAN_ENABLE					=> TRUE,
				EMAC0_TX_ENABLE							=> TRUE,
				EMAC0_RX_ENABLE							=> TRUE,
				EMAC0_TXRESET								=> FALSE,
				EMAC0_RXRESET								=> FALSE,
				EMAC0_SPEED_MSB							=> TRUE,
				EMAC0_SPEED_LSB							=> FALSE,
				EMAC0_TXIFGADJUST_ENABLE		=> FALSE,									-- insert always the legal minimum IFG
				EMAC0_UNICASTADDR						=> x"000000000000",
				EMAC0_UNIDIRECTION_ENABLE		=> FALSE,
				EMAC0_USECLKEN							=> FALSE,

				EMAC1_ADDRFILTER_ENABLE			=> FALSE,
				EMAC1_BYTEPHY								=> TRUE,
				EMAC1_CONFIGVEC_79					=> TRUE,									-- reserved, set to TRUE
				EMAC1_DCRBASEADDR						=> x"00",									-- DCR interface - base address
				EMAC1_GTLOOPBACK						=> FALSE,
				EMAC1_HOST_ENABLE						=> FALSE,
				EMAC1_MDIO_ENABLE						=> TRUE,
				EMAC1_LINKTIMERVAL					=> (others => '0'),
				EMAC1_LTCHECK_DISABLE				=> TRUE,									-- disable the length/type field check
				EMAC1_PAUSEADDR							=> (others => '0'),
				EMAC1_PHYINITAUTONEG_ENABLE => FALSE,
				EMAC1_PHYISOLATE						=> FALSE,
				EMAC1_PHYLOOPBACKMSB				=> FALSE,
				EMAC1_PHYPOWERDOWN					=> FALSE,
				EMAC1_PHYRESET							=> TRUE,
				EMAC1_RGMII_ENABLE					=> FALSE,
				EMAC1_SGMII_ENABLE					=> FALSE,
				EMAC1_1000BASEX_ENABLE			=> FALSE,
				EMAC1_TX16BITCLIENT_ENABLE	=> FALSE,
				EMAC1_RX16BITCLIENT_ENABLE	=> FALSE,
				EMAC1_TXFLOWCTRL_ENABLE			=> FALSE,
				EMAC1_RXFLOWCTRL_ENABLE			=> FALSE,
				EMAC1_TXHALFDUPLEX					=> FALSE,
				EMAC1_RXHALFDUPLEX					=> FALSE,
				EMAC1_TXINBANDFCS_ENABLE		=> FALSE,									-- automatically add padding and FCS
				EMAC1_RXINBANDFCS_ENABLE		=> FALSE,									-- verify FCS field on pass through; truncate FCS field
				EMAC1_TXJUMBOFRAME_ENABLE		=> TRUE,
				EMAC1_RXJUMBOFRAME_ENABLE		=> TRUE,
				EMAC1_TXVLAN_ENABLE					=> TRUE,
				EMAC1_RXVLAN_ENABLE					=> TRUE,
				EMAC1_TX_ENABLE							=> TRUE,
				EMAC1_RX_ENABLE							=> TRUE,
				EMAC1_TXRESET								=> FALSE,
				EMAC1_RXRESET								=> FALSE,
				EMAC1_SPEED_MSB							=> TRUE,
				EMAC1_SPEED_LSB							=> FALSE,
				EMAC1_TXIFGADJUST_ENABLE		=> FALSE,									-- insert always the legal minimum IFG
				EMAC1_UNICASTADDR						=> x"000000000000",
				EMAC1_UNIDIRECTION_ENABLE		=> FALSE,
				EMAC1_USECLKEN							=> FALSE
			)
			port map (
				RESET												=> Reset,											-- @async:

				-- Generic Host Bus interface
				HOSTCLK											=> '0',
				HOSTOPCODE									=> "00",
				HOSTREQ											=> '0',
				HOSTADDR										=> (others => '0'),
				HOSTMIIMSEL									=> '0',
				HOSTEMAC1SEL								=> '0',
				HOSTWRDATA									=> (others => '0'),
				HOSTRDDATA									=> open,
				HOSTMIIMRDY									=> open,

				-- DCR interface
				DCREMACCLK									=> '0',
				DCREMACABUS									=> (others => '0'),					-- address bus
				DCREMACENABLE								=> '0',											-- bus enable:	'0' -> GHB interface; '1' -> DCR interface
				DCREMACREAD									=> '0',											-- read
				DCREMACWRITE								=> '0',											-- write
				DCREMACDBUS									=> (others => '0'),					-- data in
				EMACDCRDBUS									=> open,										-- data out
				EMACDCRACK									=> open,										-- ack
				DCRHOSTDONEIR								=> open,										-- interrupt (register access is complete)

				-- TEMAC - port 0
				CLIENTEMAC0TXCLIENTCLKIN		=> Eth_TX_Clock(0),
				CLIENTEMAC0RXCLIENTCLKIN		=> Eth_RX_Clock(0),
				EMAC0CLIENTTXCLIENTCLKOUT		=> open,
				EMAC0CLIENTRXCLIENTCLKOUT		=> open,
				PHYEMAC0TXGMIIMIICLKIN			=> RS_TX_Clock(0),
				PHYEMAC0RXCLK								=> RS_RX_Clock(0),
				EMAC0PHYTXCLK								=> open,
				PHYEMAC0GTXCLK							=> '0',
				EMAC0PHYTXGMIIMIICLKOUT			=> open,
				PHYEMAC0MIITXCLK						=> '0',

				CLIENTEMAC0DCMLOCKED				=> Ethernet_ClockStable(0),

				-- TX interface
				CLIENTEMAC0TXDVLD						=> TX_FSM_Valid(0),
				CLIENTEMAC0TXD							=> x"00" & TX_FSM_Data(0),
				CLIENTEMAC0TXDVLDMSW				=> '0',													-- indicate odd bytes in last transmit word
				EMAC0CLIENTTXACK						=> TEMAC_TX_Ack(0),
				CLIENTEMAC0TXFIRSTBYTE			=> '0',
				CLIENTEMAC0TXUNDERRUN				=> TX_FSM_UnderrunDetected(0),	-- tx buffer underrun - is not possible if fifo_cc_tempput is used
				EMAC0CLIENTTXCOLLISION			=> open,												-- always deasserted in full duplex mode
				EMAC0CLIENTTXRETRANSMIT			=> open,												-- always deasserted in full duplex mode
				CLIENTEMAC0TXIFGDELAY				=> (others => '0'),
				EMAC0CLIENTTXSTATS					=> open,												-- TX statistics
				EMAC0CLIENTTXSTATSVLD				=> open,												-- TX statistics
				EMAC0CLIENTTXSTATSBYTEVLD		=> open,												-- TX statistics

				-- RX interface
				EMAC0CLIENTRXDVLD						=> TEMAC_RX_Valid(0),
				EMAC0CLIENTRXD(7 downto 0)	=> TEMAC_RX_Data(0),
				EMAC0CLIENTRXDVLDMSW				=> open,											-- indicate odd bytes in last receive word
				EMAC0CLIENTRXGOODFRAME			=> TEMAC_RX_GoodFrame(0),
				EMAC0CLIENTRXBADFRAME				=> TEMAC_RX_BadFrame(0),
				EMAC0CLIENTRXFRAMEDROP			=> open,											-- indicate a address filter mismatch
				EMAC0CLIENTRXSTATS					=> open,											-- RX statistics
				EMAC0CLIENTRXSTATSVLD				=> open,											-- RX statistics
				EMAC0CLIENTRXSTATSBYTEVLD		=> open,											-- RX statistics

				-- PCS configuration
				PHYEMAC0PHYAD								=> PCS_MDIO_ADDRESS(0)(4 downto 0),

				-- Status interface
				EMAC0CLIENTANINTERRUPT			=> open,											-- interrupt upon auto-negotiation
				EMAC0SPEEDIS10100						=> open,											-- must be low in GbE mode
				EMAC0PHYSYNCACQSTATUS				=> open,											-- receiver's synchronization FSM state (IEEE 802.3, clause 36)

				-- MAC layer flow control - user interface
				CLIENTEMAC0PAUSEREQ					=> '0',
				CLIENTEMAC0PAUSEVAL					=> x"0000",

				-- MDIO interface
				EMAC0PHYMCLKOUT							=> open,
				PHYEMAC0MCLKIN							=> TEMAC_MDIO_Clock_i(0),
				PHYEMAC0MDIN								=> TEMAC_MDIO_Data_i(0),
				EMAC0PHYMDOUT								=> TEMAC_MDIO_Data_o(0),
				EMAC0PHYMDTRI								=> open,

				-- GMII interface
				PHYEMAC0RXDV								=> '0',
				PHYEMAC0RXER								=> '0',
				EMAC0PHYTXEN								=> open,
				EMAC0PHYTXER								=> open,

				PHYEMAC0COL									=> '0',		-- Collision Detect
				PHYEMAC0CRS									=> '0',		-- Carrier Sense

				-- TRANS interface
				EMAC0PHYPOWERDOWN						=> Trans_PowerDown(0),
				EMAC0PHYMGTTXRESET					=> Trans_TX_Reset(0),
				EMAC0PHYMGTRXRESET					=> Trans_RX_Reset(0),
				EMAC0PHYLOOPBACKMSB					=> Trans_LoopBack(0),							-- perform loopback testing
				EMAC0PHYENCOMMAALIGN				=> Trans_EnableCommaAlign(0),			-- enable comma alignment

				-- TRANS TX interface
				EMAC0PHYTXD									=> Trans_TX_Data(0),
				EMAC0PHYTXCHARISK						=> Trans_TX_CharIsK(0),
				EMAC0PHYTXCHARDISPMODE			=> Trans_TX_DisparityMode(0),
				EMAC0PHYTXCHARDISPVAL				=> Trans_TX_DisparityValue(0),
				PHYEMAC0TXBUFERR						=> Trans_TX_BufferError(0),

				-- TRANS RX interface
				PHYEMAC0RXD									=> Trans_RX_Data(0),
				PHYEMAC0RXCHARISK						=> Trans_RX_CharIsK(0),
				PHYEMAC0RXCHARISCOMMA				=> Trans_RX_CharIsComma(0),
				PHYEMAC0RXDISPERR						=> Trans_RX_DisparityError(0),
				PHYEMAC0RXNOTINTABLE				=> Trans_RX_NotInTable(0),
				PHYEMAC0RXCLKCORCNT					=> Trans_RX_ClockCorrectionCount(0),
				PHYEMAC0RXBUFSTATUS					=> Trans_RX_BufferStatus(0),

				-- reserved - tie to ground
				PHYEMAC0RXCHECKINGCRC				=> '0',
				PHYEMAC0RXCOMMADET					=> '0',
				PHYEMAC0RXBUFERR						=> '0',
				PHYEMAC0RXLOSSOFSYNC				=> "00",
				PHYEMAC0RXRUNDISP						=> '0',

				-- optical light detected in optical transceiver
				PHYEMAC0SIGNALDET						=> '1',											-- set to high for copper cables

				-- TEMAC - port 1
				CLIENTEMAC1TXCLIENTCLKIN		=> Eth_TX_Clock(1),
				CLIENTEMAC1RXCLIENTCLKIN		=> Eth_RX_Clock(1),
				EMAC1CLIENTTXCLIENTCLKOUT		=> open,
				EMAC1CLIENTRXCLIENTCLKOUT		=> open,
				PHYEMAC1TXGMIIMIICLKIN			=> RS_TX_Clock(1),
				PHYEMAC1RXCLK								=> RS_RX_Clock(1),
				EMAC1PHYTXCLK								=> open,
				PHYEMAC1GTXCLK							=> '0',
				EMAC1PHYTXGMIIMIICLKOUT			=> open,
				PHYEMAC1MIITXCLK						=> '0',

				CLIENTEMAC1DCMLOCKED				=> Ethernet_ClockStable(0),

				-- TX interface
				CLIENTEMAC1TXDVLD						=> TX_FSM_Valid(1),
				CLIENTEMAC1TXD							=> x"00" & TX_FSM_Data(1),
				CLIENTEMAC1TXDVLDMSW				=> '0',													-- indicate odd bytes in last transmit word
				EMAC1CLIENTTXACK						=> TEMAC_TX_Ack(1),
				CLIENTEMAC1TXFIRSTBYTE			=> '0',
				CLIENTEMAC1TXUNDERRUN				=> TX_FSM_UnderrunDetected(1),	-- tx buffer underrun - is not possible if fifo_cc_tempput is used
				EMAC1CLIENTTXCOLLISION			=> open,												-- always deasserted in full duplex mode
				EMAC1CLIENTTXRETRANSMIT			=> open,												-- always deasserted in full duplex mode
				CLIENTEMAC1TXIFGDELAY				=> (others => '0'),
				EMAC1CLIENTTXSTATS					=> open,												-- TX statistics
				EMAC1CLIENTTXSTATSVLD				=> open,												-- TX statistics
				EMAC1CLIENTTXSTATSBYTEVLD		=> open,												-- TX statistics

				-- RX interface
				EMAC1CLIENTRXDVLD						=> TEMAC_RX_Valid(1),
				EMAC1CLIENTRXD(7 downto 0)	=> TEMAC_RX_Data(1),
				EMAC1CLIENTRXDVLDMSW				=> open,											-- indicate odd bytes in last receive word
				EMAC1CLIENTRXGOODFRAME			=> TEMAC_RX_GoodFrame(1),
				EMAC1CLIENTRXBADFRAME				=> TEMAC_RX_BadFrame(1),
				EMAC1CLIENTRXFRAMEDROP			=> open,											-- indicate a address filter mismatch
				EMAC1CLIENTRXSTATS					=> open,											-- RX statistics
				EMAC1CLIENTRXSTATSVLD				=> open,											-- RX statistics
				EMAC1CLIENTRXSTATSBYTEVLD		=> open,											-- RX statistics

				-- PCS configuration
				PHYEMAC1PHYAD								=> PCS_MDIO_ADDRESS(1)(4 downto 0),

				-- Status interface
				EMAC1CLIENTANINTERRUPT			=> open,											-- interrupt upon auto-negotiation
				EMAC1SPEEDIS10100						=> open,											-- must be low in GbE mode
				EMAC1PHYSYNCACQSTATUS				=> open,											-- receiver's synchronization FSM state (IEEE 802.3, clause 36)

				-- MAC layer flow control - user interface
				CLIENTEMAC1PAUSEREQ					=> '0',
				CLIENTEMAC1PAUSEVAL					=> x"0000",

				-- MDIO interface
				EMAC1PHYMCLKOUT							=> open,
				PHYEMAC1MCLKIN							=> TEMAC_MDIO_Clock_i(1),
				PHYEMAC1MDIN								=> TEMAC_MDIO_Data_i(1),
				EMAC1PHYMDOUT								=> TEMAC_MDIO_Data_o(1),
				EMAC1PHYMDTRI								=> open,

				-- GMII interface
				PHYEMAC1RXDV								=> '0',
				PHYEMAC1RXER								=> '0',
				EMAC1PHYTXEN								=> open,
				EMAC1PHYTXER								=> open,

				PHYEMAC1COL									=> '0',		-- Collision Detect
				PHYEMAC1CRS									=> '0',		-- Carrier Sense

				-- TRANS interface
				EMAC1PHYPOWERDOWN						=> Trans_PowerDown(1),
				EMAC1PHYMGTTXRESET					=> Trans_TX_Reset(1),
				EMAC1PHYMGTRXRESET					=> Trans_RX_Reset(1),
				EMAC1PHYLOOPBACKMSB					=> Trans_LoopBack(1),							-- perform loopback testing
				EMAC1PHYENCOMMAALIGN				=> Trans_EnableCommaAlign(1),			-- enable comma alignment

				-- TRANS TX interface
				EMAC1PHYTXD									=> Trans_TX_Data(1),
				EMAC1PHYTXCHARISK						=> Trans_TX_CharIsK(1),
				EMAC1PHYTXCHARDISPMODE			=> Trans_TX_DisparityMode(1),
				EMAC1PHYTXCHARDISPVAL				=> Trans_TX_DisparityValue(1),
				PHYEMAC1TXBUFERR						=> Trans_TX_BufferError(1),

				-- TRANS RX interface
				PHYEMAC1RXD									=> Trans_RX_Data(1),
				PHYEMAC1RXCHARISK						=> Trans_RX_CharIsK(1),
				PHYEMAC1RXCHARISCOMMA				=> Trans_RX_CharIsComma(1),
				PHYEMAC1RXDISPERR						=> Trans_RX_DisparityError(1),
				PHYEMAC1RXNOTINTABLE				=> Trans_RX_NotInTable(1),
				PHYEMAC1RXCLKCORCNT					=> Trans_RX_ClockCorrectionCount(1),
				PHYEMAC1RXBUFSTATUS					=> Trans_RX_BufferStatus(1),

				-- reserved - tie to ground
				PHYEMAC1RXCHECKINGCRC				=> '0',
				PHYEMAC1RXCOMMADET					=> '0',
				PHYEMAC1RXBUFERR						=> '0',
				PHYEMAC1RXLOSSOFSYNC				=> "00",
				PHYEMAC1RXRUNDISP						=> '0',

				-- optical light detected in optical transceiver
				PHYEMAC1SIGNALDET						=> '1'											-- set to high for copper cables
			);
	end generate;
end;
