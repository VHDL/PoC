library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library PoC;
use		PoC.config.all;
use		PoC.sata.all;
use		PoC.utils.all;
use		PoC.vectors.all;
use		PoC.strings.all;

entity sata_oob_tx is port (
		clk			: in std_logic;
		tx_forceelecidle 	: out std_logic;
		tx_oob_command		: in T_SATA_OOB;
		tx_oob_complete		: out std_logic
	);
end sata_oob_tx;

architecture rtl of sata_oob_tx is

	signal burstcounter		: unsigned (2 downto 0) := (others => '0');
	signal counter			: unsigned (7 downto 0) := (others => '0');
	signal last_oob_command		: T_SATA_OOB;
	signal active_oob_command	: T_SATA_OOB;
	signal tx_oob_idle		: std_logic;

begin
	tx_forceelecidle <= tx_oob_idle;

	process (clk) begin
		if rising_edge(clk) then
			-- detect oob-signals
			counter <= counter + 1;
			last_oob_command <= tx_oob_command;

			if last_oob_command = SATA_OOB_NONE and tx_oob_command /= SATA_OOB_NONE then
				counter <= (others => '0');
				burstcounter <= (others => '0');
				tx_oob_complete <= '0';
				tx_oob_idle <= '1';
				active_oob_command <= tx_oob_command;
			end if;

			if active_oob_command =	SATA_OOB_COMRESET then
				if tx_oob_idle = '0' then
					if counter >= to_unsigned(15,8) then -- burst: 106.7ns
						counter <= (others =>'0');
						burstcounter <= burstcounter + 1;
						tx_oob_idle <= '1';
					end if;
				else -- tx_oob_idle = '1'
					if burstcounter < to_unsigned(6,3) then
						if counter >= to_unsigned(47,8) then -- elecidle: 320ns
							counter <= (others =>'0');
							tx_oob_idle <= '0';
						end if;
					else
						if counter >= to_unsigned(79,8) then -- release > 525ns
							tx_oob_idle <= '0';
							tx_oob_complete <= '1';
							active_oob_command <= SATA_OOB_NONE;
						end if;
					end if;
				end if;
			end if;

			if active_oob_command = SATA_OOB_COMWAKE then
				if tx_oob_idle = '0' then
					if counter >= to_unsigned(15,8) then	-- burst: 106.7ns
						counter <= (others =>'0');
						burstcounter <= burstcounter + 1;
						tx_oob_idle <= '1';
					end if;
				else -- tx_oob_idle = '1'
					if burstcounter < to_unsigned(6,3) then
						if counter >= to_unsigned(15,8) then -- elecidle: 106.7ns
							counter <= (others =>'0');
							tx_oob_idle <= '0';
						end if;
					else
						if counter >= to_unsigned(27,8) then -- release > 175ns
							tx_oob_idle <= '0';
							tx_oob_complete <= '1';
							active_oob_command <= SATA_OOB_NONE;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

end;
