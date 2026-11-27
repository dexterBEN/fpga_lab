library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library STD;
use STD.ENV.ALL;

entity uart_rx_robustness_tb is
end entity uart_rx_robustness_tb;

architecture uart_rx_robustness_tb_arch
    of uart_rx_robustness_tb is

    --------------------------------------------------
    -- Testbench configuration
    --------------------------------------------------

    constant CLK_FREQ   : positive := 50_000_000;
    constant BAUD_RATE  : positive := 115_200;
    constant CLK_PERIOD : time := 20 ns;

    constant CLKS_PER_BIT : positive :=
        CLK_FREQ / BAUD_RATE;

    constant BIT_PERIOD : time :=
        CLKS_PER_BIT * CLK_PERIOD;

    constant FRAME_PERIOD : time :=
        10 * BIT_PERIOD;

    -- Transmitter baud rate variations (+/- 2%).
    constant FAST_BIT_PERIOD : time :=
        BIT_PERIOD * 100 / 102;

    constant SLOW_BIT_PERIOD : time :=
        BIT_PERIOD * 100 / 98;

    --------------------------------------------------
    -- DUT signals
    --------------------------------------------------

    signal clk           : std_logic := '0';
    signal reset         : std_logic := '0';
    signal rx_in         : std_logic := '1';

    signal data_out      : std_logic_vector(7 downto 0);
    signal rx_busy       : std_logic;
    signal done          : std_logic;
    signal framing_error : std_logic;

    --------------------------------------------------
    -- Verification signals
    --------------------------------------------------

    signal received_count : natural := 0;
    signal error_count    : natural := 0;

    signal expected_data : std_logic_vector(7 downto 0)
        := (others => '0');

