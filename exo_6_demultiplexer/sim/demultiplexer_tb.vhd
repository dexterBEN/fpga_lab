library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library std;
use std.env.all;

entity demultiplexer_tb is
end demultiplexer_tb;

architecture tb of demultiplexer_tb is

    signal d  : STD_LOGIC := '0';
    signal s  : STD_LOGIC_VECTOR(1 downto 0) := "00";

    signal y0 : STD_LOGIC;
    signal y1 : STD_LOGIC;
    signal y2 : STD_LOGIC;
    signal y3 : STD_LOGIC;

begin

    uut: entity work.demultiplexer
        port map (
            d  => d,
            s  => s,
            y0 => y0,
            y1 => y1,
            y2 => y2,
            y3 => y3
        );

    stimulus: process

        procedure test_demux(
            constant sel : in STD_LOGIC_VECTOR(1 downto 0);
            constant e0  : in STD_LOGIC;
            constant e1  : in STD_LOGIC;
            constant e2  : in STD_LOGIC;
            constant e3  : in STD_LOGIC
        ) is
        begin

            s <= sel;

            wait for 10 ns;

            assert y0 = e0
                report "DEMUX test failed on y0"
                severity error;

            assert y1 = e1
                report "DEMUX test failed on y1"
                severity error;

            assert y2 = e2
                report "DEMUX test failed on y2"
                severity error;

            assert y3 = e3
                report "DEMUX test failed on y3"
                severity error;

        end procedure;

    begin

        d <= '1';

        test_demux("00", '1', '0', '0', '0');
        test_demux("01", '0', '1', '0', '0');
        test_demux("10", '0', '0', '1', '0');
        test_demux("11", '0', '0', '0', '1');

        report "All demultiplexer tests passed"
            severity note;

        finish;

    end process;

end tb;