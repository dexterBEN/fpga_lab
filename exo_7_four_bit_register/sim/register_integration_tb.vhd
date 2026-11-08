library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity register_integration_tb is
end entity register_integration_tb;

architecture tb of register_integration_tb is

    constant CLK_PERIOD : time := 20 ns; -- 50 MHz

    signal clk      : std_logic := '0';
    signal reset    : std_logic := '1';
    signal commands : std_logic_vector(8 downto 0)
        := (others => '0');

    signal reset_out  : std_logic;
    signal load_out   : std_logic;
    signal shift_out  : std_logic;
    signal mode_out   : std_logic;
    signal serial_out : std_logic;
    signal data_out   : std_logic_vector(3 downto 0);

    signal q : std_logic_vector(3 downto 0);

begin

    -- Clock generation: 50 MHz
    clk <= not clk after CLK_PERIOD / 2;

    -- Command adapter
    adapter : entity work.register_command_adapter
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

    -- Register system
    registers : entity work.register_system
        port map (
            clk       => clk,
            reset     => reset,
            load      => load_out,
            shift     => shift_out,
            mode      => mode_out,
            d         => data_out,
            serial_in => serial_out,
            q         => q
        );

    stimulus : process

        -- Wait for one complete rising-edge observation
        procedure tick is
        begin
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

        -- Simulate a software request:
        -- 1. Prepare data and mode
        -- 2. Raise request bit
        -- 3. Hold long enough for synchronization
        -- 4. Lower request bit to rearm edge detection
        procedure send_pulse(
            constant base_command : in std_logic_vector(8 downto 0);
            constant request_bit  : in natural
        ) is
        begin
            commands <= base_command;

            for i in 1 to 3 loop
                tick;
            end loop;

            commands(request_bit) <= '1';

            for i in 1 to 4 loop
                tick;
            end loop;

            commands(request_bit) <= '0';

            for i in 1 to 4 loop
                tick;
            end loop;
        end procedure;

        variable cmd : std_logic_vector(8 downto 0);

    begin

        report "Starting register integration tests"
            severity note;

        -- =========================================
        -- TEST 1: Hardware reset
        -- =========================================

        commands <= (others => '0');
        reset <= '1';

        for i in 1 to 4 loop
            tick;
        end loop;

        assert q = "0000"
            report "Hardware reset failed"
            severity error;

        reset <= '0';

        for i in 1 to 4 loop
            tick;
        end loop;

        report "TEST 1: Hardware reset passed"
            severity note;

        -- =========================================
        -- TEST 2: Parallel register LOAD
        -- =========================================

        -- Command layout:
        -- bit 3:0 = parallel data
        -- bit 4   = serial_in
        -- bit 5   = mode
        -- bit 6   = load_request
        -- bit 7   = shift_request
        -- bit 8   = reset_request (unused here)

        cmd := (others => '0');
        cmd(3 downto 0) := "1010";

        send_pulse(cmd, 6);

        assert q = "1010"
            report "Parallel LOAD failed: expected 1010"
            severity error;

        report "TEST 2: Parallel LOAD passed"
            severity note;

        -- =========================================
        -- TEST 3: Parallel register holds its data
        -- =========================================

        commands <= (others => '0');

        for i in 1 to 5 loop
            tick;
        end loop;

        assert q = "1010"
            report "Parallel register did not hold its value"
            severity error;

        report "TEST 3: Parallel hold passed"
            severity note;

        -- =========================================
        -- TEST 4: Shift register SIPO
        -- =========================================

        -- Shift sequence: 1, 0, 1, 1
        -- Expected final output: 1011

        for i in 0 to 3 loop

            cmd := (others => '0');
            cmd(5) := '1'; -- Select shift register

            case i is
                when 0 => cmd(4) := '1';
                when 1 => cmd(4) := '0';
                when 2 => cmd(4) := '1';
                when 3 => cmd(4) := '1';
                when others => null;
            end case;

            send_pulse(cmd, 7);

        end loop;

        assert q = "1011"
            report "SIPO failed: expected 1011"
            severity error;

        report "TEST 4: SIPO passed"
            severity note;

        -- =========================================
        -- TEST 5: Multiplexer mode selection
        -- =========================================

        -- Select parallel register
        commands <= (others => '0');
        tick;

        assert q = "1010"
            report "MUX failed: parallel selection"
            severity error;

        -- Select shift register
        commands(5) <= '1';
        tick;

        assert q = "1011"
            report "MUX failed: shift selection"
            severity error;

        report "TEST 5: Multiplexer passed"
            severity note;

        -- =========================================
        -- TEST 6: Independent register storage
        -- =========================================

        -- Load a new value into the parallel
        -- register without altering the SIPO.
        cmd := (others => '0');
        cmd(3 downto 0) := "0101";

        send_pulse(cmd, 6);

        assert q = "0101"
            report "Second parallel LOAD failed"
            severity error;

        -- Switch back to shift register.
        commands <= (others => '0');
        commands(5) <= '1';
        tick;

        assert q = "1011"
            report "SIPO changed during parallel LOAD"
            severity error;

        report "TEST 6: Independent storage passed"
            severity note;

        -- =========================================
        -- TEST 7: Hardware reset clears both
        -- =========================================

        reset <= '1';
        tick;

        assert q = "0000"
            report "Final hardware reset failed"
            severity error;

        commands <= (others => '0');
        reset <= '0';

        for i in 1 to 4 loop
            tick;
        end loop;

        report "TEST 7: Final hardware reset passed"
            severity note;

        report "All register integration tests passed"
            severity note;

        stop;
        wait;

    end process;

end architecture tb;
