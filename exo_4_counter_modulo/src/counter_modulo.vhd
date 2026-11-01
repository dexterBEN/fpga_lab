library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter_modulo is
    port (
        clk : in STD_LOGIC;
        btn1: in STD_LOGIC;
        btn0 : in STD_LOGIC;
        led : out STD_LOGIC_VECTOR(3 downto 0)
    );
end counter_modulo;

architecture counter_modulo_arch of counter_modulo is

    signal counter   : unsigned(3 downto 0) := (others => '0');
    signal btn0_prev : STD_LOGIC := '0';

begin

    process(clk)
    begin
        if rising_edge(clk) then

            btn0_prev <= btn0;

            if btn1 = '1' then
                counter <= "0000";
            elsif btn0 = '1' and btn0_prev = '0' then
                    if counter = "1001" then
                        counter <= "0000"; 
                    else
                        counter <= counter + 1;
                    end if;
                end if;
            end if;
    end process;

    led <= std_logic_vector(counter);

end counter_modulo_arch;