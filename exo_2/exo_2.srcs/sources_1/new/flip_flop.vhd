----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/13/2026 12:02:37 AM
-- Design Name: 
-- Module Name: flip_flop - Behavioral
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

entity flip_flop is
    Port (
            clk  : in STD_LOGIC;
            sw0  : in STD_LOGIC;
            led0 : out STD_LOGIC;
            btn0 : in STD_LOGIC);
end flip_flop;

architecture flip_flop_arch of flip_flop is

begin
    flip_flop_d: process(clk)
    begin
        if rising_edge(clk) then
            if btn0 = '1' then
                led0 <= sw0;
            end if;
        end if;
    end process flip_flop_d;

end flip_flop_arch;
