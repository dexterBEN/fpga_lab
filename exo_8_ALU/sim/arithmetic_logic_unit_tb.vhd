
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity arithmetic_logic_unit_tb is
    generic (
        DATA_WIDTH : positive := 4
    );
end entity arithmetic_logic_unit_tb;

architecture tb of arithmetic_logic_unit_tb is

    constant MODULUS    : integer := 2 ** DATA_WIDTH;
    constant MAX_VALUE  : integer := MODULUS - 1;
    constant SIGN_BIT   : integer := MODULUS / 2;
    constant SIGNED_MAX : integer := SIGN_BIT - 1;

    signal a        : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal b        : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal op       : std_logic_vector(2 downto 0) := (others => '0');

    signal result   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal carry    : std_logic;
    signal borrow   : std_logic;
    signal zero     : std_logic;
    signal overflow : std_logic;

    -- Test case definition (similar to xUnit InlineData).
    type alu_test_case is record
        input_a   : integer;
        input_b   : integer;
        opcode    : integer;
    end record;

    type alu_test_array is array (natural range <>) of alu_test_case;

    -- Directed test cases.
    -- Expected outputs are calculated by a reference model.
    constant directed_tests : alu_test_array := (

        -- ADD
        (3,          2,         0),
        (0,          0,         0),
        (MAX_VALUE,  1,         0),
        (SIGNED_MAX, 1,         0),
        (SIGN_BIT,   MAX_VALUE, 0),

        -- AND
        (10,         12,        1),
        (MAX_VALUE,  0,         1),
        (MAX_VALUE,  MAX_VALUE, 1),

        -- OR
        (10,         12,        2),
        (0,          0,         2),
        (SIGN_BIT,   1,         2),

        -- SUB
        (5,          3,         3),
        (3,          5,         3),
        (0,          0,         3),
        (0,          1,         3),
        (SIGNED_MAX, MAX_VALUE, 3),
        (SIGN_BIT,   1,         3),

        -- Unsupported operations
        (10,         5,         4),
        (10,         5,         5),
        (10,         5,         6),
        (10,         5,         7)
    );

begin

    -- Device Under Test.
    dut : entity work.alu
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
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

        -- Execute one test case.
        -- Reference calculations are independent of the DUT flags.
        procedure check_alu(
            constant test_name : in string;
            constant test_data : in alu_test_case
        ) is
            variable va : std_logic_vector(DATA_WIDTH-1 downto 0);
            variable vb : std_logic_vector(DATA_WIDTH-1 downto 0);

            variable expected_result   : std_logic_vector(DATA_WIDTH-1 downto 0);
            variable expected_carry    : std_logic := '0';
            variable expected_borrow   : std_logic := '0';
            variable expected_zero     : std_logic := '0';
            variable expected_overflow : std_logic := '0';

            variable raw_result    : integer;
            variable signed_a      : integer;
            variable signed_b      : integer;
            variable signed_result : integer;
        begin

            va := std_logic_vector(
                to_unsigned(test_data.input_a, DATA_WIDTH)
            );

            vb := std_logic_vector(
                to_unsigned(test_data.input_b, DATA_WIDTH)
            );

            -- Apply stimulus.
            a  <= va;
            b  <= vb;
            op <= std_logic_vector(to_unsigned(test_data.opcode, 3));

            -- Reset expected flags.
            expected_carry    := '0';
            expected_borrow   := '0';
            expected_zero     := '0';
            expected_overflow := '0';
            expected_result   := (others => '0');

            -- Interpret operands as signed two's complement.
            signed_a := test_data.input_a;
            signed_b := test_data.input_b;

            if signed_a >= SIGN_BIT then
                signed_a := signed_a - MODULUS;
            end if;

            if signed_b >= SIGN_BIT then
                signed_b := signed_b - MODULUS;
            end if;

            -- Reference model.
            case test_data.opcode is

                when 0 =>  -- ADD

                    raw_result :=
                        test_data.input_a + test_data.input_b;

                    expected_result :=
                        std_logic_vector(
                            to_unsigned(raw_result mod MODULUS, DATA_WIDTH)
                        );

                    if raw_result >= MODULUS then
                        expected_carry := '1';
                    end if;

                    signed_result := signed_a + signed_b;

                    if signed_result < -SIGN_BIT or
                       signed_result > SIGNED_MAX then
                        expected_overflow := '1';
                    end if;

                when 1 =>  -- AND

                    expected_result := va and vb;

                when 2 =>  -- OR

                    expected_result := va or vb;

                when 3 =>  -- SUB

                    raw_result :=
                        test_data.input_a - test_data.input_b;

                    expected_result :=
                        std_logic_vector(
                            to_unsigned(
                                (raw_result + MODULUS) mod MODULUS,
                                DATA_WIDTH
                            )
                        );

                    if test_data.input_a < test_data.input_b then
                        expected_borrow := '1';
                    end if;

                    signed_result := signed_a - signed_b;

                    if signed_result < -SIGN_BIT or
                       signed_result > SIGNED_MAX then
                        expected_overflow := '1';
                    end if;

                when others =>

                    expected_result := (others => '0');

            end case;

            -- Zero flag applies to every operation.
            if expected_result = (expected_result'range => '0') then
                expected_zero := '1';
            end if;

            -- Allow combinational signals to settle.
            wait for 10 ns;

            assert result = expected_result
                report "FAIL " & test_name &
                       " RESULT: expected " & to_string(expected_result) &
                       ", got " & to_string(result)
                severity failure;

            assert carry = expected_carry
                report "FAIL " & test_name & " CARRY"
                severity failure;

            assert borrow = expected_borrow
                report "FAIL " & test_name & " BORROW"
                severity failure;

            assert zero = expected_zero
                report "FAIL " & test_name & " ZERO"
                severity failure;

            assert overflow = expected_overflow
                report "FAIL " & test_name & " OVERFLOW"
                severity failure;

            tests_run := tests_run + 1;

        end procedure;

    begin

        -- This testbench targets 4-bit and 8-bit configurations.
        assert DATA_WIDTH = 4 or DATA_WIDTH = 8
            report "Supported DATA_WIDTH values: 4 or 8"
            severity failure;

        -- ============================================
        -- TEST 1 - Data-driven directed tests
        -- ============================================

        report "Running directed tests..." severity note;

        for i in directed_tests'range loop
            check_alu(
                "Directed test " & integer'image(i),
                directed_tests(i)
            );
        end loop;

        report "Directed tests passed." severity note;

        -- ============================================
        -- TEST 2 - Exhaustive ADD / SUB tests
        -- ============================================

        report "Running exhaustive arithmetic tests..."
            severity note;

        for ia in 0 to MAX_VALUE loop
            for ib in 0 to MAX_VALUE loop

                check_alu(
                    "ADD A=" & integer'image(ia) &
                    " B=" & integer'image(ib),
                    (ia, ib, 0)
                );

                check_alu(
                    "SUB A=" & integer'image(ia) &
                    " B=" & integer'image(ib),
                    (ia, ib, 3)
                );

            end loop;
        end loop;

        report "All " & integer'image(tests_run) &
               " ALU tests passed at " &
               integer'image(DATA_WIDTH) & " bits."
            severity note;

        wait;

    end process;

end architecture tb;