begin

    --------------------------------------------------
    -- Device Under Test
    --------------------------------------------------

    dut : entity work.uart_rx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => BAUD_RATE
        )
        port map (
            clk           => clk,
            reset         => reset,
            rx_in         => rx_in,
            data_out      => data_out,
            rx_busy       => rx_busy,
            done          => done,
            framing_error => framing_error
        );


    --------------------------------------------------
    -- Clock generator
    --------------------------------------------------

    clk <= not clk after CLK_PERIOD / 2;


    --------------------------------------------------
    -- Simulation watchdog
    --------------------------------------------------

    watchdog : process
    begin

        wait for 5 ms;

        assert false
            report "Simulation timeout"
            severity failure;

        wait;

    end process watchdog;


    --------------------------------------------------
    -- Reception monitor
    --------------------------------------------------

    monitor : process

        variable previous_done  : std_logic := '0';
        variable previous_error : std_logic := '0';

        variable previous_data :
            std_logic_vector(7 downto 0)
            := (others => '0');

    begin

        wait until rising_edge(clk);
        wait for 1 ns;

        if reset = '0' then

            received_count <= 0;
            error_count    <= 0;

            previous_done  := '0';
            previous_error := '0';
            previous_data  := (others => '0');

        else

            ------------------------------------------
            -- DONE pulse duration
            ------------------------------------------

            assert not (
                done = '1' and previous_done = '1'
            )
                report "DONE lasted more than one cycle"
                severity failure;


            ------------------------------------------
            -- Framing error pulse duration
            ------------------------------------------

            assert not (
                framing_error = '1'
                and previous_error = '1'
            )
                report "Framing error lasted more than one cycle"
                severity failure;


            ------------------------------------------
            -- Mutually exclusive completion signals
            ------------------------------------------

            assert not (
                done = '1' and framing_error = '1'
            )
                report "DONE and framing error asserted together"
                severity failure;


            ------------------------------------------
            -- Output register stability
            ------------------------------------------

            if done = '0' then

                assert data_out = previous_data
                    report "Output changed without valid reception"
                    severity failure;

            end if;


            ------------------------------------------
            -- Successful reception
            ------------------------------------------

            if done = '1' then

                assert data_out = expected_data
                    report "Incorrect received byte: expected 0x" &
                           to_hstring(expected_data) &
                           ", received 0x" &
                           to_hstring(data_out)
                    severity failure;

                assert rx_busy = '0'
                    report "BUSY must be cleared on DONE"
                    severity failure;

                received_count <= received_count + 1;

                report "Received valid byte 0x" &
                       to_hstring(data_out)
                    severity note;

            end if;


            ------------------------------------------
            -- Framing error detection
            ------------------------------------------

            if framing_error = '1' then

                error_count <= error_count + 1;

                report "Framing error detected"
                    severity note;

            end if;


            ------------------------------------------
            -- Store previous output values
            ------------------------------------------

            previous_done  := done;
            previous_error := framing_error;
            previous_data  := data_out;

        end if;

    end process monitor;


    --------------------------------------------------
    -- Stimulus process
    --------------------------------------------------

    stimulus : process

        --------------------------------------------------
        -- Wait for the next clock cycle
        --------------------------------------------------

        procedure next_cycle is
        begin

            wait until rising_edge(clk);

            -- Wait until the monitor has updated its counters.
            wait for 2 ns;

        end procedure;


        --------------------------------------------------
        -- Wait for multiple clock cycles
        --------------------------------------------------

        procedure wait_cycles (
            constant count : in natural
        ) is
        begin

            for cycle in 1 to count loop
                next_cycle;
            end loop;

        end procedure;


        --------------------------------------------------
        -- Verify idle outputs
        --------------------------------------------------

        procedure check_idle is
        begin

            assert rx_busy = '0'
                report "BUSY must be low in IDLE"
                severity failure;

            assert done = '0'
                report "DONE must be low in IDLE"
                severity failure;

            assert framing_error = '0'
                report "Framing error must be low in IDLE"
                severity failure;

        end procedure;


        --------------------------------------------------
        -- Verify reception and error counters
        --------------------------------------------------

        procedure check_counts (
            constant expected_received : in natural;
            constant expected_errors   : in natural
        ) is
        begin

            next_cycle;

            assert received_count = expected_received
                report "Incorrect received frame count"
                severity failure;

            assert error_count = expected_errors
                report "Incorrect framing error count"
                severity failure;

        end procedure;


        --------------------------------------------------
        -- Generate a UART frame
        --------------------------------------------------

        procedure send_frame (
            constant value : in std_logic_vector(7 downto 0);

            constant stop_value : in std_logic := '1';

            constant bit_duration : in time := BIT_PERIOD
        ) is
        begin

            -- START bit
            rx_in <= '0';

            wait for bit_duration;

            -- Eight data bits, LSB first
            for bit_number in 0 to 7 loop

                rx_in <= value(bit_number);

                wait for bit_duration;

            end loop;

            -- STOP bit
            rx_in <= stop_value;

            wait for bit_duration;

        end procedure;


        --------------------------------------------------
        -- Generate and verify a valid UART frame
        --------------------------------------------------

        procedure receive_valid_frame (
            constant value : in std_logic_vector(7 downto 0);

            constant bit_duration : in time := BIT_PERIOD
        ) is

            variable previous_received : natural;
            variable previous_errors   : natural;

        begin

            previous_received := received_count;
            previous_errors   := error_count;

            expected_data <= value;

            -- Start independently of the DUT clock phase.
            wait for 7 ns;

            send_frame(
                value        => value,
                stop_value   => '1',
                bit_duration => bit_duration
            );

            wait for BIT_PERIOD;

            check_counts(
                previous_received + 1,
                previous_errors
            );

            assert data_out = value
                report "Incorrect output register value"
                severity failure;

            check_idle;

        end procedure;


    begin

        --------------------------------------------------
        -- Initial reset
        --------------------------------------------------

        reset <= '0';
        rx_in <= '1';

        wait for 5 * CLK_PERIOD;

        check_idle;

        wait until falling_edge(clk);

        reset <= '1';

        next_cycle;


        --------------------------------------------------
        -- TC23: False start bit
        --------------------------------------------------

        report "TC23: False start bit";

        -- Generate a pulse shorter than half a UART bit.
        rx_in <= '0';

        wait for BIT_PERIOD / 4;

        rx_in <= '1';

        -- Allow the receiver to reject the false start.
        wait for FRAME_PERIOD;

        check_counts(0, 0);

        check_idle;

        assert data_out = x"00"
            report "False START modified the output register"
            severity failure;

        report "PASS: False start bit rejected"
            severity note;


        --------------------------------------------------
        -- Prepare a previously received valid byte
        --------------------------------------------------

        receive_valid_frame(x"A5");


        --------------------------------------------------
        -- TC24: Invalid stop bit
        --------------------------------------------------

        report "TC24: Invalid stop bit";

        -- Generate a frame with a low STOP bit.
        send_frame(
            value      => x"55",
            stop_value => '0'
        );

        check_counts(1, 1);

        report "PASS: Invalid stop bit detected"
            severity note;


        --------------------------------------------------
        -- TC25: Output preservation
        --------------------------------------------------

        report "TC25: Output preservation";

        assert data_out = x"A5"
            report "Invalid frame overwrote the previous valid byte"
            severity failure;

        assert received_count = 1
            report "Invalid frame was incorrectly accepted"
            severity failure;

        report "PASS: Previous valid byte preserved"
            severity note;


        --------------------------------------------------
        -- TC26: Serial line stuck low
        --------------------------------------------------

        report "TC26: Serial line stuck low";

        -- Keep the RX line low after the framing error.
        rx_in <= '0';

        wait for 3 * FRAME_PERIOD;

        check_counts(1, 1);

        assert rx_busy = '1'
            report "Receiver must wait for the line to return high"
            severity failure;

        assert data_out = x"A5"
            report "Stuck-low condition modified the output register"
            severity failure;

        report "PASS: No repeated reception while RX is low"
            severity note;


        --------------------------------------------------
        -- TC27: Recovery after framing error
        --------------------------------------------------

        report "TC27: Recovery after framing error";

        -- Release the serial line.
        rx_in <= '1';

        wait for BIT_PERIOD;

        next_cycle;

        check_idle;

        receive_valid_frame(x"3C");

        check_counts(2, 1);

        report "PASS: Receiver recovered after framing error"
            severity note;


        --------------------------------------------------
        -- TC28: Reset during reception
        --------------------------------------------------

        report "TC28: Reset during reception";

        -- START bit
        rx_in <= '0';

        wait for BIT_PERIOD;

        -- First data bit
        rx_in <= '1';

        wait for BIT_PERIOD;

        -- Second data bit
        rx_in <= '0';

        wait for BIT_PERIOD / 2;

        assert rx_busy = '1'
            report "Expected an active reception"
            severity failure;

        -- Assert reset independently of the clock edge.
        wait until falling_edge(clk);
        wait for 3 ns;

        reset <= '0';
        rx_in <= '1';

        wait for 1 ns;

        check_idle;

        assert data_out = x"00"
            report "Output register was not reset"
            severity failure;

        -- Keep reset active for several clock cycles.
        wait_cycles(5);

        wait until falling_edge(clk);

        reset <= '1';

        next_cycle;

        -- Ensure the interrupted frame does not resume.
        wait for FRAME_PERIOD;

        check_counts(0, 0);

        check_idle;

        -- Verify normal reception after reset.
        receive_valid_frame(x"81");

        check_counts(1, 0);

        report "PASS: Receiver reset and recovery successful"
            severity note;


        --------------------------------------------------
        -- TC29: Faster transmitter
        --------------------------------------------------

        report "TC29: Transmitter baud rate +2 percent";

        receive_valid_frame(
            value        => x"55",
            bit_duration => FAST_BIT_PERIOD
        );

        receive_valid_frame(
            value        => x"A6",
            bit_duration => FAST_BIT_PERIOD
        );

        check_counts(3, 0);

        report "PASS: Faster transmitter reception"
            severity note;


        --------------------------------------------------
        -- TC30: Slower transmitter
        --------------------------------------------------

        report "TC30: Transmitter baud rate -2 percent";

        receive_valid_frame(
            value        => x"AA",
            bit_duration => SLOW_BIT_PERIOD
        );

        receive_valid_frame(
            value        => x"3C",
            bit_duration => SLOW_BIT_PERIOD
        );

        check_counts(5, 0);

        report "PASS: Slower transmitter reception"
            severity note;


        --------------------------------------------------
        -- Final idle verification
        --------------------------------------------------

        wait for FRAME_PERIOD;

        check_idle;

        check_counts(5, 0);


        --------------------------------------------------
        -- End of simulation
        --------------------------------------------------

        report "All UART RX robustness tests passed!"
            severity note;

        finish;

        wait;

    end process stimulus;

end architecture uart_rx_robustness_tb_arch;