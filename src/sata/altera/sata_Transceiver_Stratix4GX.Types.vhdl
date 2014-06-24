LIBRARY IEEE;
USE		IEEE.STD_LOGIC_1164.ALL;
USE		IEEE.NUMERIC_STD.ALL;

PACKAGE sata_TransceiverTypes IS
	TYPE T_SATA_TRANSCEIVER_COMMON_IN_SIGNALS IS RECORD
		RefClockIn_50_MHz	: STD_LOGIC;
		RefClockIn_150_MHz	: STD_LOGIC;
	END RECORD;

	TYPE T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS IS RECORD
		RX	: STD_LOGIC;
	END RECORD;

	TYPE T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS IS RECORD
		TX	: STD_LOGIC;
	END RECORD;
	
	TYPE T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS_VECTOR IS ARRAY(NATURAL RANGE <>) OF T_SATA_TRANSCEIVER_PRIVATE_IN_SIGNALS;
	TYPE T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS_VECTOR IS ARRAY(NATURAL RANGE <>) OF T_SATA_TRANSCEIVER_PRIVATE_OUT_SIGNALS;
	
	component sata_basic is port (
		reset			: in std_logic;
		inclk			: in std_logic;
		locked			: out std_logic;
		rx_clkout		: out std_logic;
		rx_datain		: in std_logic;
		rx_dataout		: out std_logic_vector (31 downto 0);
		rx_ctrlout		: out std_logic_vector (3 downto 0);
		rx_disperr		: out std_logic_vector (3 downto 0);
		rx_errdetect		: out std_logic_vector (3 downto 0);
		rx_signaldetect		: out std_logic;
		tx_clkout		: out std_logic;
		tx_forceelecidle	: in std_logic;
		tx_datain		: in std_logic_vector (31 downto 0);
		tx_ctrlin		: in std_logic_vector (3 downto 0);
		tx_dataout		: out std_logic;
		reconf_clk		: in std_logic;
		reconfig		: in std_logic;
		sata_gen		: in std_logic_vector(1 downto 0);
		busy			: out std_logic
	);
	end component;

	component sata_pll is port (
		reset		: in std_logic;
		inclk		: in std_logic;
		outclk		: out std_logic;
		locked		: out std_logic;
		reconf_clk	: in std_logic;
		reconfig	: in std_logic;
		sata_gen	: in std_logic_vector(1 downto 0);
		busy		: out std_logic
	);
	end component;

	component sata_tx_adapter is port (
		sata_gen   : in std_logic_vector(1 downto 0);
		tx_datain  : in std_logic_vector(31 downto 0);
		tx_ctrlin  : in std_logic_vector(3 downto 0);
		tx_clkout  : in std_logic;
		tx_dataout : out std_logic_vector(31 downto 0);
		tx_ctrlout : out std_logic_vector(3 downto 0)
	);
	end component;

	component sata_rx_adapter is port (
		sata_gen   : in std_logic_vector(1 downto 0);
		rx_clkin   : in std_logic;
		rx_datain  : in std_logic_vector(31 downto 0);
		rx_ctrlin  : in std_logic_vector(3 downto 0);
		rx_errin   : in std_logic_vector(3 downto 0);
		rx_clkout  : in std_logic;
		rx_dataout : out std_logic_vector(31 downto 0);
		rx_ctrlout : out std_logic_vector(3 downto 0);
		rx_syncout : out std_logic
	);
	end component;

END sata_TransceiverTypes;

PACKAGE BODY sata_TransceiverTypes IS
END PACKAGE BODY;
