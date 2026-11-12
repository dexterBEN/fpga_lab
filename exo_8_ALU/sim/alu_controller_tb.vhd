
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_controller_tb is
end entity alu_controller_tb;

architecture tb of alu_controller_tb is

    constant CLK_PERIOD : time := 20 ns;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal start   : std_logic := '0';
    signal ack     : std_logic := '0';
    signal command : std_logic_vector(31 downto 0) :=
        (others => '0');

    signal response : std_logic_vector(31 downto 0);
    signal busy     : std_logic;
    signal done     : std_logic;

    function make_command(
        a_value : natural;
        b_value : natural;
        opcode  : natural
    ) return std_logic_vector is

        variable word_value :
            std_logic_vector(31 downto 0) :=
                (others => '0');
    begin
        word_value(7 downto 0) :=
            std_logic_vector(to_unsigned(a_value, 8));

        word_value(15 downto 8) :=
            std_logic_vector(to_unsigned(b_value, 8));

        word_value(18 downto 16) :=
            std_logic_vector(to_unsigned(opcode, 3));

        return word_value;
    end function;

    function make_response(
        result_value : natural;
        c, b, z, v  : std_logic
    ) return std_logic_vector is

        variable word_value :
            std_logic_vector(31 downto 0) :=
                (others => '0');
    begin
        word_value(7 downto 0) :=
            std_logic_vector(to_unsigned(result_value, 8));

        word_value(8)  := c;
        word_value(9)  := b;
        word_value(10) := z;
        word_value(11) := v;

        return word_value;
    end function;

