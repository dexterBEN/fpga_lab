library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library STD;
use STD.ENV.ALL;

entity uart_loopback_tb is
    generic (
        TX_BAUD_RATE : positive := 115_200;
        RX_BAUD_RATE : positive := 115_200
    );
end entity uart_loopback_tb;

architecture uart_loopback_tb_arch
    of uart_loopback_tb is

    --------------------------------------------------
    -- Testbench configuration
    --------------------------------------------------

    constant CLK_FREQ   : positive := 50_000_000;
    constant CLK_PERIOD : time := 20 ns;

    constant TX_CLKS_PER_BIT : positive :=
        CLK_FREQ / TX_BAUD_RATE;

    constant RX_CLKS_PER_BIT : positive :=
        CLK_FREQ / RX_BAUD_RATE;

    constant TX_BIT_PERIOD : time :=
        TX_CLKS_PER_BIT * CLK_PERIOD;

    constant RX_BIT_PERIOD : time :=
        RX_CLKS_PER_BIT * CLK_PERIOD;

    constant TX_FRAME_PERIOD : time :=
        10 * TX_BIT_PERIOD;

    constant RX_FRAME_PERIOD : time :=
        10 * RX_BIT_PERIOD;

    -- Return the longest duration.
    function max_time(a : time; b : time) return time is
    begin
        if a > b then
            return a;
        else
            return b;
        end if;
    end function max_time;

    constant MAX_FRAME_PERIOD : time :=
        max_time(TX_FRAME_PERIOD, RX_FRAME_PERIOD);

    constant MESSAGE : string := "Hello FPGA!";

    --------------------------------------------------
    -- Scoreboard configuration
    --------------------------------------------------

    constant SCOREBOARD_SIZE : positive := 1024;

    type byte_array is array (natural range <>) of
        std_logic_vector(7 downto 0);

    --------------------------------------------------
    -- Common signals
    --------------------------------------------------

    signal clk         : std_logic := '0';
    signal reset       : std_logic := '0';
    signal serial_line : std_logic;

    --------------------------------------------------
    -- UART TX signals
    --------------------------------------------------

    signal data_in : std_logic_vector(7 downto 0)
        := (others => '0');

    signal tx_start : std_logic := '0';
    signal tx_busy  : std_logic;
    signal tx_done  : std_logic;

    --------------------------------------------------
    -- UART RX signals
    --------------------------------------------------

    signal data_out      : std_logic_vector(7 downto 0);
    signal rx_busy       : std_logic;
    signal rx_done       : std_logic;
    signal framing_error : std_logic;

    --------------------------------------------------
    -- Verification signals
    --------------------------------------------------

    signal accepted_count    : natural := 0;
    signal transmitted_count : natural := 0;
    signal received_count    : natural := 0;

