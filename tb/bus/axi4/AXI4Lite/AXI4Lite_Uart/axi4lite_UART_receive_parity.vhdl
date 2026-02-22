architecture receive_parity of axi4lite_UART_tc is
	subtype UARTDataType is std_logic_vector(7 downto 0);
	alias   UARTSequenceType is T_SLVV_8;
	constant TestData : UARTSequenceType :=  (x"5A", x"CA", x"FE", x"AF", x"FE", x"5A", x"CA", x"FE", x"AF", x"FE");	-- to PASSTHROUGH_ERROR_BYTE
	constant TestData_replacebyte : UARTSequenceType :=  (x"5A", x"15", x"FE", x"15", x"FE", x"5A", x"15", x"FE", x"15", x"FE");	--to REPLACE_ERROR_BYTE

	constant parityerror : boolean_vector := (FALSE, TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, FALSE, TRUE, FALSE);
	--constant TestData : UARTDataType := x"27";

	signal   TestDone        : integer_barrier := 1;
	signal   ReadByteTrigger : bit := '0';
begin
	-- Testbench control process
	ControlProc : process
	constant TIMEOUT : time := 10 ms;
	begin
		-- Initialization of test
		SetTestName("axi4lite_UART_receive_parity");
		SetLogEnable(PASSED, TRUE);  --Enable PASSED Logs
		SetLogEnable(INFO, TRUE);    --Enable INFO  Logs

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
		for j in parityerror'range loop
			WaitForToggle(ReadByteTrigger);
			CheckIsParity_flag(AXI_Manager, parityerror(j));
			
			log("Reading received data byte from UART register ...");
			Read(AXI_Manager, RX_REG, ReceivedData);
			AffirmIf(
				ReceivedData = toAXIData(TestData(j)),
				"Received: " & to_string(ReceivedData),
				" /= Expected: " & to_string(TestData)
		);
		end loop;
		wait for 500 us;  -- this delay is added because the uart implementation in OSVVM is providing half a stop bit and due to this there will be a error.
		WaitForBarrier(TestDone);
		wait;
	end process ManagerProc;

	-- Generate transactions for UART transmitter
	UartTxProc : process
	begin
		wait until Reset = '0';

		WaitForClock(UartTxRec, 1);
		for i in TestData'range loop 
			if parityerror(i) then
				Send(UartTxRec, TestData(i),UARTTB_PARITY_ERROR);				
			else
				Send(UartTxRec, TestData(i));				
			end if;	
			Toggle(ReadByteTrigger);
		end loop;
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


configuration axi4lite_UART_receive_parity of axi4lite_UART_th is
	for TestHarness
		for TestCtrl : axi4lite_UART_tc
			use entity work.axi4lite_UART_tc(receive_parity);
		end for;
	end for;
end configuration;
