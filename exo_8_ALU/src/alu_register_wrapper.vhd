
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_register_wrapper is
    generic (
        DATA_WIDTH : positive := 8
    );

    port (
        clk      : in  std_logic;
        reset    : in  std_logic;

        a        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        b        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
        op       : in  std_logic_vector(2 downto 0);

        result   : out std_logic_vector(DATA_WIDTH-1 downto 0);
        carry    : out std_logic;
        borrow   : out std_logic;
        zero     : out std_logic;
        overflow : out std_logic
    );
end entity alu_register_wrapper;

architecture rtl of alu_register_wrapper is

    -- Input registers.
    signal a_reg  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal b_reg  : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal op_reg : std_logic_vector(2 downto 0) := (others => '0');

    -- Combinational ALU outputs.
    signal alu_result   : std_logic_vector(DATA_WIDTH-1 downto 0);
    signal alu_carry    : std_logic;
    signal alu_borrow   : std_logic;
    signal alu_zero     : std_logic;
    signal alu_overflow : std_logic;

    -- Output registers.
    signal result_reg   : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    signal carry_reg    : std_logic := '0';
    signal borrow_reg   : std_logic := '0';
    signal zero_reg     : std_logic := '0';
    signal overflow_reg : std_logic := '0';

begin

    -- Instantiate the existing combinational ALU.
    alu_inst : entity work.alu
        generic map (
            DATA_WIDTH => DATA_WIDTH
        )
        port map (
            a        => a_reg,
            b        => b_reg,
            op       => op_reg,

            result   => alu_result,
            carry    => alu_carry,
            borrow   => alu_borrow,
            zero     => alu_zero,
            overflow => alu_overflow
        );

    -- Synchronous registers.
    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then

                -- Reset input registers.
                a_reg  <= (others => '0');
                b_reg  <= (others => '0');
                op_reg <= (others => '0');

                -- Reset output registers.
                result_reg   <= (others => '0');
                carry_reg    <= '0';
                borrow_reg   <= '0';
                zero_reg     <= '0';
                overflow_reg <= '0';

            else

                -- Capture new input operands and opcode.
                a_reg  <= a;
                b_reg  <= b;
                op_reg <= op;

                -- Capture the ALU result from the
                -- previously registered inputs.
                result_reg   <= alu_result;
                carry_reg    <= alu_carry;
                borrow_reg   <= alu_borrow;
                zero_reg     <= alu_zero;
                overflow_reg <= alu_overflow;

            end if;

        end if;
    end process;

    -- Drive external outputs from registers.
    result   <= result_reg;
    carry    <= carry_reg;
    borrow   <= borrow_reg;
    zero     <= zero_reg;
    overflow <= overflow_reg;

end architecture rtl;
