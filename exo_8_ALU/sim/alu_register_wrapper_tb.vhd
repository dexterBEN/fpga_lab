
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_register_wrapper_tb is
    generic (
        DATA_WIDTH : positive := 8
    );
end entity alu_register_wrapper_tb;

architecture tb of alu_register_wrapper_tb is

    constant CLK_PERIOD : time := 20 ns;
    constant MODULUS    : integer := 2 ** DATA_WIDTH;
    constant MAX_VALUE  : integer := MODULUS - 1;
    constant SIGN_BIT   : integer := MODULUS / 2;
    constant SIGNED_MAX : integer := SIGN_BIT - 1;

    signal clk   : std_logic := '0';
    signal reset : std_logic := '1';

    signal a  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal b  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal op : std_logic_vector(2 downto 0) := (others => '0');

    signal result   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal carry    : std_logic;
    signal borrow   : std_logic;
    signal zero     : std_logic;
    signal overflow : std_logic;

begin

    -- 50 MHz clock.
    clk <= not clk after CLK_PERIOD / 2;

    -- Device Under Test.
    dut : entity work.alu_register_wrapper
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            clk      => clk,
            reset    => reset,
            a        => a,
            b        => b,
            op       => op,
            result   => result,
            carry    => carry,
            borrow   => borrow,
            zero     => zero,
            overflow => overflow
        );

    stimulus : process

        variable tests_run : natural := 0;

        -- Previously registered output values.
        variable prev_result   : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
        variable prev_carry    : std_logic := '0';
        variable prev_borrow   : std_logic := '0';
        variable prev_zero     : std_logic := '0';
        variable prev_overflow : std_logic := '0';

        -- Check every registered output.
        procedure assert_outputs(
            constant test_name : in string;
            constant exp_result : in std_logic_vector(DATA_WIDTH-1 downto 0);
            constant exp_carry  : in std_logic;
            constant exp_borrow : in std_logic;
            constant exp_zero   : in std_logic;
            constant exp_overflow : in std_logic
        ) is
        begin
            assert result = exp_result
                report "FAIL " & test_name &
                       " RESULT: expected " & to_string(exp_result) &
                       ", got " & to_string(result)
                severity failure;

            assert carry = exp_carry
                report "FAIL " & test_name & " CARRY"
                severity failure;

            assert borrow = exp_borrow
                report "FAIL " & test_name & " BORROW"
                severity failure;

            assert zero = exp_zero
                report "FAIL " & test_name & " ZERO"
                severity failure;

            assert overflow = exp_overflow
                report "FAIL " & test_name & " OVERFLOW"
                severity failure;
        end procedure;

        -- Execute one operation and verify its pipeline latency.
        procedure check_case(
            constant test_name : in string;
            constant input_a   : in natural;
            constant input_b   : in natural;
            constant opcode    : in natural;
            constant exp_value : in natural;
            constant exp_carry : in std_logic;
            constant exp_borrow : in std_logic;
            constant exp_zero   : in std_logic;
            constant exp_overflow : in std_logic
        ) is
            variable exp_result :
                std_logic_vector(DATA_WIDTH-1 downto 0);
        begin

            exp_result :=
                std_logic_vector(to_unsigned(exp_value, DATA_WIDTH));

            -- Apply input values away from the active clock edge.
            wait until falling_edge(clk);

            a  <= std_logic_vector(to_unsigned(input_a, DATA_WIDTH));
            b  <= std_logic_vector(to_unsigned(input_b, DATA_WIDTH));
            op <= std_logic_vector(to_unsigned(opcode, 3));

            -- First rising edge: input registers capture the
            -- new operands, but output registers still contain
            -- the previous operation's result.
            wait until rising_edge(clk);
            wait for 1 ns;

            assert_outputs(
                test_name & " - first edge",
                prev_result, prev_carry, prev_borrow,
                prev_zero, prev_overflow
            );

            -- Second rising edge: output registers capture
            -- the result of the operation under test.
            wait until rising_edge(clk);
            wait for 1 ns;

            assert_outputs(
                test_name & " - second edge",
                exp_result, exp_carry, exp_borrow,
                exp_zero, exp_overflow
            );

            prev_result   := exp_result;
            prev_carry    := exp_carry;
            prev_borrow   := exp_borrow;
            prev_zero     := exp_zero;
            prev_overflow := exp_overflow;

            tests_run := tests_run + 1;

            report "PASS: " & test_name severity note;

        end procedure;

    begin

        assert DATA_WIDTH = 4 or DATA_WIDTH = 8
            report "Supported testbench widths: 4 and 8"
            severity failure;

        -- ============================================
        -- TEST 1 - Synchronous reset
        -- ============================================

        report "Testing synchronous reset..." severity note;

        wait until rising_edge(clk);
        wait for 1 ns;

        assert_outputs(
            "Initial reset",
            (DATA_WIDTH-1 downto 0 => '0'),
            '0', '0', '0', '0'
        );

        wait until falling_edge(clk);
        reset <= '0';

        -- After reset is released, ADD 0 + 0 is captured
        -- before the first test operation.
        prev_zero := '1';

        -- ============================================
        -- TEST 2 - ADD
        -- ============================================

        check_case(
            "ADD 3 + 2",
            3, 2, 0, 5,
            '0', '0', '0', '0'
        );

        check_case(
            "ADD carry MAX + 1",
            MAX_VALUE, 1, 0, 0,
            '1', '0', '1', '0'
        );

        check_case(
            "ADD signed overflow",
            SIGNED_MAX, 1, 0, SIGN_BIT,
            '0', '0', '0', '1'
        );

        -- ============================================
        -- TEST 3 - SUB
        -- ============================================

        check_case(
            "SUB 3 - 5",
            3, 5, 3, MODULUS - 2,
            '0', '1', '0', '0'
        );

        check_case(
            "SUB negative signed overflow",
            SIGN_BIT, 1, 3, SIGNED_MAX,
            '0', '0', '0', '1'
        );

        check_case(
            "SUB zero",
            5, 5, 3, 0,
            '0', '0', '1', '0'
        );

        -- ============================================
        -- TEST 4 - Logic operations
        -- ============================================

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

        -- ============================================
        -- TEST 5 - Unsupported operation
        -- ============================================

        check_case(
            "Unsupported operation",
            10, 5, 7, 0,
            '0', '0', '1', '0'
        );

        -- ============================================
        -- TEST 6 - Reset after normal activity
        -- ============================================

        wait until falling_edge(clk);
        reset <= '1';

        -- Synchronous reset must not alter the output
        -- before the next rising edge.
        assert_outputs(
            "Before synchronous reset edge",
            prev_result, prev_carry, prev_borrow,
            prev_zero, prev_overflow
        );

        wait until rising_edge(clk);
        wait for 1 ns;

        assert_outputs(
            "Reset after activity",
            (DATA_WIDTH-1 downto 0 => '0'),
            '0', '0', '0', '0'
        );

        report "All " & integer'image(tests_run) &
               " wrapper operation tests passed at " &
               integer'image(DATA_WIDTH) & " bits."
            severity note;

        report "Synchronous reset checks passed."
            severity note;

        wait;

    end process;

end architecture tb;
