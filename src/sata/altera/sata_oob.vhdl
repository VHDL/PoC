library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library PoC;
use		PoC.config.all;
use		PoC.sata.all;
use		PoC.utils.all;
use		PoC.vectors.all;
use		PoC.strings.all;

entity sata_oob is port (
	clk					: in std_logic;
	tx_oob_command		: in T_SATA_OOB;
	rx_signaldetect 	: in std_logic;
	tx_oob_complete		: out std_logic;
	tx_forceelecidle 	: out std_logic;
	rx_oob_status		: out T_SATA_OOB
	);
end sata_oob;

architecture behavioral of sata_oob is

	component sata_oob_tx is port	(
		clk		: in std_logic;
		tx_forceelecidle: out std_logic;

		tx_oob_command	: in T_SATA_OOB;
		tx_oob_complete	: out std_logic
	); end component;

	component sata_oob_rx is port	(
		clk		: in std_logic;
		rx_signaldetect 	: in std_logic;
		rx_oob_status	: out T_SATA_OOB
	); end component;

begin -- behavioral

	tx : sata_oob_tx port map (
		clk => clk,
		tx_forceelecidle => tx_forceelecidle,
		tx_oob_command => tx_oob_command,
		tx_oob_complete => tx_oob_complete
	);

	rx : sata_oob_rx port map (
		clk => clk,
		rx_signaldetect => rx_signaldetect,
		rx_oob_status => rx_oob_status
	);


end behavioral;
