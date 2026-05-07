architecture transmit_burst of axi4lite_UART_tc is
	subtype UARTDataType is std_logic_vector(7 downto 0);
	alias   UARTSequenceType is T_SLVV_8;

	alias SB_IDType is OSVVM.ScoreBoardPkg_slv.ScoreboardIdType;
	-- alias SB_NewID  is OSVVM.ScoreBoardPkg_slv.NewID[string, AlertLogIDType, AlertLogReportModeType, NameSearchType, AlertLogPrintParentType return ScoreboardIDType];
	-- alias SB_Push   is OSVVM.ScoreBoardPkg_slv.Push;
	-- alias SB_Check  is OSVVM.ScoreBoardPkg_slv.Check;

	constant TestCtrlID     : AlertLogIDType := NewID("TestController");
	signal UART_transmit_SB : SB_IDType;

	constant TestData  : UARTSequenceType := (x"5A",                                                                                                                 -- 1B
	                                          x"CA",x"FE",x"AF",x"FE",                                                                                               -- 4B
	                                          x"DE",x"AD",x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",                                                                       -- 8B
	                                          x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",x"DE",x"AD",	                     -- 16B
	                                          x"CA",x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",x"DE",x"AD",                 -- 17B
	                                          x"DA",x"CA",x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",x"DE",x"AD");          -- 18B
	constant SequenceLengths : T_POSVEC := (1, 4, 8, 16);

	signal   TestDone  : integer_barrier := 1;
	signal   WriteDone : bit             := '0';     -- barrier for triggering uart rx process
	signal   ReadDone  : bit             := '0';     -- barrier for triggering manager after uart rx process is done.

begin
	-- Testbench control process
	ControlProc : process
		constant TIMEOUT    : time := 10 ms;
	begin
		-- Initialization of test
		SetTestName("axi4lite_UART_transmit_burst");
		SetLogEnable(PASSED, FALSE);                                    --Enable PASSED Logs
		SetLogEnable(INFO, FALSE);                                      --Enable INFO  Logs
		UART_transmit_SB <= OSVVM.ScoreBoardPkg_slv.NewID("UART_transmit_SB");

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
		std.env.finish;
		wait;
	end process ControlProc;

	-- Generate transaction for AXI manager
	ManagerProc : process
		constant ProcLogID       : AlertLogIDType := NewID("ManagerProc", TestCtrlID);
		variable AxiManagerLogID : AlertLogIDType;

		constant RX_REG      : AXIAddressType := 32x"00";
		constant TX_REG      : AXIAddressType := 32x"04";
		constant STATUS_REG  : AXIAddressType := 32x"08";
		constant CONTROL_REG : AXIAddressType := 32x"0C";

		variable result1       : boolean := true;
		variable result2       : boolean := true;
		variable isFull        : boolean := true;
		variable isEmpty       : boolean := true;

		--status reg for tx
		procedure StatusIsFull_TX(
			signal   manager : inout  AddressBusRecType;
			variable result  : out boolean
		) is
			variable Data : AXIDataType;
		begin
			Read(manager, STATUS_REG, Data);
			result := Data(3) = '1';
		end procedure;

		procedure WaitOnNotFull(
			signal manager : inout AddressBusRecType
		) is
			variable isFull : boolean := true;
		begin
			while isFull loop
				StatusIsFull_TX(manager, isFull);
			end loop;
		end procedure;

		procedure UARTSendBurst(
			signal manager : inout AddressBusRecType;
			constant data_array : in UARTSequenceType
		) is
		begin
			for i in data_array'range loop
				WaitOnNotFull(manager);
				OSVVM.ScoreBoardPkg_slv.Push(UART_transmit_SB, data_array(i));
				Write(manager, TX_REG, data_array(i));
			end loop;
		end procedure;
	begin
		wait until Reset = '0';

		WaitForClock(AXI_Manager, 2);

		GetAlertLogID(AXI_Manager, AxiManagerLogID);
		SetLogEnable(AxiManagerLogID, INFO, False);

		for i in SequenceLengths'range loop
			log(ProcLogID, "Send test sequence " & to_string(i) & " of " & to_string(SequenceLengths(i)) & " bytes by writing multiple bytes to UART TX register ...");
			UARTSendBurst(AXI_Manager, TestData(low(SequenceLengths, i) to high(SequenceLengths, i)));




			-- create a barrier here to notify UART RX process
			Toggle(WriteDone);

			-- read status, full should be 1
			StatusIsFull_TX(AXI_Manager, isFull);
			log(ProcLogID, "TX status reg is filled: " & to_string(isFull));


			-- wait for barriers from RX proces
			WaitForToggle(ReadDone);

			-- read status, empty should be 1
			StatusIsFull_TX(AXI_Manager, isEmpty);
			log(ProcLogID, "TX status reg is empty: " & to_string(not isEmpty));
		end loop;

	-- End of Test
		wait for 16 * 10 * UART_BAUD_PERIOD_115200;
		-- wait;
		WaitForBarrier(TestDone);
		wait;
	end process;

	-- Generate transactions for UART transmitter
	UartTxProc : process
		constant ProcLogID    : AlertLogIDType := NewID("UartTxProc", TestCtrlID);
	begin
		wait until Reset = '0';

		log(ProcLogID, "Transmit verification model isn't used in this testcase");

		WaitForBarrier(TestDone);
		wait;
	end process;


	-- Generate transactions for UART receiver
	UartRxProc : process
		constant ProcLogID    : AlertLogIDType := NewID("UartRxProc", TestCtrlID);
		variable ReceivedData : UARTDataType;
	begin
		wait until Reset = '0';

		for i in SequenceLengths'range loop
			-- barrier from manager process that all 17 bytes are written to fifo
			WaitForToggle(WriteDone);

			log(ProcLogID, "Receive sequence " & to_string(i) & " ...");

			-- Receive sequence length many bytes.
			for j in 0 to SequenceLengths(i) - 1 loop
				Get(UartRxRec, ReceivedData);                                             -- Read out the data.
				OSVVM.ScoreBoardPkg_slv.Check(UART_transmit_SB, ReceivedData);
			end loop;

			-- send barrier to manager
			Toggle(ReadDone);
		end loop;

		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;

configuration axi4lite_UART_transmit_burst of axi4lite_UART_th is
	for TestHarness
		for TestCtrl : axi4lite_UART_tc
			use entity work.axi4lite_UART_tc(transmit_burst);
		end for;
	end for;
end configuration;
