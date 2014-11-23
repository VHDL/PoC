



entity misc_watch is
	generic (
		CLOCK_FREQ		: FREQ		:= 100 MHz
	);
	port (
		Clock					: STD_LOGIC;
		Reset					: STD_LOGIC;
		
		
	);
end;

architecture rtl of misc_watch is
	function cond_inc(condition : STD_LOGIC; value : UNSIGNED) return UNSIGNED is
	begin
		return mux(condition, value, (value + 1));
	end function;

	signal Tick_us								: UNSIGNED(6 downto 0)		:= (others => '0');
	signal TickCounter_us					: UNSIGNED(23 downto 0)		:= (others => '0');
	signal USecondCounter_us			: UNSIGNED(19 downto 0)		:= (others => '0');
	signal MSecondCounter_us			: UNSIGNED(9 downto 0)		:= (others => '0');
	signal SecondCounter_us				: UNSIGNED(5 downto 0)		:= (others => '0');
	signal MinuteCounter_us				: UNSIGNED(5 downto 0)		:= (others => '0');
	signal HourCounter_us					: UNSIGNED(4 downto 0)		:= (others => '0');
	signal DayOfWeekCounter_us		: UNSIGNED(2 downto 0)		:= (others => '0');
	signal DayOfMonthCounter_us		: UNSIGNED(4 downto 0)		:= (others => '0');
	signal DayOfYearCounter_us		: UNSIGNED(8 downto 0)		:= (others => '0');
	signal WeekCounter_us					: UNSIGNED(5 downto 0)		:= (others => '0');
	signal MonthCounter_us				: UNSIGNED(3 downto 0)		:= (others => '0');
	signal YearCounter_us					: UNSIGNED(12 downto 0)		:= (others => '0');
	
	signal Tick_evt								: STD_LOGIC								:= '0';
	signal TickCounter_evt				: STD_LOGIC								:= '0';
	signal USecondCounter_evt			: STD_LOGIC								:= '0';
	signal MSecondCounter_evt			: STD_LOGIC								:= '0';
	signal SecondCounter_evt			: STD_LOGIC								:= '0';
	signal MinuteCounter_evt			: STD_LOGIC								:= '0';
	signal HourCounter_evt				: STD_LOGIC								:= '0';
	signal DayOfWeekCounter_evt		: STD_LOGIC								:= '0';
	signal DayOfMonthCounter_evt	: STD_LOGIC								:= '0';
	signal DayOfYearCounter_evt		: STD_LOGIC								:= '0';
	signal WeekCounter_evt				: STD_LOGIC								:= '0';
	signal MonthCounter_evt				: STD_LOGIC								:= '0';
	signal YearCounter_evt				: STD_LOGIC								:= '0';
begin

	process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Tick_us								<= (others => '0');
				TickCounter_us				<= (others => '0');
				USecondCounter_us			<= (others => '0');
				MSecondCounter_us			<= (others => '0');
				SecondCounter_us			<= (others => '0');
				MinuteCounter_us			<= (others => '0');
				HourCounter_us				<= (others => '0');
				DayOfWeekCounter_us		<= (others => '0');
				DayOfMonthCounter_us	<= (others => '0');
				DayOfYearCounter_us		<= (others => '0');
				WeekCounter_us				<= (others => '0');
				MonthCounter_us				<= (others => '0');
				YearCounter_us				<= (others => '0');
			else
				Tick_us								<= mux(Tick_evt, (Tick_us + 1), (others => '0'));
				Tick_evt							<= to_sl(Tick_us = 99);
				
				TickCounter_us				<= mux(TickCounter_evt, cond_inc(Tick_evt, TickCounter_us), (others => '0'));
				TickCounter_evt				<= to_sl(TickCounter_us = 9999999);
				
				USecondCounter_us			<= mux(USecondCounter_evt, cond_inc(Tick_evt, USecondCounter_us), (others => '0'));
				USecondCounter_evt		<= to_sl(USecondCounter_us = 999999);
				
				MSecondCounter_us			<= mux(MSecondCounter_evt, cond_inc(Tick_evt, MSecondCounter_us), (others => '0'));
				MSecondCounter_evt		<= to_sl(MSecondCounter_us = 999);
				
				SecondCounter_us			<= mux(SecondCounter_evt, cond_inc((TickCounter_evt and Tick_evt), SecondCounter_us), (others => '0'));
				SecondCounter_evt			<= to_sl(SecondCounter_us = 59);
				
				MinuteCounter_us			<= mux(MinuteCounter_evt, cond_inc((SecondCounter_evt and Tick_evt), MinuteCounter_us), (others => '0'));
				MinuteCounter_evt			<= to_sl(MinuteCounter_us = 59);
				
				HourCounter_us				<= mux(HourCounter_evt, cond_inc((MinuteCounter_evt and Tick_evt), HourCounter_us), (others => '0'));
				HourCounter_evt				<= to_sl(HourCounter_us = 23);
				
				DayOfYearCounter_us		<= mux(DayOfYearCounter_evt, cond_inc((HourCounter_evt and Tick_evt), DayOfYearCounter_us), (others => '0'));
				DayOfYearCounter_evt	<= to_sl(DayOfYearCounter_us = 364);
			end if;
		end if;
	end process;

end;
