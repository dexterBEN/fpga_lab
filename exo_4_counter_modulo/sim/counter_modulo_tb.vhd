library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library std;
use std.env.all;

entity counter_modulo_tb is
end counter_modulo_tb;

architecture tb of counter_modulo_tb is

    signal clk  : STD_LOGIC := '0';
    signal btn0 : STD_LOGIC := '0';
    signal btn1 : STD_LOGIC := '0';
    signal led  : STD_LOGIC_VECTOR(3 downto 0);

begin

    dut : entity work.counter_modulo
        port map (
            clk  => clk,
            btn0 => btn0,
            btn1 => btn1,
            led  => led
        );

    -- 125 MHz clock -> 8 ns period
    clk_process : process
    begin
        clk <= '0';
        wait for 4 ns;

        clk <= '1';
        wait for 4 ns;
    end process;

    stimulus : process
    begin

        -- Initial state
        btn0 <= '0';
        btn1 <= '0';
        wait for 20 ns;

        assert led = "0000"
            report "ERROR: initial counter value should be 0000"
            severity error;


        -- Press BTN0 ten times
        for i in 1 to 10 loop

            btn0 <= '1';
            wait for 16 ns;

            btn0 <= '0';
            wait for 16 ns;

        end loop;

        -- After 10 presses, modulo-10 counter must wrap to 0
        assert led = "0000"
            report "ERROR: counter should wrap to 0000 after 10 presses"
            severity error;


        -- Press BTN0 three more times
        for i in 1 to 3 loop

            btn0 <= '1';
            wait for 16 ns;

            btn0 <= '0';
            wait for 16 ns;

        end loop;

        assert led = "0011"
            report "ERROR: counter should be 0011 after 3 additional presses"
            severity error;


        -- Reset with BTN1
        btn1 <= '1';
        wait for 16 ns;

        btn1 <= '0';
        wait for 16 ns;

        assert led = "0000"
            report "ERROR: counter should reset to 0000"
            severity error;


        report "All counter modulo tests passed"
            severity note;

        finish;

    end process;

end tb;