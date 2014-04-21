LIBRARY IEEE;
USE			IEEE.STD_LOGIC_1164.ALL;
USE			IEEE.NUMERIC_STD.ALL;

LIBRARY PoC;
USE			PoC.utils.ALL;

LIBRARY L_Global;
USE			L_Global.GlobalTypes.ALL;

LIBRARY L_IO;
USE			L_IO.IOTypes.ALL;

LIBRARY L_Ethernet;
USE			L_Ethernet.EthTypes.ALL;


ENTITY ARP_Tester IS
	GENERIC (
		CLOCK_FREQ_MHZ							: REAL																	:= 125.0;					-- 125 MHz
		ARP_LOOKUP_INTERVAL_MS			: REAL																	:= 100.0					-- 100 ms
	);
	PORT (
		Clock												: IN	STD_LOGIC;																	-- 
		Reset												: IN	STD_LOGIC;																	-- 

		Command											: IN	T_NET_ARP_TESTER_COMMAND;
		Status											: OUT	T_NET_ARP_TESTER_STATUS;
		
		IPCache_Lookup							: OUT	STD_LOGIC;
		IPCache_IPv4Address_rst			: IN	STD_LOGIC;
		IPCache_IPv4Address_nxt			: IN	STD_LOGIC;
		IPCache_IPv4Address_Data		: OUT	T_SLV_8;
		
		IPCache_Valid								: IN	STD_LOGIC;
		IPCache_MACAddress_rst			: OUT	STD_LOGIC;
		IPCache_MACAddress_nxt			: OUT	STD_LOGIC;
		IPCache_MACAddress_Data			: IN	T_SLV_8
	);
END;

