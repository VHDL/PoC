library IEEE;
use     IEEE.std_logic_1164.all;
use     IEEE.numeric_std.all;

library PoC;
use PoC.utils.all;
use PoC.axi4.all;

entity AXI4Lite_Reader is
    Port ( 
      Clock         : in STD_LOGIC;
      Reset         : in STD_LOGIC;
      
      Strobe        : in STD_LOGIC;
      Address       : in unsigned;
      Ready         : out std_logic;
      
      Data          : out std_logic_vector;
      Done          : out STD_LOGIC;
      Error         : out STD_LOGIC;
      
      ARValid       : out std_logic;
      ARReady       : in std_logic;
      ARAddr        : out unsigned;
      ARCache       : out T_AXI4_Cache := C_AXI4_Cache;
      ARProt        : out T_AXI4_Protect := C_AXI4_Protect;
      
      RValid        : in std_logic;
      RReady        : out std_logic;
      RData         : in std_logic_vector;
      RResp         : in T_AXI4_Response
    );
end entity;

architecture rtl of AXI4Lite_Reader is
  type T_State is (S_Idle, S_Write, S_wait);

  signal State : T_State := S_Idle;


begin

  process(Clock)
  begin
    if rising_edge(clock) then
      Done        <= '0';
      Error       <= '0';
      ARValid     <= '0';
      RReady      <= '0';
      Ready       <= '0';
      
      if Reset = '1' then
        State  <= S_Idle;
      else
        case State is
          when S_Idle =>
            Ready       <= '1';
            if Strobe = '1' then
              Ready     <= '0';
              ARValid   <= '1';
              RReady    <= '1';
              ARAddr    <= Address;
              State     <= S_Write;
            end if;
            
          when S_Write =>
            ARValid     <= '1';
            RReady      <= '1';
            if ARReady = '1' then
              ARValid     <= '0';
              if RResp = C_AXI4_RESPONSE_OKAY then
                if RValid = '1' then
                  RReady <= '0';
                  Data   <= RData;
                  State  <= S_Idle;
                  Done   <= '1';
                else
                  State  <= S_wait;
                end if;
              else
                Error       <= '1';
                State  <= S_Idle;
              end if;
            end if;
            
          when S_wait =>
            RReady   <= '1';
            if RValid = '1' then
              RReady <= '0';
              Data   <= RData;
              State  <= S_Idle;
              Done   <= '1';
            end if;
          when others =>
            Error  <= '1';
            State  <= S_Idle;
        end case;
      end if;
    end if;
  end process;

end architecture;