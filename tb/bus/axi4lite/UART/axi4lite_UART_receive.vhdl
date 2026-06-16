architecture receive of axi4lite_UART_tc is
	subtype UARTDataType is std_logic_vector(7 downto 0);

	constant TestData : UARTDataType := x"45";

	signal   TestDone        : integer_barrier := 1;
	signal   ReadByteTrigger : bit := '0';
begin
	-- Testbench control process
	ControlProc : process
		constant TIMEOUT : time := 10 ms;
	begin
		-- Initialization of test
		SetTestName("axi4lite_UART_receive");
		SetLogEnable(PASSED, FALSE);  --Enable PASSED Logs
		SetLogEnable(INFO, FALSE);    --Enable INFO  Logs

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
	end process ControlProc;

	-- Generate transaction for AXI manager
	ManagerProc : process
		constant RX_REG      : AXIAddressType := 32x"00";
		constant TX_REG      : AXIAddressType := 32x"04";
		constant STATUS_REG  : AXIAddressType := 32x"08";
		constant CONTROL_REG : AXIAddressType := 32x"0C";

		function toAXIData(data : UARTDataType) return AXIDataType is
		begin
			return 24x"00" & data;
		end function;

		variable ReceivedData : AXIDataType;
	begin
		wait until Reset = '0';

		WaitForToggle(ReadByteTrigger);

		log("Reading received data byte from UART register ...");
		Read(AXI_Manager, RX_REG, ReceivedData);
		AffirmIf(
			ReceivedData = toAXIData(TestData),
			"Received: " & to_hstring(ReceivedData),
			" /= Expected: " & to_hstring(TestData)
		);

		wait for 500 us;  -- this delay is added because the uart implementation in OSVVM is providing half a stop bit and due to this there will be a error.
		WaitForBarrier(TestDone);
		wait;
	end process ManagerProc;

	-- Generate transactions for UART transmitter
	UartTxProc : process
	begin
		wait until Reset = '0';

		WaitForClock(UartTxRec, 1);
		Send(UartTxRec, TestData);
		Toggle(ReadByteTrigger);

		WaitForBarrier(TestDone);
		wait;
	end process;


	-- Generate transactions for UART receiver
	UartRxProc : process
	begin
		wait until Reset = '0';

		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;


configuration axi4lite_UART_receive of axi4lite_UART_th is
	for TestHarness
		for TestCtrl : axi4lite_UART_tc
			use entity work.axi4lite_UART_tc(receive);
		end for;
	end for;
end configuration;
