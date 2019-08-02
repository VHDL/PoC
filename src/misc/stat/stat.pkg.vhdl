library IEEE;
use     IEEE.numeric_std.all;


package stat is
	type T_STAT_MINMAX_COUNTER_VALUE is record
		Value   : unsigned;
		Min     : unsigned;
		Max     : unsigned;
	end record;
end package;
