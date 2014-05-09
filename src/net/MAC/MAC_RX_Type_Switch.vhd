LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.config.ALL;
USE			PoC.utils.ALL;
USE			PoC.vectors.ALL;
USE			PoC.net.ALL;


ENTITY MAC_RX_Type_Switch IS
	GENERIC (
		DEBUG													: BOOLEAN													:= FALSE;
		ETHERNET_TYPES								: T_NET_MAC_ETHERNETTYPE_VECTOR		:= (0 => C_NET_MAC_ETHERNETTYPE_EMPTY)
	);
	PORT (
		Clock													: IN	STD_LOGIC;
		Reset													: IN	STD_LOGIC;
		
		In_Valid											: IN	STD_LOGIC;
		In_Data												: IN	T_SLV_8;
		In_SOF												: IN	STD_LOGIC;
		In_EOF												: IN	STD_LOGIC;
		In_Ready											: OUT	STD_LOGIC;
		In_Meta_rst										: OUT	STD_LOGIC;
		In_Meta_SrcMACAddress_nxt			: OUT	STD_LOGIC;
		In_Meta_SrcMACAddress_Data		: IN	T_SLV_8;
		In_Meta_DestMACAddress_nxt		: OUT	STD_LOGIC;
		In_Meta_DestMACAddress_Data		: IN	T_SLV_8;

		Out_Valid											: OUT	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		Out_Data											: OUT	T_SLVV_8(ETHERNET_TYPES'length - 1 DOWNTO 0);
		Out_SOF												: OUT	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		Out_EOF												: OUT	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		Out_Ready											: IN	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		Out_Meta_rst									: IN	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		Out_Meta_SrcMACAddress_nxt		: IN	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		Out_Meta_SrcMACAddress_Data		: OUT	T_SLVV_8(ETHERNET_TYPES'length - 1 DOWNTO 0);
		Out_Meta_DestMACAddress_nxt		: IN	STD_LOGIC_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0);
		Out_Meta_DestMACAddress_Data	: OUT	T_SLVV_8(ETHERNET_TYPES'length - 1 DOWNTO 0);
		Out_Meta_EthType							: OUT	T_NET_MAC_ETHERNETTYPE_VECTOR(ETHERNET_TYPES'length - 1 DOWNTO 0)
	);
END;


ARCHITECTURE rtl OF MAC_RX_Type_Switch IS
	ATTRIBUTE KEEP									: BOOLEAN;
	ATTRIBUTE FSM_ENCODING					: STRING;
	
	CONSTANT PORTS									: POSITIVE																			:= ETHERNET_TYPES'length;
	CONSTANT ETHERNET_TYPES_I				: T_NET_MAC_ETHERNETTYPE_VECTOR(0 TO PORTS - 1)	:= ETHERNET_TYPES;

	TYPE T_STATE		IS (
		ST_IDLE,
			ST_TYPE_1,
			ST_PAYLOAD_1,
			ST_PAYLOAD_N,
		ST_DISCARD_FRAME
	);

	SUBTYPE T_ETHERNETTYPE_BYTEINDEX			IS NATURAL RANGE 0 TO 1;
	
	SIGNAL State													: T_STATE																	:= ST_IDLE;
	SIGNAL NextState											: T_STATE;
	ATTRIBUTE FSM_ENCODING OF State				: SIGNAL IS ite(DEBUG, "gray", ite((VENDOR = VENDOR_XILINX), "auto", "default"));

	SIGNAL In_Ready_i											: STD_LOGIC;
	SIGNAL Is_DataFlow										: STD_LOGIC;
	SIGNAL Is_SOF													: STD_LOGIC;
	SIGNAL Is_EOF													: STD_LOGIC;
	
	SIGNAL New_Valid_i										: STD_LOGIC;
	SIGNAL New_SOF_i											: STD_LOGIC;
	SIGNAL Out_Ready_i										: STD_LOGIC;
	
	SIGNAL EthernetType_CompareIndex			: T_ETHERNETTYPE_BYTEINDEX;
	
	SIGNAL CompareRegister_rst						: STD_LOGIC;
	SIGNAL CompareRegister_init						: STD_LOGIC;
	SIGNAL CompareRegister_clear					: STD_LOGIC;
	SIGNAL CompareRegister_en							: STD_LOGIC;
	SIGNAL CompareRegister_d							: STD_LOGIC_VECTOR(PORTS - 1 DOWNTO 0)		:= (OTHERS => '1');
	SIGNAL NoHits													: STD_LOGIC;
	
	SIGNAL EthernetType_rst								: STD_LOGIC;
	SIGNAL EthernetType_en								: STD_LOGIC;
	SIGNAL EthernetType_sel								: T_ETHERNETTYPE_BYTEINDEX;
	SIGNAL EthernetType_d									: T_NET_MAC_ETHERNETTYPE									:= C_NET_MAC_ETHERNETTYPE_EMPTY;
	
BEGIN

	In_Ready			<= In_Ready_i;
	Is_DataFlow		<= In_Valid AND In_Ready_i;
	Is_SOF				<= In_Valid AND In_SOF;
	Is_EOF				<= In_Valid AND In_EOF;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				State		<= ST_IDLE;
			ELSE
				State		<= NextState;
			END IF;
		END IF;
	END PROCESS;

	PROCESS(State, Is_DataFlow, Is_SOF, Is_EOF, In_Valid, NoHits, Out_Ready_i)
	BEGIN
		NextState												<= State;

		In_Ready_i											<= '0';
		
		New_Valid_i											<= '0';
		New_SOF_i												<= '0';

		CompareRegister_en							<= '0';
		CompareRegister_rst							<= '0';
		CompareRegister_init						<= Is_SOF;
		CompareRegister_clear						<= Is_EOF;

		EthernetType_CompareIndex				<= 1;
		EthernetType_rst								<= '0';
		EthernetType_en									<= '0';
		EthernetType_sel								<= 1;

		CASE State IS
			WHEN ST_IDLE =>
				EthernetType_rst						<= '1';
				EthernetType_en							<= '0';
			
				IF (Is_SOF = '1') THEN
					EthernetType_rst					<= '0';
					EthernetType_en						<= '1';
					In_Ready_i								<= '1';
				
					IF (Is_EOF = '0') THEN
						NextState								<= ST_TYPE_1;
					ELSE
						NextState								<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_TYPE_1 =>
				EthernetType_CompareIndex		<= 0;
				EthernetType_en							<= In_Valid;
				EthernetType_sel						<= 0;
				CompareRegister_en					<= In_Valid;
			
				IF (In_Valid = '1') THEN
					In_Ready_i								<= '1';
				
					IF (Is_EOF = '0') THEN
						NextState								<= ST_PAYLOAD_1;
					ELSE
						NextState								<= ST_IDLE;
					END IF;
				END IF;
			
			WHEN ST_PAYLOAD_1 =>
				IF (NoHits = '1') THEN
					IF (Is_EOF = '0') THEN
						In_Ready_i							<= '1';
						NextState								<= ST_DISCARD_FRAME;
					ELSE
						NextState								<= ST_IDLE;
					END IF;
				ELSE
					In_Ready_i								<= Out_Ready_i;
					New_Valid_i								<= In_Valid;
					New_SOF_i									<= '1';
				
					IF (IS_DataFlow = '1') THEN
						IF (Is_EOF = '0') THEN
							NextState							<= ST_PAYLOAD_N;
						ELSE
							NextState							<= ST_IDLE;
						END IF;
					END IF;
				END IF;
				
			WHEN ST_PAYLOAD_N =>
				In_Ready_i									<= Out_Ready_i;
				New_Valid_i									<= In_Valid;
			
				IF ((IS_DataFlow AND Is_EOF) = '1') THEN
					NextState									<= ST_IDLE;
				END IF;
				
			WHEN ST_DISCARD_FRAME =>
				In_Ready_i									<= '1';
			
				IF ((IS_DataFlow AND Is_EOF) = '1') THEN
					NextState									<= ST_IDLE;
				END IF;
				
		END CASE;
	END PROCESS;

	
	gen0 : FOR I IN 0 TO PORTS - 1 GENERATE
		SIGNAL Hit								: STD_LOGIC;
	BEGIN
		Hit <= to_sl(In_Data = ETHERNET_TYPES_I(I)(EthernetType_CompareIndex));
		
		PROCESS(Clock)
		BEGIN
			IF rising_edge(Clock) THEN
				IF ((Reset OR CompareRegister_rst) = '1') THEN
					CompareRegister_d(I)				<= '0';
				ELSE
					IF (CompareRegister_init	= '1') THEN
						CompareRegister_d(I)			<= Hit;
					ELSIF (CompareRegister_clear	= '1') THEN
						CompareRegister_d(I)			<= '0';
					ELSIF (CompareRegister_en  = '1') THEN
						CompareRegister_d(I)			<= CompareRegister_d(I) AND Hit;
					END IF;
				END IF;
			END IF;
		END PROCESS;
	END GENERATE;

	NoHits									<= slv_nor(CompareRegister_d);

--	PROCESS(Clock)
--	BEGIN
--		IF rising_edge(Clock) THEN
--			IF ((Reset OR EthernetType_rst) = '1') THEN
--				EthernetType_d		<= C_NET_MAC_ETHERNETTYPE_EMPTY;
--			ELSE
--				IF (EthernetType_en = '1') THEN
--					EthernetType_d(EthernetType_sel) 	<= In_Data;
--				END IF;
--			END IF;
--		END IF;
--	END PROCESS;

	Out_Valid											<= (Out_Valid'range => New_Valid_i) AND CompareRegister_d;
	Out_Data											<= (Out_Data'range	=> In_Data);
	Out_SOF												<= (Out_SOF'range		=> New_SOF_i);
	Out_EOF												<= (Out_EOF'range		=> In_EOF);
	Out_Ready_i										<= slv_or(Out_Ready AND CompareRegister_d);

	-- Meta: rst
	In_Meta_rst										<= slv_or(Out_Meta_rst AND CompareRegister_d);

	-- Meta: DestMACAddress
	In_Meta_DestMACAddress_nxt		<= slv_or(Out_Meta_DestMACAddress_nxt AND CompareRegister_d);
	Out_Meta_DestMACAddress_Data	<= (Out_Data'range	=> In_Meta_DestMACAddress_Data);
	
	-- Meta: SrcMACAddress
	In_Meta_SrcMACAddress_nxt			<= slv_or(Out_Meta_SrcMACAddress_nxt AND CompareRegister_d);
	Out_Meta_SrcMACAddress_Data		<= (Out_Data'range	=> In_Meta_SrcMACAddress_Data);
	
	-- Meta: EthType
	genEthType : FOR I IN ETHERNET_TYPES_I'range GENERATE
		Out_Meta_EthType(I)					<= ETHERNET_TYPES_I(I);		--(Out_Data'range	=> EthernetType_d);			-- after exact match, the register value must be the same as in the array => use const arry values => better optimization
	END GENERATE;
END ARCHITECTURE;
