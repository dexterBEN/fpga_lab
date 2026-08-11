----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Dexter
-- 
-- Create Date: 08/08/2026 05:41:45 PM
-- Design Name: 
-- Module Name: switch_button - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity switch_button is
    Port ( sw : in STD_LOGIC;
        led : out STD_LOGIC);
end switch_button;

architecture Behavioral of switch_button is

begin

    led <= sw;

end Behavioral;
