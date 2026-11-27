library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library STD;
use STD.ENV.ALL;

entity uart_gpio_bridge_tb is
end entity uart_gpio_bridge_tb;

architecture uart_gpio_bridge_tb_arch
    of uart_gpio_bridge_tb is

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

    constant TIMEOUT_CYCLES : positive :=
        2 * 10 * CLKS_PER_BIT;

    --------------------------------------------------
    -- Command register bit mapping
    --------------------------------------------------

    constant CMD_REQUEST_BIT : natural := 8;

    --------------------------------------------------
    -- Status register bit mapping
    --------------------------------------------------

    constant STATUS_ACK_BIT     : natural := 8;
    constant STATUS_ACTIVE_BIT  : natural := 9;
    constant STATUS_TX_BUSY_BIT : natural := 10;
    constant STATUS_RX_BUSY_BIT : natural := 11;
    constant STATUS_TX_DONE_BIT : natural := 12;
    constant STATUS_RX_DONE_BIT : natural := 13;
    constant STATUS_ERROR_BIT   : natural := 14;

    --------------------------------------------------
    -- DUT signals
    --------------------------------------------------

    signal clk   : std_logic := '0';
    signal reset : std_logic := '0';

    signal command_in : std_logic_vector(31 downto 0)
        := (others => '0');

    signal status_out : std_logic_vector(31 downto 0);

    --------------------------------------------------
    -- Decoded status signals
    --------------------------------------------------

    signal rx_data : std_logic_vector(7 downto 0);

    signal tx_ack : std_logic;
    signal active : std_logic;

    signal tx_busy : std_logic;
    signal rx_busy : std_logic;

    signal tx_done : std_logic;
    signal rx_done : std_logic;

    signal framing_error : std_logic;

    --------------------------------------------------
    -- Verification signals
    --------------------------------------------------

    signal accepted_count  : natural := 0;
    signal completed_count : natural := 0;

