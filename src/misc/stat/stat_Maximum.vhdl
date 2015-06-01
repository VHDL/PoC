
library	IEEE;
use			IEEE.std_logic_1164.all;
use			IEEE.numeric_std.all;

library	PoC;
use			PoC.utils.all;
use			PoC.vectors.all;


entity stat_Maximum is
	generic (
		DEPTH					: POSITIVE		:= 8;
		DATA_BITS			: POSITIVE		:= 16;
		COUNTER_BITS	: POSITIVE		:= 16
	);
	port (
		Clock					: in	STD_LOGIC;
		Reset					: in	STD_LOGIC;
		
		Enable				: in	STD_LOGIC;
		DataIn				: in	STD_LOGIC_VECTOR(DATA_BITS - 1 downto 0);
		
		Valids				: out	STD_LOGIC_VECTOR(DEPTH - 1 downto 0);
		Maximums			: out	T_SLM(DEPTH - 1 downto 0, DATA_BITS - 1 downto 0);
		Counts				: out	T_SLM(DEPTH - 1 downto 0, COUNTER_BITS - 1 downto 0)
	);
end entity;


architecture rtl of stat_Maximum is

	type T_TAG_MEMORY				is array(NATURAL range <>) of UNSIGNED(DATA_BITS - 1 downto 0);
	type T_COUNTER_MEMORY		is array(NATURAL range <>) of UNSIGNED(COUNTER_BITS - 1 downto 0);

	-- create matrix from vector-vector
	function to_slm(usv : T_TAG_MEMORY) return t_slm is
		variable slm		: t_slm(usv'range, DATA_BITS - 1 downto 0);
	begin
		for i in usv'range loop
			for j in DATA_BITS - 1 downto 0 loop
				slm(i, j)		:= usv(i)(j);
			end loop;
		end loop;
		return slm;
	end function;
	
	function to_slm(usv : T_COUNTER_MEMORY) return t_slm is
		variable slm		: t_slm(usv'range, COUNTER_BITS - 1 downto 0);
	begin
		for i in usv'range loop
			for j in COUNTER_BITS - 1 downto 0 loop
				slm(i, j)		:= usv(i)(j);
			end loop;
		end loop;
		return slm;
	end function;

	signal DataIn_us				: UNSIGNED(DataIn'range);

	signal TagHit						: STD_LOGIC_VECTOR(DEPTH - 1 downto 0);
	signal MaximumHit				: STD_LOGIC_VECTOR(DEPTH - 1 downto 0);
	signal TagMemory				: T_TAG_MEMORY(DEPTH - 1 downto 0)			:= (others => (others => '0'));
	signal CounterMemory		: T_COUNTER_MEMORY(DEPTH - 1 downto 0)	:= (others => (others => '0'));
	signal MaximumIndex			: STD_LOGIC_VECTOR(DEPTH - 1 downto 0)	:= ((DEPTH - 1) => '1', others => '0');
	signal ValidMemory			: STD_LOGIC_VECTOR(DEPTH - 1 downto 0)	:= (others => '0');
	
begin
	DataIn_us		<= unsigned(DataIn);

	genTagHit : for i in 0 to DEPTH - 1 generate
		TagHit(i)			<= to_sl(TagMemory(i) = DataIn_us);
		MaximumHit(i)	<= to_sl(TagMemory(i) < DataIn_us);
	end generate;

	process(Clock)
		variable NewMaximum_nxt		: STD_LOGIC_VECTOR(DEPTH - 1 downto 0);
		variable NewMaximum_idx 	: NATURAL;
		variable TagHit_idx 			: NATURAL;
	begin
		NewMaximum_nxt	:= MaximumIndex(MaximumIndex'high - 1 downto 0) & MaximumIndex(MaximumIndex'high);	
		NewMaximum_idx	:= to_index(onehot2bin(NewMaximum_nxt));
		TagHit_idx			:= to_index(onehot2bin(TagHit));
	
		if rising_edge(Clock) then
			if (Reset = '1') then
				ValidMemory										<= (others => '0');
			elsif ((slv_nand(ValidMemory) and slv_nor(TagHit) and Enable) = '1') then
				for i in DEPTH - 1 downto 1 loop
					if (MaximumHit(i) = '1') then
						TagMemory(i)			<= TagMemory(i - 1);
						ValidMemory(i)		<= ValidMemory(i - 1);
						CounterMemory(i)	<= CounterMemory(i - 1);
					end if;
				end loop;
				for i in 0 to DEPTH - 1 loop
					if (MaximumHit(i) = '1') then
						TagMemory(i)			<= DataIn_us;
						ValidMemory(i)		<= '1';
						CounterMemory(i)	<= to_unsigned(1, COUNTER_BITS);
						exit;
					end if;
				end loop;
			elsif ((slv_or(MaximumHit) and slv_nor(TagHit) and Enable) = '1') then
				for i in DEPTH - 1 downto 1 loop
					if (MaximumHit(i) = '1') then
						TagMemory(i)			<= TagMemory(i - 1);
						ValidMemory(i)		<= ValidMemory(i - 1);
						CounterMemory(i)	<= CounterMemory(i - 1);
					end if;
				end loop;
				for i in 0 to DEPTH - 1 loop
					if (MaximumHit(i) = '1') then
						TagMemory(i)			<= DataIn_us;
						ValidMemory(i)		<= '1';
						CounterMemory(i)	<= to_unsigned(1, COUNTER_BITS);
						exit;
					end if;
				end loop;
			elsif ((slv_or(TagHit) and Enable)= '1') then
				CounterMemory(TagHit_idx)			<= CounterMemory(TagHit_idx) + 1;
			end if;
		end if;
	end process;

	Valids		<= ValidMemory;
	Maximums	<= to_slm(TagMemory);
	Counts		<= to_slm(CounterMemory);

end architecture;
