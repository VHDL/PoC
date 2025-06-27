library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library OSVVM;
context OSVVM.OsvvmContext;

library osvvm_common;
context osvvm_common.OsvvmCommonContext;

library OSVVM_AXI4 ;
context OSVVM_AXI4.Axi4LiteContext;

library PoC;
use     PoC.utils.all;
use     PoC.physical.all;
use     PoC.vectors.all;
use     PoC.axi4lite.all;


package AXI4Lite_Register_pkg is

	constant AXI_ADDR_WIDTH   : integer := 32;
	constant AXI_DATA_WIDTH   : integer := 32;
	constant AXI_STRB_WIDTH   : integer := AXI_DATA_WIDTH / 8;
	constant REG_ADDRESS_BITS : natural := PoC.axi4lite.ADDRESS_BITS;

	subtype AXIAddressType is std_logic_vector(AXI_ADDR_WIDTH - 1 downto 0);
	subtype AXIDataType    is std_logic_vector(AXI_DATA_WIDTH - 1 downto 0);

	procedure ReadInit (
		signal AxiMasterTransRec : inout Axi4LiteMasterTransactionRecType; 
		signal ReadPort          : T_SLVV(open)(DATA_BITS-1 downto 0);
		constant reg_index       : integer;
		constant addr            : AXIAddressType;
		constant init_val        : AXIDataType
	);

	procedure ReadReserved (
		signal AxiMasterTransRec : inout Axi4LiteMasterTransactionRecType; 
		constant addr            : AXIAddressType
	);

	procedure WriteCheck (
		signal AxiMasterTransRec : inout Axi4LiteMasterTransactionRecType; 
		signal ReadPort          : in  T_SLVV(open)(DATA_BITS-1 downto 0);
		signal WritePort         : out T_SLVV(open)(DATA_BITS-1 downto 0);
		constant reg_index       : integer;
		constant addr            : AXIAddressType;
		constant write_val       : AXIDataType
	);

	procedure WriteReserved (
		signal AxiMasterTransRec : inout Axi4LiteMasterTransactionRecType; 
		constant addr            : AXIAddressType
	);

end package;

package body AXI4Lite_Register_pkg is

	procedure ReadInit (
		signal   AxiMasterTransRec : inout Axi4LiteMasterTransactionRecType; 
		signal   ReadPort          : T_SLVV(open)(DATA_BITS-1 downto 0);
		constant reg_index         : integer;
		constant addr              : AXIAddressType;
		constant init_val          : AXIDataType 
	) is
	begin
		-- Read from transaction record
		ReadCheck(AxiMasterTransRec, addr, init_val);
		-- Read from PL side
		AffirmIfEqual(ReadPort(reg_index), init_val);
	end procedure;

	procedure ReadReserved (
		signal   AxiMasterTransRec : inout Axi4LiteMasterTransactionRecType; 
		constant addr              : AXIAddressType
	) is
		variable OptVal   : integer;
		variable ReadData : AXIDataType;
	begin
		GetAxi4Options(AxiMasterTransRec, RRESP, OptVal);
		SetAxi4Options(AxiMasterTransRec, RRESP, AXI4_RESP_DECERR);
		Read(AxiMasterTransRec, addr, ReadData);
		SetAxi4Options(AxiMasterTransRec, RRESP, OptVal);
	end procedure;

	procedure WriteCheck (
		signal   AxiMasterTransRec : inout Axi4LiteMasterTransactionRecType; 
		signal   ReadPort          : in  T_SLVV(open)(DATA_BITS-1 downto 0);
		signal   WritePort         : out T_SLVV(open)(DATA_BITS-1 downto 0);
		constant reg_index         : integer;
		constant addr              : AXIAddressType;
		constant write_val         : AXIDataType 
	) is
		variable ReadData : AXIDataType;
	begin
		-- WriteCheck to transaction record
		Write(AxiMasterTransRec, addr, write_val);
		Read(AxiMasterTransRec, addr, ReadData);

		-- Read from PL side
		WritePort            <= (WritePort'range => (DATA_BITS-1 downto 0 => 'X'));
		WritePort(reg_index) <= write_val;
		AffirmIfEqual(ReadPort(reg_index), write_val);
	end procedure;

	procedure WriteReserved (
		signal   AxiMasterTransRec : inout Axi4LiteMasterTransactionRecType; 
		constant addr              : AXIAddressType
	) is
		variable OptVal   : integer;
		variable ReadData : AXIDataType;
	begin
		GetAxi4Options(AxiMasterTransRec, BRESP, OptVal);
		SetAxi4Options(AxiMasterTransRec, BRESP, AXI4_RESP_DECERR);
		Write(AxiMasterTransRec, addr, 32x"00");
		SetAxi4Options(AxiMasterTransRec, BRESP, OptVal);
	end procedure;

end package body;