begin

    clk <= not clk after CLK_PERIOD / 2;

    dut : entity work.alu_controller
        port map (
            clk      => clk,
            reset    => reset,
            start    => start,
            ack      => ack,
            command  => command,
            response => response,
            busy     => busy,
            done     => done
        );

    stimulus : process

        variable tests_run : natural := 0;

        procedure check_case(
            constant test_name     : in string;
            constant input_a       : in natural;
            constant input_b       : in natural;
            constant opcode        : in natural;
            constant exp_value     : in natural;
            constant exp_carry     : in std_logic;
            constant exp_borrow    : in std_logic;
            constant exp_zero      : in std_logic;
            constant exp_overflow  : in std_logic;
            constant inject_busy   : in boolean := false
        ) is

            variable expected_response :
                std_logic_vector(31 downto 0);

            variable previous_response :
                std_logic_vector(31 downto 0);

        begin

            expected_response := make_response(
                exp_value,
                exp_carry,
                exp_borrow,
                exp_zero,
                exp_overflow
            );

            previous_response := response;

            -- Submit command.
            wait until falling_edge(clk);

            command <= make_command(
                input_a, input_b, opcode
            );
            start <= '1';
            ack <= '0';

            -- Edge 1: command accepted.
            wait until rising_edge(clk);
            wait for 1 ns;

            assert busy = '1' and done = '0'
                report "FAIL " & test_name &
                       ": command not accepted"
                severity failure;

            assert response = previous_response
                report "FAIL " & test_name &
                       ": response changed early"
                severity failure;

            -- Optionally inject a different command
            -- while the controller is busy.
            wait until falling_edge(clk);

            if inject_busy then
                command <= make_command(100, 20, 0);
                start <= '1';
            else
                start <= '0';
            end if;

            -- Edge 2: wrapper captures inputs.
            wait until rising_edge(clk);
            wait for 1 ns;

            assert busy = '1' and done = '0'
                report "FAIL " & test_name &
                       ": premature completion at edge 2"
                severity failure;

            assert response = previous_response
                report "FAIL " & test_name &
                       ": response changed at edge 2"
                severity failure;

            wait until falling_edge(clk);
            start <= '0';

            -- Edge 3: wrapper captures result.
            wait until rising_edge(clk);
            wait for 1 ns;

            assert busy = '1' and done = '0'
                report "FAIL " & test_name &
                       ": premature completion at edge 3"
                severity failure;

            assert response = previous_response
                report "FAIL " & test_name &
                       ": response changed at edge 3"
                severity failure;

            -- Edge 4: controller publishes result.
            wait until rising_edge(clk);
            wait for 1 ns;

            assert busy = '0' and done = '1'
                report "FAIL " & test_name &
                       ": completion status"
                severity failure;

            assert response = expected_response
                report "FAIL " & test_name &
                       ": expected " &
                       to_hstring(expected_response) &
                       ", got " &
                       to_hstring(response)
                severity failure;

            -- DONE must remain asserted without ACK.
            for i in 1 to 3 loop
                wait until rising_edge(clk);
                wait for 1 ns;

                assert done = '1' and busy = '0'
                    report "FAIL " & test_name &
                           ": done not persistent"
                    severity failure;

                assert response = expected_response
                    report "FAIL " & test_name &
                           ": response not retained"
                    severity failure;
            end loop;

            -- Acknowledge completion.
            wait until falling_edge(clk);
            ack <= '1';

            wait until rising_edge(clk);
            wait for 1 ns;

            assert done = '0' and busy = '0'
                report "FAIL " & test_name &
                       ": ACK not accepted"
                severity failure;

            assert response = expected_response
                report "FAIL " & test_name &
                       ": ACK cleared response"
                severity failure;

            wait until falling_edge(clk);
            ack <= '0';

            tests_run := tests_run + 1;
            report "PASS: " & test_name severity note;

        end procedure;

    begin

        -- Initial synchronous reset.
        wait until rising_edge(clk);
        wait for 1 ns;

        assert response = x"00000000"
            report "FAIL initial reset response"
            severity failure;

        assert busy = '0' and done = '0'
            report "FAIL initial reset status"
            severity failure;

        wait until falling_edge(clk);
        reset <= '0';

        -- Existing arithmetic and logic tests.
        check_case(
            "ADD 3 + 2",
            3, 2, 0, 5,
            '0', '0', '0', '0'
        );

        check_case(
            "ADD carry",
            255, 1, 0, 0,
            '1', '0', '1', '0'
        );

        check_case(
            "ADD signed overflow",
            127, 1, 0, 128,
            '0', '0', '0', '1'
        );

        check_case(
            "SUB borrow",
            3, 5, 3, 254,
            '0', '1', '0', '0'
        );

        check_case(
            "SUB signed overflow",
            128, 1, 3, 127,
            '0', '0', '0', '1'
        );

        check_case(
            "SUB zero",
            5, 5, 3, 0,
            '0', '0', '1', '0'
        );

        check_case(
            "AND",
            10, 12, 1, 8,
            '0', '0', '0', '0'
        );

        check_case(
            "OR",
            10, 12, 2, 14,
            '0', '0', '0', '0'
        );

        check_case(
            "Unsupported operation",
            10, 5, 7, 0,
            '0', '0', '1', '0'
        );

        -- Test 10: start while busy must be ignored.
        check_case(
            "Ignore START during BUSY",
            7, 8, 0, 15,
            '0', '0', '0', '0',
            true
        );

        -- Test 11: synchronous reset during transaction.
        wait until falling_edge(clk);
        command <= make_command(100, 20, 0);
        start <= '1';

        -- Command is accepted.
        wait until rising_edge(clk);
        wait for 1 ns;

        assert busy = '1' and done = '0'
            report "FAIL: reset test did not start"
            severity failure;

        wait until falling_edge(clk);
        start <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert busy = '1'
            report "FAIL: transaction ended too early"
            severity failure;

        -- Assert reset between two clock edges.
        wait until falling_edge(clk);
        reset <= '1';

        wait for 1 ns;

        assert busy = '1' and done = '0'
            report "FAIL: reset acted asynchronously"
            severity failure;

        -- Reset becomes effective at next rising edge.
        wait until rising_edge(clk);
        wait for 1 ns;

        assert busy = '0' and done = '0'
            report "FAIL: reset did not stop transaction"
            severity failure;

        assert response = x"00000000"
            report "FAIL: reset did not clear response"
            severity failure;

        report "PASS: Reset during transaction"
            severity note;

        tests_run := tests_run + 1;

        wait until falling_edge(clk);
        reset <= '0';

        -- Check that the controller works after reset.
        check_case(
            "Recovery after reset",
            9, 6, 0, 15,
            '0', '0', '0', '0'
        );

        report "All " & integer'image(tests_run) &
               " controller scenarios passed."
            severity note;

        wait;

    end process;

end architecture tb;
