use work.AXI4Stream.all;


package AXI4Stream_Sized is
	generic (
		DATA_BITS     : natural;
		USER_BITS     : natural := 0
	);

	subtype SIZED_M2S is T_AXI4STREAM_M2S(
		Data(DATA_BITS - 1 downto 0),
		User(USER_BITS - 1 downto 0)
	);
	subtype SIZED_S2M is T_AXI4STREAM_S2M;
	
	subtype SIZED_M2S_VECTOR is T_AXI4STREAM_M2S_VECTOR(open)(
		Data(DATA_BITS - 1 downto 0),
		User(USER_BITS - 1 downto 0)
	);
	subtype SIZED_S2M_VECTOR is T_AXI4STREAM_S2M_VECTOR;
end package;


use work.AXI4Lite.all;


package AXI4Lite_Sized is
	generic (
		ADDRESS_BITS  : natural;
		DATA_BITS     : natural
	);
	
	subtype SIZED_M2S is T_AXI4LITE_BUS_M2S(
		AWAddr(ADDRESS_BITS - 1 downto 0),
		WData(DATA_BITS - 1 downto 0),
		WStrb(DATA_BITS / 8 - 1 downto 0),
		ARAddr(ADDRESS_BITS - 1 downto 0)
	);
	subtype SIZED_S2M is T_AXI4LITE_BUS_S2M(
		RData(DATA_BITS - 1 downto 0)
	);
	
	subtype SIZED_M2S_VECTOR is T_AXI4LITE_BUS_M2S_VECTOR(open)(
		AWAddr(ADDRESS_BITS - 1 downto 0),
		WData(DATA_BITS - 1 downto 0),
		WStrb(DATA_BITS / 8 - 1 downto 0),
		ARAddr(ADDRESS_BITS - 1 downto 0)
	);
	subtype SIZED_S2M_VECTOR is T_AXI4LITE_BUS_S2M_VECTOR(open)(
		RData(DATA_BITS - 1 downto 0)
	);
end package;


use work.AXI4_Full.all;

package AXI4Full_Sized is
	generic (
		ADDRESS_BITS  : natural;
		DATA_BITS     : natural;
		USER_BITS     : natural := 0;
		ID_BITS       : natural := 0
	);

	subtype SIZED_M2S is T_AXI4_BUS_M2S(
		AWID(ID_BITS - 1 downto 0),
		AWAddr(ADDRESS_BITS - 1 downto 0),
		AWUser(USER_BITS - 1 downto 0),
		WUser(USER_BITS - 1 downto 0),
		WData(DATA_BITS - 1 downto 0),
		WStrb(DATA_BITS / 8 - 1 downto 0),
		ARAddr(ADDRESS_BITS - 1 downto 0),
		ARID(ID_BITS - 1 downto 0),
		ARUser(USER_BITS - 1 downto 0)
	);

	subtype SIZED_S2M is T_AXI4_BUS_S2M(
		BID(ID_BITS - 1 downto 0),
		BUser(USER_BITS - 1 downto 0),
		RData(DATA_BITS - 1 downto 0),
		RID(ID_BITS - 1 downto 0),
		RUser(USER_BITS - 1 downto 0)
	);
	
	subtype SIZED_M2S_VECTOR is T_AXI4_BUS_M2S_VECTOR(open)(
		AWID(ID_BITS - 1 downto 0),
		AWAddr(ADDRESS_BITS - 1 downto 0),
		AWUser(USER_BITS - 1 downto 0),
		WUser(USER_BITS - 1 downto 0),
		WData(DATA_BITS - 1 downto 0),
		WStrb(DATA_BITS / 8 - 1 downto 0),
		ARAddr(ADDRESS_BITS - 1 downto 0),
		ARID(ID_BITS - 1 downto 0),
		ARUser(USER_BITS - 1 downto 0)
	);

	subtype SIZED_S2M_VECTOR is T_AXI4_BUS_S2M_VECTOR(open)(
		BID(ID_BITS - 1 downto 0),
		BUser(USER_BITS - 1 downto 0),
		RData(DATA_BITS - 1 downto 0),
		RID(ID_BITS - 1 downto 0),
		RUser(USER_BITS - 1 downto 0)
	);
end package;