begin

    --------------------------------------------------
    -- UART transmitter
    --------------------------------------------------

    transmitter : entity work.uart_tx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => TX_BAUD_RATE
        )
        port map (
            clk      => clk,
            reset    => reset,
            data_in  => data_in,
            tx_start => tx_start,

            tx_out   => serial_line,
            tx_busy  => tx_busy,
            done     => tx_done
        );


    --------------------------------------------------
    -- UART receiver
    --------------------------------------------------

    receiver : entity work.uart_rx
        generic map (
            CLK_FREQ  => CLK_FREQ,
            BAUD_RATE => RX_BAUD_RATE
        )
        port map (
            clk           => clk,
            reset         => reset,
            rx_in         => serial_line,

            data_out      => data_out,
            rx_busy       => rx_busy,
            done          => rx_done,
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

        wait for 100 ms;

        assert false
            report "Simulation timeout"
            severity failure;

        wait;

    end process watchdog;


    --------------------------------------------------
    -- Monitor and scoreboard
    --------------------------------------------------

    monitor : process

        variable scoreboard :
            byte_array(0 to SCOREBOARD_SIZE - 1);

        variable write_index : natural := 0;
        variable read_index  : natural := 0;

        variable previous_tx_done : std_logic := '0';
        variable previous_rx_done : std_logic := '0';

        variable previous_data :
            std_logic_vector(7 downto 0)
            := (others => '0');

        variable request_accepted : boolean;
        variable accepted_data :
            std_logic_vector(7 downto 0);

    begin

        wait until rising_edge(clk);

        -- Capture the transmitter handshake before
        -- registered signals are updated.
        request_accepted :=
            reset = '1'
            and tx_start = '1'
            and tx_busy = '0';

        accepted_data := data_in;

        -- Allow DUT outputs to stabilize.
        wait for 1 ns;

        if reset = '0' then

            write_index := 0;
            read_index  := 0;

            accepted_count    <= 0;
            transmitted_count <= 0;
            received_count    <= 0;

            previous_tx_done := '0';
            previous_rx_done := '0';
            previous_data    := (others => '0');

        else

            ------------------------------------------
            -- Record accepted transmission requests
            ------------------------------------------

            if request_accepted then

                assert write_index < SCOREBOARD_SIZE
                    report "Scoreboard capacity exceeded"
                    severity failure;

                scoreboard(write_index) := accepted_data;

                write_index := write_index + 1;

                accepted_count <= accepted_count + 1;

                assert tx_busy = '1'
                    report "Accepted request did not start TX"
                    severity failure;

            end if;


            ------------------------------------------
            -- Framing error verification
            ------------------------------------------

            assert framing_error = '0'
                report "Unexpected UART framing error"
                severity failure;


            ------------------------------------------
            -- Completion pulse verification
            ------------------------------------------

            assert not (
                tx_done = '1'
                and previous_tx_done = '1'
            )
                report "TX DONE lasted more than one cycle"
                severity failure;

            assert not (
                rx_done = '1'
                and previous_rx_done = '1'
            )
                report "RX DONE lasted more than one cycle"
                severity failure;


            ------------------------------------------
            -- Transmitter completion
            ------------------------------------------

            if tx_done = '1' then

                assert tx_busy = '0'
                    report "TX BUSY must be low on TX DONE"
                    severity failure;

                assert transmitted_count < write_index
                    report "Unexpected TX completion"
                    severity failure;

                transmitted_count <= transmitted_count + 1;

            end if;


            ------------------------------------------
            -- Receiver completion
            ------------------------------------------

            if rx_done = '1' then

                assert rx_busy = '0'
                    report "RX BUSY must be low on RX DONE"
                    severity failure;

                assert read_index < write_index
                    report "Unexpected received byte"
                    severity failure;

                assert data_out = scoreboard(read_index)
                    report "Data mismatch at index " &
                           integer'image(read_index) &
                           ": expected 0x" &
                           to_hstring(scoreboard(read_index)) &
                           ", received 0x" &
                           to_hstring(data_out)
                    severity failure;

                read_index := read_index + 1;

                received_count <= received_count + 1;

            end if;


            ------------------------------------------
            -- Output register stability
            ------------------------------------------

            if rx_done = '0' then

                assert data_out = previous_data
                    report "RX output changed without DONE"
                    severity failure;

            end if;


            ------------------------------------------
            -- Store previous signal values
            ------------------------------------------

            previous_tx_done := tx_done;
            previous_rx_done := rx_done;
            previous_data    := data_out;

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

            -- Allow monitor counters to update.
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

            assert serial_line = '1'
                report "Serial line must be high in IDLE"
                severity failure;

            assert tx_busy = '0'
                report "TX must be idle"
                severity failure;

            assert rx_busy = '0'
                report "RX must be idle"
                severity failure;

            assert tx_done = '0'
                report "TX DONE must be low"
                severity failure;

            assert rx_done = '0'
                report "RX DONE must be low"
                severity failure;

            assert framing_error = '0'
                report "Framing error must be low"
                severity failure;

        end procedure;


        --------------------------------------------------
        -- Verify communication counters
        --------------------------------------------------

        procedure check_counts (
            constant expected_accepted    : in natural;
            constant expected_transmitted : in natural;
            constant expected_received    : in natural
        ) is
        begin

            assert accepted_count = expected_accepted
                report "Incorrect accepted byte count"
                severity failure;

            assert transmitted_count = expected_transmitted
                report "Incorrect transmitted byte count"
                severity failure;

            assert received_count = expected_received
                report "Incorrect received byte count"
                severity failure;

        end procedure;


        --------------------------------------------------
        -- Submit one byte to the transmitter
        --------------------------------------------------

        procedure transmit_byte (
            constant value : in std_logic_vector(7 downto 0)
        ) is
        begin

            -- Wait until TX can accept another byte.
            -- No additional inter-frame delay is inserted.
            loop

                wait until falling_edge(clk);

                exit when tx_busy = '0';

            end loop;

            data_in  <= value;
            tx_start <= '1';

            next_cycle;

            tx_start <= '0';

            assert tx_busy = '1'
                report "Transmission did not start"
                severity failure;

        end procedure;


        --------------------------------------------------
        -- Wait until all submitted bytes are processed
        --------------------------------------------------

        procedure wait_for_completion (
            constant expected_count : in natural
        ) is
        begin

            -- Allow enough time for the final frame.
            for cycle in 1 to
                (2 * MAX_FRAME_PERIOD / CLK_PERIOD)
            loop

                if transmitted_count = expected_count
                    and received_count = expected_count
                then
                    exit;
                end if;

                next_cycle;

            end loop;

            check_counts(
                expected_count,
                expected_count,
                expected_count
            );

            -- Allow completion pulses to clear.
            next_cycle;

            check_idle;

        end procedure;


        --------------------------------------------------
        -- Apply a common asynchronous reset
        --------------------------------------------------

        procedure reset_system is
        begin

            tx_start <= '0';

            -- Assert reset between clock edges.
            wait until falling_edge(clk);
            wait for 3 ns;

            reset <= '0';

            wait for 1 ns;

            check_idle;

            assert data_out = x"00"
                report "RX output was not reset"
                severity failure;

            wait_cycles(5);

            check_counts(0, 0, 0);

            wait until falling_edge(clk);

            reset <= '1';

            next_cycle;

            check_idle;

        end procedure;


    begin

        --------------------------------------------------
        -- Display configuration
        --------------------------------------------------

        report "UART loopback testbench";

        report "TX baud rate: " &
               integer'image(TX_BAUD_RATE);

        report "RX baud rate: " &
               integer'image(RX_BAUD_RATE);


        --------------------------------------------------
        -- TC31: System reset
        --------------------------------------------------

        report "TC31: System reset";

        reset_system;

        report "PASS: TX and RX reset successfully"
            severity note;


        --------------------------------------------------
        -- TC32: Single byte loopback
        --------------------------------------------------

        report "TC32: Single byte loopback";

        transmit_byte(x"A6");

        wait_for_completion(1);

        assert data_out = x"A6"
            report "Single byte loopback failed"
            severity failure;

        report "PASS: Single byte loopback"
            severity note;


        --------------------------------------------------
        -- TC33: Exhaustive byte transmission
        --------------------------------------------------

        report "TC33: Exhaustive byte transmission";

        for value in 0 to 255 loop

            transmit_byte(
                std_logic_vector(
                    to_unsigned(value, 8)
                )
            );

        end loop;

        wait_for_completion(257);

        assert data_out = x"FF"
            report "Incorrect final exhaustive test byte"
            severity failure;

        report "PASS: All 256 byte values received correctly"
            severity note;


        --------------------------------------------------
        -- TC34: Back-to-back transmission
        --------------------------------------------------

        report "TC34: Back-to-back transmission";

        transmit_byte(x"00");
        transmit_byte(x"FF");
        transmit_byte(x"55");
        transmit_byte(x"AA");

        wait_for_completion(261);

        report "PASS: Back-to-back transmission"
            severity note;


        --------------------------------------------------
        -- TC35: Data sequence integrity
        --------------------------------------------------

        report "TC35: Data sequence integrity";

        for index in MESSAGE'range loop

            transmit_byte(
                std_logic_vector(
                    to_unsigned(
                        character'pos(MESSAGE(index)),
                        8
                    )
                )
            );

        end loop;

        wait_for_completion(
            261 + MESSAGE'length
        );

        report "PASS: Message received in correct order: " &
               MESSAGE
            severity note;


        --------------------------------------------------
        -- TC36: Completion synchronization
        --------------------------------------------------

        report "TC36: Completion synchronization";

        -- Ensure that no delayed or duplicated events
        -- appear after the final transmission.
        wait for 2 * MAX_FRAME_PERIOD;

        next_cycle;

        check_counts(
            261 + MESSAGE'length,
            261 + MESSAGE'length,
            261 + MESSAGE'length
        );

        check_idle;

        report "PASS: TX and RX completion counts match"
            severity note;


        --------------------------------------------------
        -- TC37: Reset during communication
        --------------------------------------------------

        report "TC37: Reset during communication";

        transmit_byte(x"00");

        -- Interrupt the communication during DATA.
        wait_cycles(3 * TX_CLKS_PER_BIT);

        assert tx_busy = '1'
            report "Expected active transmitter"
            severity failure;

        assert rx_busy = '1'
            report "Expected active receiver"
            severity failure;

        reset_system;

        -- Ensure the interrupted frame does not resume.
        wait for 2 * MAX_FRAME_PERIOD;

        next_cycle;

        check_counts(0, 0, 0);

        check_idle;

        report "PASS: Reset interrupted TX and RX"
            severity note;


        --------------------------------------------------
        -- TC38: Recovery after reset
        --------------------------------------------------

        report "TC38: Recovery after reset";

        transmit_byte(x"81");

        wait_for_completion(1);

        transmit_byte(x"3C");

        wait_for_completion(2);

        assert data_out = x"3C"
            report "Incorrect byte after reset"
            severity failure;

        report "PASS: Communication recovered after reset"
            severity note;


        --------------------------------------------------
        -- TC39: Baud rate configuration
        --------------------------------------------------

        if TX_BAUD_RATE /= RX_BAUD_RATE then

            report "TC39: Baud rate mismatch";

            report "PASS: Loopback tests completed " &
                   "with different TX and RX baud rates"
                severity note;

        else

            report "TC39: Skipped in nominal configuration"
                severity note;

        end if;


        --------------------------------------------------
        -- End of simulation
        --------------------------------------------------

        report "All UART loopback tests passed!"
            severity note;

        finish;

        wait;

    end process stimulus;

end architecture uart_loopback_tb_arch;