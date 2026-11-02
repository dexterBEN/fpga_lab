library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library std;
use std.env.all;

entity multiplexer_tb is
end multiplexer_tb;

architecture tb of multiplexer_tb is

    signal d0 : STD_LOGIC := '0';
    signal d1 : STD_LOGIC := '0';
    signal d2 : STD_LOGIC := '0';
    signal d3 : STD_LOGIC := '0';
    signal s  : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal y  : STD_LOGIC;

begin

    uut: entity work.multiplexer
        port map (
            d0 => d0,
            d1 => d1,
            d2 => d2,
            d3 => d3,
            s  => s,
            y  => y
        );

    stimulus: process

        procedure test_mux(
            constant sel      : in STD_LOGIC_VECTOR(1 downto 0);
            constant expected : in STD_LOGIC
        ) is
        begin
            s <= sel;

            wait for 10 ns;

            assert y = expected
                report "MUX test failed"
                severity error;
        end procedure;

    begin

        d0 <= '0';
        d1 <= '1';
        d2 <= '0';
        d3 <= '1';

        test_mux("00", '0');
        test_mux("01", '1');
        test_mux("10", '0');
        test_mux("11", '1');

        report "All multiplexer tests passed"
            severity note;

        finish;

    end process;

end tb;