
library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

entity register_command_adapter_tb is
end entity;

architecture tb of register_command_adapter_tb is

    signal clk : std_logic := '0';
    signal commands : std_logic_vector(8 downto 0) := (others => '0');

    signal reset_out  : std_logic;
    signal load_out   : std_logic;
    signal shift_out  : std_logic;
    signal mode_out   : std_logic;
    signal serial_out : std_logic;
    signal data_out   : std_logic_vector(3 downto 0);

begin

    -- 50 MHz clock
    clk <= not clk after 10 ns;

    dut : entity work.register_command_adapter
        port map (
            clk        => clk,
            commands   => commands,
            reset_out  => reset_out,
            load_out   => load_out,
            shift_out  => shift_out,
            mode_out   => mode_out,
            serial_out => serial_out,
            data_out   => data_out
        );

    stimulus : process

        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

    begin
        -- Initialize synchronization registers
        tick;
        tick;
        tick;

        -- TEST 1: Direct command decoding
        -- data=1010, serial=1, mode=1
        commands <= "000111010";
        wait for 1 ns;

        assert data_out = "1010"
            report "Data decoding failed"
            severity error;

        assert serial_out = '1'
            report "Serial decoding failed"
            severity error;

        assert mode_out = '1'
            report "Mode decoding failed"
            severity error;

        -- TEST 2: LOAD rising-edge detection
        commands(6) <= '1';

        tick;
        assert load_out = '0'
            report "LOAD asserted too early"
            severity error;

        tick;
        assert load_out = '1'
            report "LOAD pulse missing"
            severity error;

        tick;
        assert load_out = '0'
            report "LOAD pulse longer than one cycle"
            severity error;

        tick;
        assert load_out = '0'
            report "LOAD repeated while request held high"
            severity error;

        -- Rearm LOAD
        commands(6) <= '0';
        tick;
        tick;
        tick;

        commands(6) <= '1';
        tick;
        tick;

        assert load_out = '1'
            report "Second LOAD pulse missing"
            severity error;

        tick;
        commands(6) <= '0';
        tick;
        tick;
        tick;

        -- TEST 3: SHIFT rising-edge detection
        commands(7) <= '1';

        tick;
        assert shift_out = '0'
            report "SHIFT asserted too early"
            severity error;

        tick;
        assert shift_out = '1'
            report "SHIFT pulse missing"
            severity error;

        tick;
        assert shift_out = '0'
            report "SHIFT pulse longer than one cycle"
            severity error;

        commands(7) <= '0';
        tick;
        tick;
        tick;

        -- TEST 4: RESET synchronization
        commands(8) <= '1';

        tick;
        assert reset_out = '0'
            report "RESET asserted too early"
            severity error;

        tick;
        assert reset_out = '1'
            report "RESET synchronization failed"
            severity error;

        commands(8) <= '0';
        tick;
        tick;

        assert reset_out = '0'
            report "RESET release failed"
            severity error;

        report "All adapter tests passed" severity note;

        stop;
        wait;

    end process;

end architecture;
