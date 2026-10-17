library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library std;
use std.env.all;

entity binary_counter_tb is
end binary_counter_tb;

architecture tb of binary_counter_tb is

    signal clk  : STD_LOGIC := '0';
    signal btn0 : STD_LOGIC := '0';
    signal led  : STD_LOGIC_VECTOR(3 downto 0);

begin

    dut : entity work.binary_counter
        port map (
            clk  => clk,
            btn0 => btn0,
            led  => led
        );

    clk_process : process
    begin
        clk <= '0';
        wait for 4 ns;

        clk <= '1';
        wait for 4 ns;
    end process;

    stimulus : process
    begin

        btn0 <= '0';
        wait for 20 ns;

        assert led = "0000"
            report "ERROR: initial counter value should be 0000"
            severity error;

        -- First press
        btn0 <= '1';
        wait for 16 ns;

        assert led = "0001"
            report "ERROR: after first press, counter should be 0001"
            severity error;

        btn0 <= '0';
        wait for 20 ns;

        -- Second press
        btn0 <= '1';
        wait for 16 ns;

        assert led = "0010"
            report "ERROR: after second press, counter should be 0010"
            severity error;

        btn0 <= '0';
        wait for 20 ns;

        -- Third press
        btn0 <= '1';
        wait for 16 ns;

        assert led = "0011"
            report "ERROR: after third press, counter should be 0011"
            severity error;

        btn0 <= '0';
        wait for 20 ns;

        report "All binary counter tests passed"
            severity note;

        finish;

    end process;

end tb;