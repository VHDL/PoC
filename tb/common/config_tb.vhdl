entity config_tb is
end config_tb;


library PoC;
use PoC.config.all;

architecture tb of config_tb is
begin
  process
  begin
    report "Vendor: "&vendor_t'image(VENDOR) severity note;
    report "Device: "&device_t'image(DEVICE) severity note;
    wait;
  end process;
end tb;
