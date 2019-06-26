library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use PoC.utils.all;
use PoC.axi4.all;

entity AXI4Lite_Writer is
  Port ( 
    Clock       : in STD_LOGIC;
    Reset       : in STD_LOGIC;
    
    Strobe      : in STD_LOGIC;
    Address     : in unsigned;
    Data        : in STD_LOGIC_VECTOR;
    Ready       : out STD_LOGIC;
    Done        : out STD_LOGIC;
    Error       : out STD_LOGIC;
    
    AWValid     : out std_logic; 
    AWReady     : in std_logic;
    AWAddr      : out unsigned; 
    AWCache     : out T_AXI4_Cache := C_AXI4_Cache;
    AWProt      : out T_AXI4_Protect := C_AXI4_Protect;
     
    WValid      : out std_logic;
    WReady      : in std_logic;
    WData       : out std_logic_vector;
    WStrb       : out std_logic_vector;
   
    BValid      : in std_logic;
    BReady      : out std_logic;
    BResp       : in T_AXI4_Response
    
  );
end AXI4Lite_Writer;

architecture rtl of AXI4Lite_Writer is
  
  type T_State is (S_Idle, S_Write, S_data_wait, S_Resp_wait);

  signal State : T_State := S_Idle;

begin
  WStrb <= (others => '1');

  process(clock)
  begin
    if rising_edge(clock) then
      Ready   <= '0';
      Done    <= '0';
      Error   <= '0';
      AWValid <= '0';
      WValid  <= '0';
      BReady  <= '0';
      
      if Reset = '1' then
        State <= S_Idle;
      else
        case State is
          when S_Idle =>
            Ready   <= '1';
            if Strobe = '1' then
              Ready   <= '0';
              AWValid <= '1';
              WValid  <= '1';
              AWAddr  <= Address;
              WData   <= Data;
              State <= S_Write;
            end if;
          when S_Write =>
            AWValid <= '1';
            WValid  <= '1';
            if AWReady = '1' then
              AWValid <= '0';
              if WReady = '1' then
                WValid  <= '0';
                BReady  <= '1';
                State   <= S_Resp_wait;
              else
                State   <= S_data_wait;
              end if;
            end if;
          when S_data_wait =>
            WValid  <= '1';
            if WReady = '1' then
              WValid  <= '0';
              BReady  <= '1';
              State   <= S_Resp_wait;
            end if;
          when S_Resp_wait =>
            BReady  <= '1';
            if BValid = '1' then
              BReady  <= '0';
              if BResp = C_AXI4_RESPONSE_OKAY then
                Done    <= '1';
              else
                Error <= '1';
              end if;
              State <= S_Idle;
            end if;
            
          when others =>
            State <= S_Idle;
            Error <= '1';
        end case;
      end if;
    end if;
  end process;

end rtl;
