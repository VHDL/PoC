library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.stat.all;


entity stat_MinMaxCounter is
	generic (
		BITS            : natural;
		COUNT_ON_CLEAR  : boolean := TRUE
	);
	port (
		Clock         : in  std_logic;
		Reset         : in  std_logic;
		
		Enable        : in  std_logic;
		LatchAndClear : in  std_logic;
		
		Value         : out T_STAT_MINMAX_COUNTER_VALUE
	);
end entity;


architecture RTL of stat_MinMaxCounter is
	signal Counter_Value        : unsigned(BITS - 1 downto 0) := (others => '0');
	signal StableCounter_Value  : unsigned(BITS - 1 downto 0) := (others => '0');  -- XXX: @Max find a good name ;P
	signal Minimum              : unsigned(BITS - 1 downto 0) := (others => '1');
	signal Maximum              : unsigned(BITS - 1 downto 0) := (others => '0');
	signal has_counted          : std_logic; -- not needed
begin
	Counter : process(Clock)
	begin
		if rising_edge(Clock) then
			if (Reset = '1') then
				Counter_Value       <= (others => '0');
				StableCounter_Value <= (others => '0');
				Minimum             <= (others => '0');
				Maximum             <= (others => '0');
			else
				--counter:
				if (LatchAndClear = '1') then
					Counter_Value         <= (others => '0');
					if (COUNT_ON_CLEAR) then
						StableCounter_Value <= Counter_Value + 1;
					else
						StableCounter_Value <= Counter_Value;
					end if;
				elsif (Enable = '1') and ((not Counter_Value) /= 0) then
					Counter_Value         <= Counter_Value + 1;
				end if;
				
				--min max logic:
				if(StableCounter_Value > Maximum) then
					Maximum <= unsigned(StableCounter_Value);
				end if;
				
				if(StableCounter_Value < Minimum) then
					Minimum <= unsigned(StableCounter_Value);
				end if;
			end if;
		end if;
	end process;
	
	--wire out count
	Value.Value <= resize(StableCounter_Value, Value.Value'length);
	Value.Min   <= resize(Minimum, Value.Min'length);
	Value.Max   <= resize(Maximum, Value.Max'length);
end architecture;
