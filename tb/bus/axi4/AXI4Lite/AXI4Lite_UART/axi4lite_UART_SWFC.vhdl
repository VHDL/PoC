architecture Software_flowcontrol of axi4lite_UART_tc is
	subtype UARTDataType is std_logic_vector(7 downto 0);
	alias   UARTSequenceType is T_SLVV_8;

	alias SB_IDType is OSVVM.ScoreBoardPkg_slv.ScoreboardIdType;
	signal UART_receive_SB : SB_IDType;
	signal UART_transmit_SB : SB_IDType;

	constant TestCtrlID     : AlertLogIDType := NewID("TestController");

	constant TestData : UARTSequenceType :=  (x"5A",                                                                                                     -- 1B
											  x"CA",x"FE",x"AF",x"FE",                                                                                        -- 4B
											  x"DE",x"AD",x"BE",x"EF",x"DE",x"AD",x"BE",x"EF",                                                                -- 8B
											  x"CA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE",x"CA",x"FE",x"AF",x"FE",x"10",                 -- 16B
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
		0 => ( 4,  4, FALSE, FALSE),
		1 => ( 8,  8, FALSE, FALSE),
		2 => ( 11, 11, FALSE, FALSE),
		3 => (12, 12,  FALSE, FALSE),
		4 => (16, 16,  TRUE,  FALSE)
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
	signal   Read_Enable      : std_logic:= '0';
	signal   SWFC_TRigger    : integer:= 0; --software flow control trigger
	signal   latch_xon       : std_logic:= '0';
	signal   check_FC_Char   : std_logic:= '0';

	constant XON				: std_logic_vector(7 downto 0)	:= x"11";	-- ^Q
	constant XOFF				: std_logic_vector(7 downto 0)	:= x"13";	-- ^S
begin
	-- Testbench control process
	ControlProc : process
		constant TIMEOUT : time := 10 ms;
	begin
		-- Initialization of test
		SetTestName("axi4lite_UART_SWFC");
		SetLogEnable(PASSED, FALSE);  --Enable PASSED Logs
		SetLogEnable(INFO, FALSE);    --Enable INFO  Logs
		UART_receive_SB   <= OSVVM.ScoreBoardPkg_slv.NewID("UART_receive_SB");
        UART_transmit_SB  <= OSVVM.ScoreBoardPkg_slv.NewID("UART_transmit_SB");

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

	begin
		wait until Reset = '0';

		GetAlertLogID(AXI_Manager, AxiManagerLogID);
		SetLogEnable(AxiManagerLogID, INFO, False);
		OSVVM.ScoreBoardPkg_slv.Push(UART_transmit_SB, XON);
		OSVVM.ScoreBoardPkg_slv.Push(UART_transmit_SB, XOFF);
		OSVVM.ScoreBoardPkg_slv.Push(UART_transmit_SB, XON);
		OSVVM.ScoreBoardPkg_slv.Push(UART_transmit_SB, XOFF);
		OSVVM.ScoreBoardPkg_slv.Push(UART_transmit_SB, XON);

		for i in ReadoutLengths'range loop

			WaitForToggle(Read_Enable);

			CheckIsEmpty_RX(AXI_Manager, FALSE);
			CheckIsFull_RX(AXI_Manager, Sequences(i).IsFull);
			CheckIsOverrun_RX(AXI_Manager, Sequences(i).IsOverrun);

			log(ProcLogID, "Reading received data sequence " & to_string(i) & " of "  & to_string(ReadoutLengths(i)) & " bytes from UART register");
			for j in 0 to ReadoutLengths(i) - 1 loop
				Read(AXI_Manager, RX_REG, ReceivedData);
				OSVVM.ScoreBoardPkg_slv.Check(UART_receive_SB, ReceivedData(7 downto 0));
			end loop;
            toggle(latch_xon);
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
			if TransmitLengths(i) >= 12 then -- 12=(16*0.75) is the set upper limit for RX Fifo flow control.
			check_FC_Char <= '1';
			Increment(SWFC_TRigger);
			else
			check_FC_Char <= '0';
			Increment(SWFC_TRigger);
			end if;
			--Increment(SWFC_TRigger);
		end loop;

		WaitForBarrier(TestDone);
		wait;
	end process;

	-- Generate transactions for UART receiver
	UartRxProc : process
	constant ProcLogID    : AlertLogIDType := NewID("UartRxProc", TestCtrlID);
	variable ReceivedData : UARTDataType;

	begin
		wait until Reset = '0';
		for i in sequences'range loop
		  if check_FC_Char = '1' then

		     WaitForToggle(SWFC_TRigger);

		     Get(UartRxRec, ReceivedData);
		     OSVVM.ScoreBoardPkg_slv.Check(UART_transmit_SB, ReceivedData);
		     log(ProcLogID, "received XOFF character");

		     toggle(Read_Enable);

             WaitForToggle(latch_xon);

            Get(UartRxRec, ReceivedData);
		    OSVVM.ScoreBoardPkg_slv.Check(UART_transmit_SB, ReceivedData);

		    log(ProcLogID, "received XON character");
          else
		    WaitForToggle(SWFC_TRigger);
		    toggle(Read_Enable);
		  end if;
		end loop;

		WaitForBarrier(TestDone);
		wait;
	end process;
end architecture;


configuration axi4lite_UART_SWFC of uart_AXILite_th is
	for TestHarness
		for TestCtrl : axi4lite_UART_tc
			use entity work.axi4lite_UART_tc(Software_flowcontrol);
		end for;
	end for;
end configuration;