ARCHITECTURE rtl OF ARP_Tester IS
	ATTRIBUTE KEEP													: BOOLEAN;
	
	SIGNAL Tick															: STD_LOGIC;
	ATTRIBUTE KEEP OF Tick									: SIGNAL IS TRUE;
	
	CONSTANT LOOKUP_ADDRESSES								: T_NET_IPV4_ADDRESS_VECTOR														:= (
		0 =>			to_net_ipv4_address("192.168.99.1"),
		1 =>			to_net_ipv4_address("192.168.99.2"),
		2 =>			to_net_ipv4_address("192.168.99.3"),
		3 =>			to_net_ipv4_address("192.168.99.4"),
		4 =>			to_net_ipv4_address("192.168.99.2"),
		5 =>			to_net_ipv4_address("192.168.99.5"),
		6 =>			to_net_ipv4_address("192.168.99.6"),
		7 =>			to_net_ipv4_address("192.168.99.7"),
		8 =>			to_net_ipv4_address("192.168.99.3"),
		9 =>			to_net_ipv4_address("192.168.99.8"),
		10 =>			to_net_ipv4_address("192.168.99.9"),
		11 =>			to_net_ipv4_address("192.168.99.2"),
		12 =>			to_net_ipv4_address("192.168.99.3"),
		13 =>			to_net_ipv4_address("192.168.99.2"),
		14 =>			to_net_ipv4_address("192.168.99.3"),
		15 =>			to_net_ipv4_address("192.168.99.1")
	);
	
	SUBTYPE T_BYTE_INDEX										 IS NATURAL RANGE 0 TO 3;
	
	TYPE T_STATE IS (
		ST_IDLE,
		ST_IPCACHE_LOOKUP_WAIT,
		ST_IPCACHE_READ
	);
	
	SIGNAL State														: T_STATE																								:= ST_IDLE;
	SIGNAL NextState												: T_STATE;
	
	SIGNAL IPv4Address_we										: STD_LOGIC;
	SIGNAL IPv4Address_sel									: T_BYTE_INDEX;
	SIGNAL IPv4Address_d										: T_NET_IPV4_ADDRESS																		:= to_net_ipv4_address("192.168.99.1");
	
	ATTRIBUTE KEEP OF IPCache_MACAddress_Data	: SIGNAL IS TRUE;
	
	SIGNAl Reader_Counter_en								: STD_LOGIC;
	SIGNAl Reader_Counter_us								: UNSIGNED(log2ceilnz(T_BYTE_INDEX'high) - 1 DOWNTO 0)	:= (OTHERS => '0');
	
	SIGNAl Lookup_Counter_en								: STD_LOGIC;
	SIGNAl Lookup_Counter_us								: UNSIGNED(3 DOWNTO 0)																	:= (OTHERS => '0');

BEGIN
	ASSERT FALSE REPORT "TICKCOUNTER_MAX: " & INTEGER'image(TimingToCycles_ms(ARP_LOOKUP_INTERVAL_MS, Freq_MHz2Real_ns(CLOCK_FREQ_MHZ))) & "    ARP_LOOKUP_INTERVAL_MS: " & REAL'image(ARP_LOOKUP_INTERVAL_MS) & " ms" SEVERITY NOTE;

		-- ARP_TestFSM
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
	
	PROCESS(State, Tick, IPCache_Valid, Reader_Counter_us)
	BEGIN
		NextState											<= State;
		
		Status												<= NET_ARP_TESTER_STATUS_IDLE;
		
		IPCache_Lookup								<= '0';
		IPCache_MACAddress_rst				<= '0';
		IPCache_MACAddress_nxt				<= '0';
		
		Reader_Counter_en							<= '0';
--		IPv4Address_we								<= '0';
--		IPv4Address_sel								<= 0;
		Lookup_Counter_en							<= '0';
		
		CASE State IS 
			WHEN ST_IDLE =>
				IF (Tick = '1') THEN
					IPCache_Lookup					<= '1';
					NextState								<= ST_IPCACHE_LOOKUP_WAIT;
				END IF;
				
			WHEN ST_IPCACHE_LOOKUP_WAIT =>
				Status										<= NET_ARP_TESTER_STATUS_TESTING;
				
				IPCache_MACAddress_rst		<= '1';
			
				IF (IPCache_Valid = '1') THEN
					IPCache_MACAddress_rst	<= '0';
					IPCache_MACAddress_nxt	<= '1';
				
					Reader_Counter_en				<= '1';
					NextState								<= ST_IPCACHE_READ;
				END IF;
				
			WHEN ST_IPCACHE_READ =>
				Status										<= NET_ARP_TESTER_STATUS_TESTING;
				Reader_Counter_en					<= '1';
				IPCache_MACAddress_nxt		<= '1';
				
				IF (Reader_Counter_us = 3) THEN
					Status									<= NET_ARP_TESTER_STATUS_TEST_COMPLETE;
--					IPv4Address_we					<= '1';
					Lookup_Counter_en				<= '1';
					NextState								<= ST_IDLE;
				END IF;
				
		END CASE;
	END PROCESS;

	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reader_Counter_en = '0') THEN
				Reader_Counter_us		<= to_unsigned(0, Reader_Counter_us'length);
			ELSE
				Reader_Counter_us		<= Reader_Counter_us + 1;
			END IF;
		END IF;
	END PROCESS;
	
	PROCESS(Clock)
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Reset = '1') THEN
				Lookup_Counter_us		<= to_unsigned(0, Lookup_Counter_us'length);
			ELSE
				IF (Lookup_Counter_en = '1') THEN
					Lookup_Counter_us		<= Lookup_Counter_us + 1;
				END IF;
			END IF;
		END IF;
	END PROCESS;
	
--	PROCESS(Clock)
--	BEGIN
--		IF rising_edge(Clock) THEN
--			IF (IPv4Address_we = '1') THEN
--				IPv4Address_d(IPv4Address_sel)		<= IPCache_MACAddress_Data;
--			END IF;
--		END IF;
--	END PROCESS;
	
	IPv4Address_d			<= LOOKUP_ADDRESSES(to_integer(Lookup_Counter_us));
	
	IPv4AddressSeq : ENTITY L_Global.Sequenzer
		GENERIC MAP (
			INPUT_BITS						=> 32,
			OUTPUT_BITS						=> 8,
			REGISTERED						=> FALSE
		)
		PORT MAP (
			Clock									=> Clock,
			Reset									=> Reset,
			
			Input									=> to_slv(IPv4Address_d),
			rst										=> IPCache_IPv4Address_rst,
			rev										=> '1',
			nxt										=> IPCache_IPv4Address_nxt,
			Output								=> IPCache_IPv4Address_Data
		);
	
	-- lookup interval tick generator
	PROCESS(Clock)
		CONSTANT TICKCOUNTER_RES_MS							: REAL																								:= ARP_LOOKUP_INTERVAL_MS;
		CONSTANT TICKCOUNTER_MAX								: POSITIVE																						:= TimingToCycles_ms(TICKCOUNTER_RES_MS, Freq_MHz2Real_ns(CLOCK_FREQ_MHZ));
		CONSTANT TICKCOUNTER_BITS								: POSITIVE																						:= log2ceilnz(TICKCOUNTER_MAX);
	
		VARIABLE TickCounter_s									: SIGNED(TICKCOUNTER_BITS DOWNTO 0)										:= to_signed(TICKCOUNTER_MAX, TICKCOUNTER_BITS + 1);
	BEGIN
		IF rising_edge(Clock) THEN
			IF (Tick = '1') THEN
				TickCounter_s		:= to_signed(TICKCOUNTER_MAX, TickCounter_s'length);
			ELSE
				TickCounter_s		:= TickCounter_s - 1;
			END IF;
		END IF;
		
		Tick			<= TickCounter_s(TickCounter_s'high);
	END PROCESS;

END ARCHITECTURE;