begin

    --------------------------------------------------
    -- Device Under Test
    --------------------------------------------------

    dut : entity work.uart_gpio_bridge
        generic map (
            CLK_FREQ     => CLK_FREQ,
            TX_BAUD_RATE => BAUD_RATE,
            RX_BAUD_RATE => BAUD_RATE
        )
        port map (
            clk        => clk,
            reset      => reset,
            command_in => command_in,
            status_out => status_out
        );


    --------------------------------------------------
    -- Clock generator
    --------------------------------------------------

    clk <= not clk after CLK_PERIOD / 2;


    --------------------------------------------------
    -- Status register decoding
    --------------------------------------------------

    rx_data <= status_out(7 downto 0);

    tx_ack <= status_out(STATUS_ACK_BIT);

    active <= status_out(STATUS_ACTIVE_BIT);

    tx_busy <= status_out(STATUS_TX_BUSY_BIT);
    rx_busy <= status_out(STATUS_RX_BUSY_BIT);

    tx_done <= status_out(STATUS_TX_DONE_BIT);
    rx_done <= status_out(STATUS_RX_DONE_BIT);

    framing_error <= status_out(STATUS_ERROR_BIT);


    --------------------------------------------------
    -- Simulation watchdog
    --------------------------------------------------

    watchdog : process
    begin

        wait for 10 ms;

        assert false
            report "Simulation timeout"
            severity failure;

        wait;

    end process watchdog;


    --------------------------------------------------
    -- Transaction monitor
    --------------------------------------------------

    monitor : process

        variable previous_active : std_logic := '0';
        variable previous_ack    : std_logic := '0';

        variable previous_tx_done : std_logic := '0';
        variable previous_rx_done : std_logic := '0';

        variable previous_rx_data :
            std_logic_vector(7 downto 0)
            := (others => '0');

    begin

        wait until rising_edge(clk);

        -- Allow DUT outputs and decoded status signals
        -- to stabilize.
        wait for 1 ns;

        if reset = '0' then

            accepted_count  <= 0;
            completed_count <= 0;

            previous_active := '0';
            previous_ack    := '0';

            previous_tx_done := '0';
            previous_rx_done := '0';

            previous_rx_data := (others => '0');

        else

            ------------------------------------------
            -- Reserved status bits
            ------------------------------------------

            assert status_out(31 downto 15) =
                (31 downto 15 => '0')
                report "Reserved status bits must be zero"
                severity failure;


            ------------------------------------------
            -- No framing error during valid loopback
            ------------------------------------------

            assert framing_error = '0'
                report "Unexpected UART framing error"
                severity failure;


            ------------------------------------------
            -- Transaction acceptance detection
            ------------------------------------------

            if active = '1'
                and previous_active = '0'
            then

                accepted_count <= accepted_count + 1;

                assert tx_ack /= previous_ack
                    report "Transaction started without ACK toggle"
                    severity failure;

                assert tx_ack =
                    command_in(CMD_REQUEST_BIT)
                    report "ACK does not match REQUEST"
                    severity failure;

                assert tx_done = '0'
                    report "TX DONE was not cleared"
                    severity failure;

                assert rx_done = '0'
                    report "RX DONE was not cleared"
                    severity failure;

            end if;


            ------------------------------------------
            -- ACK must only change on acceptance
            ------------------------------------------

            if tx_ack /= previous_ack then

                assert active = '1'
                    and previous_active = '0'
                    report "Unexpected ACK change"
                    severity failure;

            end if;


            ------------------------------------------
            -- Transaction completion detection
            ------------------------------------------

            if active = '0'
                and previous_active = '1'
            then

                completed_count <= completed_count + 1;

                assert tx_done = '1'
                    report "Transaction completed before TX DONE"
                    severity failure;

                assert rx_done = '1'
                    report "Transaction completed before RX DONE"
                    severity failure;

                assert tx_busy = '0'
                    report "TX still busy at completion"
                    severity failure;

                assert rx_busy = '0'
                    report "RX still busy at completion"
                    severity failure;

            end if;


            ------------------------------------------
            -- Sticky flag verification
            ------------------------------------------

            -- Completion flags may only be cleared
            -- when a new transaction is accepted.

            if not (
                active = '1'
                and previous_active = '0'
            ) then

                if previous_tx_done = '1' then

                    assert tx_done = '1'
                        report "TX DONE flag cleared unexpectedly"
                        severity failure;

                end if;

                if previous_rx_done = '1' then

                    assert rx_done = '1'
                        report "RX DONE flag cleared unexpectedly"
                        severity failure;

                end if;

            end if;


            ------------------------------------------
            -- Received data stability
            ------------------------------------------

            if rx_data /= previous_rx_data then

                assert rx_done = '1'
                    and previous_rx_done = '0'
                    report "RX data changed without new reception"
                    severity failure;

            end if;


            ------------------------------------------
            -- Store previous status values
            ------------------------------------------

            previous_active := active;
            previous_ack    := tx_ack;

            previous_tx_done := tx_done;
            previous_rx_done := rx_done;

            previous_rx_data := rx_data;

        end if;

    end process monitor;


    --------------------------------------------------
    -- Stimulus process
    --------------------------------------------------

    stimulus : process

        variable request_toggle : std_logic := '0';

        --------------------------------------------------
        -- Wait for the next clock cycle
        --------------------------------------------------

        procedure next_cycle is
        begin

            wait until rising_edge(clk);

            -- Allow the monitor counters to update.
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
        -- Verify idle state
        --------------------------------------------------

        procedure check_idle is
        begin

            assert active = '0'
                report "Transaction must be inactive"
                severity failure;

            assert tx_busy = '0'
                report "TX must be idle"
                severity failure;

            assert rx_busy = '0'
                report "RX must be idle"
                severity failure;

            assert framing_error = '0'
                report "Unexpected framing error"
                severity failure;

        end procedure;


        --------------------------------------------------
        -- Verify transaction counters
        --------------------------------------------------

        procedure check_counts (
            constant expected_accepted  : in natural;
            constant expected_completed : in natural
        ) is
        begin

            assert accepted_count = expected_accepted
                report "Incorrect accepted transaction count"
                severity failure;

            assert completed_count = expected_completed
                report "Incorrect completed transaction count"
                severity failure;

        end procedure;


        --------------------------------------------------
        -- Apply a system reset
        --------------------------------------------------

        procedure reset_system is
        begin

            -- Reset the software-side command register
            -- and synchronize the request toggle.

            wait until falling_edge(clk);
            wait for 3 ns;

            command_in <= (others => '0');

            request_toggle := '0';

            reset <= '0';

            wait for 1 ns;

            assert status_out = x"00000000"
                report "Status register was not reset"
                severity failure;

            wait_cycles(5);

            check_counts(0, 0);

            wait until falling_edge(clk);

            reset <= '1';

            next_cycle;

            check_idle;

            assert status_out = x"00000000"
                report "Unexpected status after reset"
                severity failure;

        end procedure;


        --------------------------------------------------
        -- Write a command register value
        --------------------------------------------------

        procedure write_command (
            constant value   : in std_logic_vector(7 downto 0);
            constant request : in std_logic
        ) is

            variable command_word :
                std_logic_vector(31 downto 0);

        begin

            command_word := (others => '0');

            command_word(7 downto 0) := value;

            command_word(CMD_REQUEST_BIT) := request;

            -- Simulate an atomic AXI GPIO register write.
            wait until falling_edge(clk);

            command_in <= command_word;

        end procedure;


        --------------------------------------------------
        -- Submit a new transmission request
        --------------------------------------------------

        procedure submit_request (
            constant value : in std_logic_vector(7 downto 0)
        ) is

            variable previous_count : natural;

        begin

            check_idle;

            previous_count := accepted_count;

            assert tx_ack = request_toggle
                report "REQUEST and ACK are not synchronized"
                severity failure;

            -- Toggle the request bit.
            request_toggle := not request_toggle;

            -- Write data and request in the same command.
            write_command(
                value   => value,
                request => request_toggle
            );

            ------------------------------------------
            -- Wait for acknowledgement
            ------------------------------------------

            for cycle in 1 to TIMEOUT_CYCLES loop

                next_cycle;

                exit when tx_ack = request_toggle;

            end loop;

            assert tx_ack = request_toggle
                report "Request acknowledgement timeout"
                severity failure;

            assert active = '1'
                report "Acknowledged request is not active"
                severity failure;

            assert accepted_count = previous_count + 1
                report "Request was not accepted exactly once"
                severity failure;

            assert tx_done = '0'
                report "Previous TX DONE flag was not cleared"
                severity failure;

            assert rx_done = '0'
                report "Previous RX DONE flag was not cleared"
                severity failure;

        end procedure;


        --------------------------------------------------
        -- Wait for transaction completion
        --------------------------------------------------

        procedure wait_for_completion (
            constant expected_data : in std_logic_vector(7 downto 0)
        ) is

            variable previous_count : natural;

        begin

            previous_count := completed_count;

            for cycle in 1 to TIMEOUT_CYCLES loop

                if active = '0'
                    and tx_done = '1'
                    and rx_done = '1'
                then

                    exit;

                end if;

                next_cycle;

            end loop;

            assert active = '0'
                report "Transaction completion timeout"
                severity failure;

            assert tx_done = '1'
                report "TX DONE was not recorded"
                severity failure;

            assert rx_done = '1'
                report "RX DONE was not recorded"
                severity failure;

            assert completed_count = previous_count + 1
                report "Incorrect completion count"
                severity failure;

            assert rx_data = expected_data
                report "Loopback data mismatch: expected 0x" &
                       to_hstring(expected_data) &
                       ", received 0x" &
                       to_hstring(rx_data)
                severity failure;

            check_idle;

        end procedure;


        --------------------------------------------------
        -- Execute a complete UART transaction
        --------------------------------------------------

        procedure transfer_byte (
            constant value : in std_logic_vector(7 downto 0)
        ) is
        begin

            submit_request(value);

            wait_for_completion(value);

            report "PASS: Transferred byte 0x" &
                   to_hstring(value)
                severity note;

        end procedure;


        --------------------------------------------------
        -- Verify the complete status register
        --------------------------------------------------

        procedure check_final_status (
            constant expected_data : in std_logic_vector(7 downto 0);
            constant expected_ack  : in std_logic
        ) is

            variable expected_status :
                std_logic_vector(31 downto 0);

        begin

            expected_status := (others => '0');

            expected_status(7 downto 0) :=
                expected_data;

            expected_status(STATUS_ACK_BIT) :=
                expected_ack;

            expected_status(STATUS_TX_DONE_BIT) := '1';
            expected_status(STATUS_RX_DONE_BIT) := '1';

            assert status_out = expected_status
                report "Incorrect status register: expected 0x" &
                       to_hstring(expected_status) &
                       ", received 0x" &
                       to_hstring(status_out)
                severity failure;

        end procedure;


    begin

        --------------------------------------------------
        -- TC40: Bridge reset
        --------------------------------------------------

        report "TC40: Bridge reset";

        reset_system;

        report "PASS: Bridge reset successfully"
            severity note;


        --------------------------------------------------
        -- TC41-TC42: Command decoding and toggle request
        --------------------------------------------------

        report "TC41-TC42: Command decoding and toggle request";

        -- Write data without toggling REQUEST.
        write_command(x"A6", '0');

        wait for 2 * BIT_PERIOD;

        next_cycle;

        check_counts(0, 0);

        check_idle;

        -- Submit the same data with a new request.
        submit_request(x"A6");

        assert command_in = x"000001A6"
            report "Incorrect command register value"
            severity failure;

        check_counts(1, 0);

        report "PASS: Request toggle detected"
            severity note;


        --------------------------------------------------
        -- TC44: Request acknowledgement
        --------------------------------------------------

        report "TC44: Request acknowledgement";

        assert tx_ack = '1'
            report "Incorrect request acknowledgement"
            severity failure;

        assert active = '1'
            report "Transaction must be active"
            severity failure;

        report "PASS: Request acknowledged"
            severity note;


        --------------------------------------------------
        -- TC45: Complete UART loopback
        --------------------------------------------------

        report "TC45: Complete UART loopback";

        wait_for_completion(x"A6");

        check_counts(1, 1);

        check_final_status(x"A6", '1');

        report "PASS: Byte 0xA6 received successfully"
            severity note;


        --------------------------------------------------
        -- TC43: No repeated transmission
        --------------------------------------------------

        report "TC43: No repeated transmission";

        -- Maintain REQUEST and DATA after completion.
        -- A level-sensitive implementation could
        -- incorrectly start another transmission.

        wait for 3 * FRAME_PERIOD;

        next_cycle;

        check_counts(1, 1);

        check_idle;

        report "PASS: Command accepted exactly once"
            severity note;


        --------------------------------------------------
        -- TC46: Sticky completion flags
        --------------------------------------------------

        report "TC46: Sticky completion flags";

        -- Simulate a slow software polling interval.
        wait for 1 ms;

        next_cycle;

        assert tx_done = '1'
            report "TX DONE flag was lost"
            severity failure;

        assert rx_done = '1'
            report "RX DONE flag was lost"
            severity failure;

        assert rx_data = x"A6"
            report "Received data was not preserved"
            severity failure;

        check_final_status(x"A6", '1');

        check_counts(1, 1);

        report "PASS: Completion flags and data preserved"
            severity note;


        --------------------------------------------------
        -- TC47: Unchanged request
        --------------------------------------------------

        report "TC47: Unchanged request";

        -- Change the data without toggling REQUEST.
        write_command(
            value   => x"55",
            request => request_toggle
        );

        wait for 2 * FRAME_PERIOD;

        next_cycle;

        check_counts(1, 1);

        check_idle;

        check_final_status(x"A6", '1');

        report "PASS: Data change without toggle ignored"
            severity note;


        --------------------------------------------------
        -- TC48: Successive toggle requests
        --------------------------------------------------

        report "TC48: Successive toggle requests";

        -- REQUEST: 1 -> 0
        transfer_byte(x"55");

        check_final_status(x"55", '0');

        -- REQUEST: 0 -> 1
        transfer_byte(x"AA");

        check_final_status(x"AA", '1');

        -- REQUEST: 1 -> 0
        transfer_byte(x"00");

        check_final_status(x"00", '0');

        -- REQUEST: 0 -> 1
        transfer_byte(x"FF");

        check_final_status(x"FF", '1');

        check_counts(5, 5);

        report "PASS: Successive toggle requests"
            severity note;


        --------------------------------------------------
        -- TC49: TX data latching
        --------------------------------------------------

        report "TC49: TX data latching";

        submit_request(x"3C");

        -- Wait until transmission is in progress.
        wait_cycles(2 * CLKS_PER_BIT);

        assert tx_busy = '1'
            report "Expected active transmitter"
            severity failure;

        assert rx_busy = '1'
            report "Expected active receiver"
            severity failure;

        -- Modify the command data during transmission
        -- without changing the request toggle.
        write_command(
            value   => x"FF",
            request => request_toggle
        );

        -- The originally accepted byte must be received.
        wait_for_completion(x"3C");

        check_final_status(x"3C", '0');

        check_counts(6, 6);

        report "PASS: Original TX data preserved"
            severity note;


        --------------------------------------------------
        -- TC50: Status register mapping
        --------------------------------------------------

        report "TC50: Status register mapping";

        -- REQUEST: 0 -> 1
        submit_request(x"81");

        -- Verify the acceptance status.
        assert status_out = x"0000033C"
            report "Incorrect status at request acceptance"
            severity failure;

        -- Wait until both UART modules are busy.
        wait_cycles(2 * CLKS_PER_BIT);

        assert active = '1'
            report "Transaction must still be active"
            severity failure;

        assert tx_busy = '1'
            report "TX BUSY bit is incorrect"
            severity failure;

        assert rx_busy = '1'
            report "RX BUSY bit is incorrect"
            severity failure;

        assert status_out = x"00000F3C"
            report "Incorrect status during transmission"
            severity failure;

        wait_for_completion(x"81");

        assert status_out = x"00003181"
            report "Incorrect final status register"
            severity failure;

        check_counts(7, 7);

        report "PASS: Status register mapping"
            severity note;


        --------------------------------------------------
        -- TC51: Reset during active transaction
        --------------------------------------------------

        report "TC51: Reset during active transaction";

        submit_request(x"00");

        -- Interrupt the transaction during DATA.
        wait_cycles(3 * CLKS_PER_BIT);

        assert active = '1'
            report "Expected active transaction"
            severity failure;

        assert tx_busy = '1'
            report "Expected active transmitter"
            severity failure;

        assert rx_busy = '1'
            report "Expected active receiver"
            severity failure;

        reset_system;

        -- Ensure the interrupted transaction
        -- does not resume.
        wait for 2 * FRAME_PERIOD;

        next_cycle;

        check_counts(0, 0);

        check_idle;

        assert status_out = x"00000000"
            report "Unexpected transaction after reset"
            severity failure;

        report "PASS: Active transaction interrupted"
            severity note;


        --------------------------------------------------
        -- TC52: Recovery after reset
        --------------------------------------------------

        report "TC52: Recovery after reset";

        transfer_byte(x"A5");

        check_final_status(x"A5", '1');

        transfer_byte(x"5A");

        check_final_status(x"5A", '0');

        check_counts(2, 2);

        report "PASS: Bridge recovered after reset"
            severity note;


        --------------------------------------------------
        -- Final idle verification
        --------------------------------------------------

        wait for 2 * FRAME_PERIOD;

        next_cycle;

        check_counts(2, 2);

        check_idle;

        check_final_status(x"5A", '0');


        --------------------------------------------------
        -- End of simulation
        --------------------------------------------------

        report "All UART GPIO bridge tests passed!"
            severity note;

        finish;

        wait;

    end process stimulus;

end architecture uart_gpio_bridge_tb_arch;