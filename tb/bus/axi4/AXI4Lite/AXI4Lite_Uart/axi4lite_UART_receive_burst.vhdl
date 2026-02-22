architecture receive_burst of axi4lite_UART_tc is
	subtype UARTDataType is std_logic_vector(7 downto 0);	
	alias   UARTSequenceType is T_SLVV_8;

	alias SB_IDType is OSVVM.ScoreBoardPkg_slv.ScoreboardIdType;	
	signal UART_receive_SB : SB_IDType;
	
	constant TestCtrlID     : AlertLogIDType := NewID("TestController");
	
	constant TestData : UARTSequenceType :=  (x"5A",                                                                                                     -- 1B
											  x"CA",x"FE",x"AF",x"FE",                                                                                        -- 4B
											  x"DE",x"AD",x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",                                                                -- 8B
											  x"CA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE",                 -- 16B
											  x"DA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE", x"BA",         -- 17B
											  x"EA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE", x"BA",x"CA");         -- 18B

	type SequenceDescriptionType is record
		TransmitLength : positive;
		ReadoutLength  : positive;
		IsFull         : boolean;
		IsOverrun      : boolean;
	end record;
	type SequencesType is array(natural range <>) of SequenceDescriptionType;
	
	constant Sequences : SequencesType := (
		0 => ( 1,  1, FALSE, FALSE),
		1 => ( 4,  4, FALSE, FALSE),
		2 => ( 8,  8, FALSE, FALSE),
		3 => (16, 16,  TRUE, FALSE),
		4 => (17, 16,  TRUE,  TRUE)
	);

	function toTransmitLengths(sequences : SequencesType) return T_POSVEC is
		variable lengths : T_POSVEC(sequences'range);
	begin
		for i in sequences'range loop
			lengths(i) := sequences(i).TransmitLength;
		end loop;
		return lengths;
	end function;

	function toReadoutLengths(sequences : SequencesType) return T_POSVEC is
		variable lengths : T_POSVEC(sequences'range);
	begin
		for i in sequences'range loop
			lengths(i) := sequences(i).ReadoutLength;
		end loop;
		return lengths;
	end function;
	
	constant TransmitLengths : T_POSVEC := toTransmitLengths(Sequences);
	constant ReadoutLengths  : T_POSVEC := toReadoutLengths(Sequences);

	signal   TestDone        : integer_barrier := 1;
	signal   ReadByteTrigger : natural := 0;
begin
	-- Testbench control process
	ControlProc : process
		constant TIMEOUT : time := 10 ms;
	begin
		-- Initialization of test
		SetTestName("axi4lite_UART_receive_burst");
		SetLogEnable(PASSED, TRUE);  --Enable PASSED Logs
		SetLogEnable(INFO, TRUE);    --Enable INFO  Logs
		UART_receive_SB <= OSVVM.ScoreBoardPkg_slv.NewID("UART_receive_SB");		

		-- Wait for testbench Initialization
		wait for 0 ns;
		wait for 0 ns;
		TranscriptOpen;
		SetTranscriptMirror(TRUE);

		-- wait for design reset
		wait until Reset = '0';
		ClearAlerts;

		WaitForBarrier(TestDone, TIMEOUT);
		EndOfTestReports(ReportAll => TRUE, Timeout => now >= TIMEOUT);
		std.env.finish;.stop;
		wait;
	end process ControlProc;

	-- Generate transaction for AXI manager
	ManagerProc : process	
		constant ProcLogID       : AlertLogIDType := NewID("ManagerProc", TestCtrlID);
		variable AxiManagerLogID : AlertLogIDType;
		
		constant RX_REG          : AXIAddressType := 32x"00";
		constant TX_REG          : AXIAddressType := 32x"04";
		constant STATUS_REG      : AXIAddressType := 32x"08";
		constant CONTROL_REG     : AXIAddressType := 32x"0C";
		
		variable ReceivedData    : AXIDataType;
		variable isFull          :  boolean := true;
		variable isEmpty         :  boolean := true;
		
		-- status reg for rx, bit 5 checks for the Status_RX_Overrun
		procedure CheckIsEmpty_RX(
			signal   manager  : inout  AddressBusRecType;
			constant expected : in     boolean
		) is
			variable Data    : AXIDataType;
			variable isEmpty : boolean;
		begin
			Read(manager, STATUS_REG, Data);
			isEmpty := Data(0) = '0';
			AffirmIf(isEmpty = expected, "EmptyBit:     Received: " & to_string(isEmpty), " /= Expected: " & to_string(expected));
		end procedure;
		
		procedure CheckIsFull_RX(
			signal   manager  : inout  AddressBusRecType;
			constant expected : in     boolean
		) is
			variable Data   : AXIDataType;
			variable isFull : boolean;
		begin
			Read(manager, STATUS_REG, Data);
			isFull := Data(1) = '1';
			AffirmIf(isFull = expected, "FullBit:       Received: " & to_string(isFull), " /= Expected: " & to_string(expected));
		end procedure;
		
		procedure CheckIsOverrun_RX(
			signal   manager  : inout  AddressBusRecType;
			constant expected : in     boolean
		) is
			variable Data      : AXIDataType;
			variable isOverrun : boolean;
		begin
			Read(manager, STATUS_REG, Data);
			isOverrun := Data(5) = '1';
			AffirmIf(isOverrun = expected, "OverrunBit: Received: " & to_string(isOverrun), " /= Expected: " & to_string(expected));
		end procedure;
		
		procedure CheckIsParity_flag(
			signal   manager  : inout  AddressBusRecType;
			constant expected : in     boolean
		) is
			variable Data    : AXIDataType;
			variable parity_error : boolean;
		begin
			Read(manager, STATUS_REG, Data);
			parity_error := Data(7) = '1';
			AffirmIf(parity_error = expected, "EmptyBit:     Received: " & to_string(parity_error), " /= Expected: " & to_string(expected));
		end procedure;
		
	begin
		wait until Reset = '0';		
				
		GetAlertLogID(AXI_Manager, AxiManagerLogID);
		SetLogEnable(AxiManagerLogID, INFO, False); 
							
		for i in ReadoutLengths'range loop
			WaitForToggle(ReadByteTrigger);
			
			CheckIsEmpty_RX(AXI_Manager, FALSE);
			CheckIsParity_flag(AXI_Manager, FALSE);
			CheckIsFull_RX(AXI_Manager, Sequences(i).IsFull);
			CheckIsOverrun_RX(AXI_Manager, Sequences(i).IsOverrun);
			
			log(ProcLogID, "Reading received data sequence " & to_string(i) & " of "  & to_string(ReadoutLengths(i)) & " bytes from UART register");
			for j in 0 to ReadoutLengths(i) - 1 loop
				Read(AXI_Manager, RX_REG, ReceivedData);
				OSVVM.ScoreBoardPkg_slv.Check(UART_receive_SB, ReceivedData(7 downto 0));
			end loop;

			CheckIsEmpty_RX(AXI_Manager, TRUE);
			CheckIsFull_RX(AXI_Manager, FALSE);
			CheckIsOverrun_RX(AXI_Manager, FALSE);
		end loop;
				
		wait for 500 us;
		WaitForBarrier(TestDone);
		wait;
	end process ManagerProc;

	-- Generate transactions for UART transmitter
	UartTxProc : process
		constant ProcLogID    : AlertLogIDType := NewID("UartTxProc", TestCtrlID);
		
		procedure UARTSendBurst(
			signal uartRec : inout UartRecType; 
			constant data_array : in UARTSequenceType
		) is
		begin
			for i in data_array'range loop				
				OSVVM.ScoreBoardPkg_slv.Push(UART_receive_SB, data_array(i));				
				log(ProcLogID, "Sending  data of " & to_string(i) & "th  byte to AXI RX register");
				Send(uartRec, data_array(i));
			end loop;
		end procedure;	
	begin
		wait until Reset = '0';
		WaitForClock(UartTxRec, 1); 
		
		for i in TransmitLengths'range loop
			log("Send test sequence " & to_string(i) & " of " & to_string(TransmitLengths(i)) & " bytes to AXI RX register ...");
			UARTSendBurst(UartTxRec, TestData(low(TransmitLengths, i) to high(TransmitLengths, i)));
			Increment(ReadByteTrigger);
		end loop;
				
		WaitForBarrier(TestDone);
		wait;
	end process;

	-- Generate transactions for UART receiver
	UartRxProc : process
	constant ProcLogID    : AlertLogIDType := NewID("UartRxProc", TestCtrlID);
	begin
		wait until Reset = '0';
		
		log(ProcLogID, "Transmit verification model isn't used in this testcase");
		
		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;


configuration axi4lite_UART_receive_burst of axi4lite_UART_th is
	for TestHarness
		for TestCtrl : axi4lite_UART_tc
			use entity work.axi4lite_UART_tc(receive_burst);
		end for;
	end for;
end configuration;
