----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 08/11/2026 10:50:19 PM
-- Design Name: 
-- Module Name: logic_gate - Behavioral
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

entity logic_gate is
    Port ( sw0 : in STD_LOGIC;
           sw1 : in STD_LOGIC;
           led0 : out STD_LOGIC);
end logic_gate;

architecture logic_gate_arch of logic_gate is

begin

    led0 <= sw0 and sw1;

end logic_gate_arch;
