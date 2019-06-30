
library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use     PoC.utils.all;
use     PoC.vectors.all;
use     PoC.axi4.all;

entity AXI4Lite_Register is
	Generic (
		ADDRESS_BITS  : natural                 := 32;
		DATA_BITS     : natural                 := 32;
	 	CONFIG        : T_AXI4_Register_Description_Vector  := (
				0 => to_AXI4_Register_Description(Address => to_unsigned(0,ADDRESS_BITS)),--, Writeable => true, Init_Value => x"ABCDEF01", Auto_Clear_Mask => x"FFFF0000"),
				1 => to_AXI4_Register_Description(Address => to_unsigned(4,ADDRESS_BITS)),--, Writeable => true, Init_Value => x"ABCDEF01", Auto_Clear_Mask => x"FFFF0000"),
				2 => to_AXI4_Register_Description(Address => to_unsigned(8,ADDRESS_BITS)),--, Writeable => true, Init_Value => x"ABCDEF01", Auto_Clear_Mask => x"FFFF0000"),
				3 => to_AXI4_Register_Description(Address => to_unsigned(12,ADDRESS_BITS)) --, Writeable => true, Init_Value => x"ABCDEF01", Auto_Clear_Mask => x"FFFF0000")
			)
	);
	Port (
		S_AXI_ACLK              : in  std_logic;
		S_AXI_ARESETN           : in  std_logic;
		S_AXI_m2s               : in  T_AXI4Lite_BUS_M2S := Initialize_AXI4Lite_Bus_M2S(32, 32);
		S_AXI_s2m               : out T_AXI4Lite_BUS_S2M := Initialize_AXI4Lite_Bus_S2M(32, 32);
		RegisterFile_ReadPort   : out T_SLVV(0 to CONFIG'Length -1)(DATA_BITS -1 downto 0);
		RegisterFile_WritePort  : in  T_SLVV(0 to CONFIG'Length -1)(DATA_BITS -1 downto 0)
	);
end AXI4Lite_Register;

architecture Behavioral of AXI4Lite_Register is
	-- Example-specific design signals
	-- local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	-- ADDR_LSB is used for addressing 32/64 bit registers/memories
	-- ADDR_LSB = 2 for 32 bits (n downto 2)
	-- ADDR_LSB = 3 for 64 bits (n downto 3)
	constant ADDR_LSB           : positive  := (DATA_BITS/32) + 1;
	
	-- AXI4LITE signals
	signal axi_awaddr      : std_logic_vector(ADDRESS_BITS -1 -ADDR_LSB downto 0)   := (others => '0');
	signal axi_awready     : std_logic := '0';
	signal axi_wready      : std_logic := '0';
	signal axi_bresp       : std_logic_vector(1 downto 0)  := "00";
	signal axi_bvalid      : std_logic := '0';
	signal axi_araddr      : std_logic_vector(ADDRESS_BITS -1 -ADDR_LSB downto 0)   := (others => '0');
	signal axi_arready     : std_logic := '0';
	signal axi_rdata       : std_logic_vector(DATA_BITS -1 downto 0)   := (others => '0');
	signal axi_rresp       : std_logic_vector(1 downto 0)  := "00";
	signal axi_rvalid      : std_logic := '0';

	signal RegisterFile    : T_SLVV(0 to CONFIG'Length -1)(DATA_BITS -1 downto 0);
	
	signal slv_reg_rden    : std_logic;
	signal slv_reg_wren    : std_logic;
	signal reg_data_out    : std_logic_vector(DATA_BITS -1 downto 0);
    
begin

    S_AXI_s2m.AWReady  <= axi_awready;
    S_AXI_s2m.WReady   <= axi_wready; 
    S_AXI_s2m.BResp    <= axi_bresp;  
    S_AXI_s2m.BValid   <= axi_bvalid; 
    S_AXI_s2m.ARReady  <= axi_arready;
    S_AXI_s2m.RData    <= axi_rdata;  
    S_AXI_s2m.RResp    <= axi_rresp;  
    S_AXI_s2m.RValid   <= axi_rvalid; 


   
    -------- WRITE TRANSACTION DEPENDECIES --------
    
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then 
            if (S_AXI_ARESETN = '0') then
                axi_awready <= '0';
                axi_awaddr <= (others => '0');
            elsif (axi_awready = '0' and S_AXI_m2s.AWValid = '1' and S_AXI_m2s.WValid = '1') then
                axi_awready <= '1';
                -- Write Address latching
                axi_awaddr <= S_AXI_m2s.AWAddr(S_AXI_m2s.AWAddr'high downto ADDR_LSB);
            else
                axi_awready <= '0';
            end if;
        end if;
    end process;

    
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then 
            if (S_AXI_ARESETN = '0') then
                axi_wready <= '0';
            elsif (axi_wready = '0' and S_AXI_m2s.AWValid = '1' and S_AXI_m2s.WValid = '1') then
                axi_wready <= '1';
            else
                axi_wready <= '0';
            end if;
        end if;
    end process;
    
    process(S_AXI_ACLK)
    	variable trunc_addr : std_logic_vector(CONFIG(0).address'range);
    begin
        if rising_edge(S_AXI_ACLK) then
            if ((S_AXI_ARESETN = '0')) then
                for i in CONFIG'range loop
                    RegisterFile(i) <= CONFIG(i).init_value;
                end loop;
            else
                if (slv_reg_wren = '1') then
                    for i in CONFIG'range loop
                    		trunc_addr := std_logic_vector(CONFIG(i).address);
                        if ((axi_awaddr = trunc_addr(CONFIG(i).address'length downto ADDR_LSB)) and (CONFIG(i).writeable)) then -- found fitting register and it is writable
                            for ii in S_AXI_m2s.WStrb'reverse_range loop
                                -- Respective byte enables are asserted as per write strobes  
                                if (S_AXI_m2s.WStrb(ii) = '1' ) then
                                    RegisterFile(i)(ii * 8 + 7 downto ii * 8) <= S_AXI_m2s.WData(8 * ii + 7 downto 8 * ii);
                                end if;
                            end loop;
                        end if;
                    end loop;
                else
                    --clear where needed, otherwise latch
                    for i in CONFIG'range loop
                        RegisterFile(i) <= RegisterFile(i) and (not CONFIG(i).Auto_Clear_Mask);  
                    end loop;
                end if;
            end if;
        end if;
    end process;
    
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then 
            if (S_AXI_ARESETN = '0') then
                axi_bvalid  <= '0';
                axi_bresp   <= C_AXI4_RESPONSE_OKAY;
            else
                if (axi_bvalid = '0' and axi_awready = '1' and axi_wready = '1' and S_AXI_m2s.WValid = '1' and S_AXI_m2s.AWValid = '1') then
                    axi_bvalid  <= '1';
                    axi_bresp   <= C_AXI4_RESPONSE_OKAY;
                elsif (S_AXI_m2s.BReady = '1' and axi_bvalid = '1') then
                    axi_bvalid <= '0';     
                end if;
            end if;
        end if;
    end process;
    
    slv_reg_wren    <= axi_wready and axi_awready and S_AXI_m2s.AWValid and S_AXI_m2s.WValid;        
    
    RegisterFile_ReadPort <= RegisterFile;
    
    -------- READ TRANSACTION DEPENDECIES --------
    
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then 
            if (S_AXI_ARESETN = '0') then
                axi_arready <= '0';
                axi_araddr  <= (others => '1');
            elsif (axi_arready = '0' and S_AXI_m2s.ARValid = '1') then
                axi_arready <= '1';
                axi_araddr  <= S_AXI_m2s.ARAddr(S_AXI_m2s.ARAddr'high downto ADDR_LSB);
            else
                axi_arready <= '0';
            end if;
        end if;
    end process;
    
    process (S_AXI_ACLK)
    begin
        if rising_edge(S_AXI_ACLK) then 
            if (S_AXI_ARESETN = '0') then
                axi_rvalid <= '0';
                axi_rresp  <= C_AXI4_RESPONSE_OKAY;
            elsif (axi_rvalid = '0' and S_AXI_m2s.ARValid = '1' and axi_arready = '1') then
                axi_rvalid <= '1';
                axi_rresp  <= C_AXI4_RESPONSE_OKAY;
            else
                axi_rvalid <= '0';
            end if;
        end if;
    end process;
    
    slv_reg_rden    <=  S_AXI_m2s.ARValid and axi_arready and (not axi_rvalid);   


    --todo
    
    blockReadMux: block
        signal mux      : T_SLVV(0 to CONFIG'Length -1)(DATA_BITS -1 downto 0);
    begin
        --only wire out register if read only
        genMux: for i in CONFIG'range generate
            genPort: if (not(CONFIG(i).writeable)) generate 
                mux(i) <= RegisterFile_WritePort(i);
            else generate
                mux(i) <= RegisterFile(i);
            end generate;
        end generate;
        
        process(mux, axi_araddr)
        	variable trunc_addr : std_logic_vector(CONFIG(0).address'range);
        begin
        		reg_data_out  <= (others => '0');
            for i in CONFIG'range loop
            		trunc_addr := std_logic_vector(CONFIG(i).address);
                if(axi_araddr = trunc_addr(CONFIG(i).address'length downto ADDR_LSB)) then
                    reg_data_out <= mux(i);
                    exit;
                end if;
            end loop;
        end process;
        
    end block;      
            
        -- Output register or memory read data
    process(S_AXI_ACLK) is
    begin
        if (rising_edge (S_AXI_ACLK)) then
            if  (S_AXI_ARESETN = '0')  then
                axi_rdata  <= (others => '0');
            elsif (slv_reg_rden = '1') then
                -- When there is a valid read address (S_AXI_m2s.ARValid) with 
                -- acceptance of read address by the slave (axi_arready), 
                -- output the read data 
                -- Read address mux

                axi_rdata <= reg_data_out;     -- register read data
            end if;
        end if;
    end process;  
    
end Behavioral;
