LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;


ENTITY MAC_TX_Type_Prepender IS
	GENERIC (
		DEBUG													: BOOLEAN													:= FALSE;
		ETHERNET_TYPES								: T_NET_MAC_ETHERNETTYPE_VECTOR		:= (0 => to_net_mac_ethernettype(x"0000"))
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		In_Valid											: IN	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		In_Data												: IN	T_SLVV_8(ETHERNET_TYPES'length - 1 DOWNTO 0);
		In_SOF												: IN	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		In_EOF												: IN	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		In_Ready											: OUT	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		In_Meta_rst										: OUT	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		In_Meta_DestMACAddress_nxt		: OUT	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		In_Meta_DestMACAddress_Data		: IN	T_SLVV_8(ETHERNET_TYPES'length - 1 DOWNTO 0);
		
		Out_Valid											: OUT	STD_LOGIC;
		Out_Data											: OUT	T_SLV_8;
		Out_SOF												: OUT	STD_LOGIC;
		Out_EOF												: OUT	STD_LOGIC;
		Out_Ready											: IN	STD_LOGIC;
		Out_Meta_rst									: IN	STD_LOGIC;
		Out_Meta_DestMACAddress_nxt		: IN	STD_LOGIC;
		Out_Meta_DestMACAddress_Data	: OUT	T_SLV_8
	);
END;


ARCHITECTURE rtl OF MAC_TX_Type_Prepender IS
	ATTRIBUTE KEEP										: BOOLEAN;
	ATTRIBUTE FSM_ENCODING						: STRING;
	
	CONSTANT PORTS										: POSITIVE				:= ETHERNET_TYPES'length;

	CONSTANT META_RST_BIT							: NATURAL					:= 0;
	CONSTANT META_DEST_NXT_BIT				: NATURAL					:= 1;
	
	CONSTANT META_BITS								: POSITIVE				:= 24;
	CONSTANT META_REV_BITS						: POSITIVE				:= 2;
	
	TYPE T_STATE		IS (
		ST_IDLE,
			ST_PREPEND_TYPE_1,
			ST_PAYLOAD
	);

	SIGNAL State											: T_STATE																						:= ST_IDLE;
	SIGNAL NextState									: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State		: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL LLMux_In_Valid							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL LLMux_In_Data							: T_SLM(PORTS - 1 DOWNTO 0, T_SLV_8'range)								:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL LLMux_In_Meta							: T_SLM(PORTS - 1 DOWNTO 0, META_BITS - 1 DOWNTO 0)				:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL LLMux_In_Meta_rev					: T_SLM(PORTS - 1 DOWNTO 0, META_REV_BITS - 1 DOWNTO 0)		:= (OTHERS => (OTHERS => 'Z'));		-- necessary default assignment 'Z' to get correct simulation results (iSIM, vSIM, ghdl/gtkwave)
	SIGNAL LLMux_In_SOF								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL LLMux_In_EOF								: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);
	SIGNAL LLMux_In_Ready							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0);

	SIGNAL LLMux_Out_Valid						: STD_LOGIC;
	SIGNAL LLMux_Out_Data							: T_SLV_8;
	SIGNAL LLMux_Out_Meta							: STD_LOGIC_VECTOR(META_BITS - 1 DOWNTO 0);
	SIGNAL LLMux_Out_Meta_rev					: STD_LOGIC_VECTOR(META_REV_BITS - 1 DOWNTO 0);
	SIGNAL LLMux_Out_SOF							: STD_LOGIC;
	SIGNAL LLMux_Out_EOF							: STD_LOGIC;
	SIGNAL LLMux_Out_Ready						: STD_LOGIC;

	SIGNAL Is_DataFlow								: STD_LOGIC;
	SIGNAL Is_SOF											: STD_LOGIC;
	SIGNAL Is_EOF											: STD_LOGIC;
	
BEGIN

	LLMux_In_Valid		<= In_Valid;
	LLMux_In_Data			<= to_slm(In_Data);
	LLMux_In_SOF			<= In_SOF;
	LLMux_In_EOF			<= In_EOF;
	In_Ready					<= LLMux_In_Ready;
	
	genLLMuxIn : FOR I IN 0 TO PORTS - 1 GENERATE
		SIGNAL Meta			: STD_LOGIC_VECTOR(META_BITS - 1 DOWNTO 0);
	BEGIN
		Meta	(15 DOWNTO	0)	<= to_slv(ETHERNET_TYPES(I));
		Meta	(23 DOWNTO 16)	<= In_Meta_DestMACAddress_Data(I);
		
		assign_row(LLMux_In_Meta	, Meta	, I);
	END GENERATE;
	
	In_Meta_rst									<= get_col(LLMux_In_Meta_rev, META_RST_BIT);
	In_Meta_DestMACAddress_nxt	<= get_col(LLMux_In_Meta_rev, META_DEST_NXT_BIT);
	
	LLMux : ENTITY PoC.stream_Mux
		GENERIC MAP (
			PORTS									=> PORTS,
			DATA_BITS							=> LLMux_Out_Data'length,
			META_BITS							=> LLMux_Out_Meta'length,
			META_REV_BITS					=> LLMux_Out_Meta_rev'length
		)
		PORT MAP (
			Clock									=> Clock,
			Reset									=> Reset,
			
			In_Valid							=> LLMux_In_Valid,
			In_Data								=> LLMux_In_Data,
			In_Meta								=> LLMux_In_Meta,
			In_Meta_rev						=> LLMux_In_Meta_rev,
			In_SOF								=> LLMux_In_SOF,
			In_EOF								=> LLMux_In_EOF,
			In_Ready							=> LLMux_In_Ready,
			
			Out_Valid							=> LLMux_Out_Valid,
			Out_Data							=> LLMux_Out_Data,
			Out_Meta							=> LLMux_Out_Meta,
			Out_Meta_rev					=> LLMux_Out_Meta_rev,
			Out_SOF								=> LLMux_Out_SOF,
			Out_EOF								=> LLMux_Out_EOF,
			Out_Ready							=> LLMux_Out_Ready
		);
	
	LLMux_Out_Meta_rev(META_RST_BIT)				<= Out_Meta_rst;
	LLMux_Out_Meta_rev(META_DEST_NXT_BIT)		<= Out_Meta_DestMACAddress_nxt;
	
	Is_DataFlow		<= LLMux_Out_Valid AND Out_Ready;
	Is_SOF				<= LLMux_Out_Valid AND LLMux_Out_SOF;
	Is_EOF				<= LLMux_Out_Valid AND LLMux_Out_EOF;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State			<= ST_IDLE;
			ELSE
				State			<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, LLMux_Out_Valid, LLMux_Out_Data, LLMux_Out_Meta, LLMux_Out_EOF, Is_DataFlow, Is_SOF, Is_EOF, Out_Ready)
	BEGIN
		NextState							<= State;
		
		Out_Valid							<= '0';
		Out_Data							<= LLMux_Out_Data;
		Out_SOF								<= '0';
		Out_EOF								<= '0';

		LLMux_Out_Ready			<= '0';
	
		CASE State IS
			WHEN ST_IDLE =>
				IF (Is_SOF = '1') THEN
					Out_Valid				<= '1';
					Out_SOF					<= '1';
					Out_Data				<= LLMux_Out_Meta(15 DOWNTO 8);
					
					IF (Out_Ready = '1') THEN
						NextState			<= ST_PREPEND_TYPE_1;
					END IF;
				END IF;

			WHEN ST_PREPEND_TYPE_1 =>
				Out_Valid					<= '1';
				Out_Data					<= LLMux_Out_Meta(7 DOWNTO 0);
					
				IF (Out_Ready = '1') THEN
					NextState				<= ST_PAYLOAD;
				END IF;
			
			WHEN ST_PAYLOAD =>
				Out_Valid					<= LLMux_Out_Valid;
				Out_EOF						<= LLMux_Out_EOF;
				LLMux_Out_Ready	<= Out_Ready;

				IF ((Is_DataFlow AND Is_EOF) = '1') THEN
					NextState			<= ST_IDLE;
				END IF;
			
		END CASE;
	END PROCESS;

	Out_Meta_DestMACAddress_Data		<= LLMux_Out_Meta(23 DOWNTO 16);

END ARCHITECTURE;
