library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library STD;
use STD.ENV.ALL;

entity uart_rx_tb is
end entity uart_rx_tb;

architecture uart_rx_tb_arch of uart_rx_tb is

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

    --------------------------------------------------
    -- Expected reception sequence
    --------------------------------------------------

    type byte_array is array (natural range <>) of
        std_logic_vector(7 downto 0);

    constant TEST_DATA : byte_array := (
        x"41",
        x"00",
        x"FF",
        x"55",
        x"AA",
        x"A6",
        x"3C",
        x"81"
    );

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
    -- Reception monitor
    --------------------------------------------------

    monitor : process

        variable previous_done : std_logic := '0';
        variable previous_busy : std_logic := '0';

        variable previous_data :
            std_logic_vector(7 downto 0)
            := (others => '0');

    begin

        wait until rising_edge(clk);

        -- Allow registered and combinational signals
        -- to stabilize after the clock edge.
        wait for 1 ns;

        if reset = '0' then

            received_count <= 0;

            previous_done := '0';
            previous_busy := '0';
            previous_data := (others => '0');

        else

            ------------------------------------------
            -- No framing error on valid frames
            ------------------------------------------

            assert framing_error = '0'
                report "Unexpected framing error"
                severity failure;

            ------------------------------------------
            -- DONE must be a single-cycle pulse
            ------------------------------------------

            assert not (
                done = '1' and previous_done = '1'
            )
                report "DONE lasted more than one cycle"
                severity failure;

            ------------------------------------------
            -- Output data must remain stable
            ------------------------------------------

            if done = '0' then

                assert data_out = previous_data
                    report "Output changed without DONE"
                    severity failure;

            end if;

            ------------------------------------------
            -- Reception completion
            ------------------------------------------

            if done = '1' then

                assert previous_busy = '1'
                    report "DONE without active reception"
                    severity failure;

                assert rx_busy = '0'
                    report "BUSY must be cleared on DONE"
                    severity failure;

                assert received_count < TEST_DATA'length
                    report "Unexpected additional byte"
                    severity failure;

                assert data_out =
                    TEST_DATA(received_count)
                    report "Incorrect received byte: " &
                           "expected 0x" &
                           to_hstring(
                               TEST_DATA(received_count)
                           ) &
                           ", received 0x" &
                           to_hstring(data_out)
                    severity failure;

                report "PASS: Received byte 0x" &
                       to_hstring(data_out)
                    severity note;

                received_count <= received_count + 1;

            end if;

            ------------------------------------------
            -- Store previous output values
            ------------------------------------------

            previous_done := done;
            previous_busy := rx_busy;
            previous_data := data_out;

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
            wait for 1 ns;

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
        -- Generate a complete UART frame
        --------------------------------------------------

        procedure send_frame (
            constant value : in std_logic_vector(7 downto 0)
        ) is
        begin

            ------------------------------------------
            -- START bit
            ------------------------------------------

            rx_in <= '0';

            wait for BIT_PERIOD / 2;

            assert rx_busy = '1'
                report "Receiver did not detect START"
                severity failure;

            wait for BIT_PERIOD / 2;

            ------------------------------------------
            -- Eight data bits, LSB first
            ------------------------------------------

            for bit_number in 0 to 7 loop

                rx_in <= value(bit_number);

                wait for BIT_PERIOD / 2;

                assert rx_busy = '1'
                    report "BUSY cleared during DATA"
                    severity failure;

                wait for BIT_PERIOD / 2;

            end loop;

            ------------------------------------------
            -- STOP bit
            ------------------------------------------

            rx_in <= '1';

            wait for BIT_PERIOD;

        end procedure;


        --------------------------------------------------
        -- Verify that a frame has been received
        --------------------------------------------------

        procedure check_received (
            constant expected_count : in natural;
            constant expected_data  :
                in std_logic_vector(7 downto 0)
        ) is
        begin

            next_cycle;

            assert received_count = expected_count
                report "Incorrect received frame count"
                severity failure;

            assert data_out = expected_data
                report "Incorrect output register value"
                severity failure;

            check_idle;

        end procedure;


    begin

        --------------------------------------------------
        -- TC13: Reset verification
        --------------------------------------------------

        report "TC13: Reset verification";

        reset <= '0';
        rx_in <= '1';

        wait for 5 * CLK_PERIOD;

        check_idle;

        assert data_out = x"00"
            report "Output register was not reset"
            severity failure;

        wait until falling_edge(clk);

        reset <= '1';

        next_cycle;

        report "PASS: Reset";


        --------------------------------------------------
        -- TC14: Idle state verification
        --------------------------------------------------

        report "TC14: Idle state verification";

        for cycle in 1 to CLKS_PER_BIT loop

            next_cycle;

            check_idle;

        end loop;

        assert received_count = 0
            report "Unexpected reception during IDLE"
            severity failure;

        report "PASS: Idle state";


        --------------------------------------------------
        -- TC15-TC20: Functional reception tests
        --------------------------------------------------

        report "TC15-TC20: UART frame reception";

        -- Start independently of the DUT clock phase.
        wait for 7 ns;

        for index in 0 to 4 loop

            send_frame(TEST_DATA(index));

            check_received(
                index + 1,
                TEST_DATA(index)
            );

            -- Additional idle period between frames.
            wait for BIT_PERIOD;

        end loop;

        report "PASS: Functional reception tests";


        --------------------------------------------------
        -- TC21: Multiple successive frames
        --------------------------------------------------

        report "TC21: Multiple successive frames";

        send_frame(TEST_DATA(5));

        check_received(
            6,
            TEST_DATA(5)
        );

        report "PASS: Successive frame reception";


        --------------------------------------------------
        -- TC22: Back-to-back frames
        --------------------------------------------------

        report "TC22: Back-to-back frames";

        -- No additional idle period between frames.
        send_frame(TEST_DATA(6));
        send_frame(TEST_DATA(7));

        check_received(
            8,
            TEST_DATA(7)
        );

        report "PASS: Back-to-back frame reception";


        --------------------------------------------------
        -- Final idle verification
        --------------------------------------------------

        for cycle in 1 to CLKS_PER_BIT loop

            next_cycle;

            check_idle;

        end loop;

        assert received_count = TEST_DATA'length
            report "Incorrect total number of received bytes"
            severity failure;


        --------------------------------------------------
        -- End of simulation
        --------------------------------------------------

        report "All UART RX tests passed!"
            severity note;

        finish;

        wait;

    end process stimulus;

end architecture uart_rx_tb_arch;