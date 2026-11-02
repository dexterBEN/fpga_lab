----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/01/2026 08:03:09 PM
-- Design Name: 
-- Module Name: multiplexer - Behavioral
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
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity multiplexer is
    port (
        d0 : in  STD_LOGIC;
        d1 : in  STD_LOGIC;
        d2 : in  STD_LOGIC;
        d3 : in  STD_LOGIC;
        s  : in  STD_LOGIC_VECTOR(1 downto 0);
        y  : out STD_LOGIC
    );
end multiplexer;

architecture multiplexer_arch of multiplexer is

begin
    process (d0, d1, d2, d3, s) is
    begin

        if s = "00" then
            y <= d0;
        elsif s = "01" then
            y <= d1;
        elsif s = "10" then
            y <= d2;
        elsif s = "11" then
            y <= d3;
        else
            y <= '0';
        end if;
        
    end process;

end multiplexer_arch;
