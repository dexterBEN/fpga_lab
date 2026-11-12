library ieee;
use ieee.std_logic_1164.all;

entity alu_controller is
    port (
        clk      : in  std_logic;
        reset    : in  std_logic;

        start    : in  std_logic;
        ack      : in  std_logic;
        command  : in  std_logic_vector(31 downto 0);

        response : out std_logic_vector(31 downto 0);
        busy     : out std_logic;
        done     : out std_logic
    );
end entity alu_controller;

architecture rtl of alu_controller is

    type state_t is (
        IDLE,
        LOAD,
        WAIT_RESULT,
        CAPTURE,
        DONE_WAIT
    );

    signal state : state_t := IDLE;

    signal command_reg : std_logic_vector(31 downto 0) :=
        (others => '0');

    signal response_reg : std_logic_vector(31 downto 0) :=
        (others => '0');

    signal alu_result   : std_logic_vector(7 downto 0);
    signal alu_carry    : std_logic;
    signal alu_borrow   : std_logic;
    signal alu_zero     : std_logic;
    signal alu_overflow : std_logic;

begin

    alu_inst : entity work.alu_register_wrapper
        generic map (
            DATA_WIDTH => 8
        )
        port map (
            clk      => clk,
            reset    => reset,

            a        => command_reg(7 downto 0),
            b        => command_reg(15 downto 8),
            op       => command_reg(18 downto 16),

            result   => alu_result,
            carry    => alu_carry,
            borrow   => alu_borrow,
            zero     => alu_zero,
            overflow => alu_overflow
        );

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state        <= IDLE;
                command_reg  <= (others => '0');
                response_reg <= (others => '0');
            else
                case state is

                    when IDLE =>
                        if start = '1' then
                            command_reg <= command;
                            state <= LOAD;
                        end if;

                    when LOAD =>
                        -- Wrapper captures A, B and OP.
                        state <= WAIT_RESULT;

                    when WAIT_RESULT =>
                        -- Wrapper captures computed outputs.
                        state <= CAPTURE;

                    when CAPTURE =>
                        -- Copy registered ALU outputs.
                        response_reg <= (others => '0');

                        response_reg(7 downto 0)
                            <= alu_result;

                        response_reg(8)  <= alu_carry;
                        response_reg(9)  <= alu_borrow;
                        response_reg(10) <= alu_zero;
                        response_reg(11) <= alu_overflow;

                        state <= DONE_WAIT;

                    when DONE_WAIT =>
                        -- Keep result and done until ack.
                        if ack = '1' then
                            state <= IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

    busy <= '1' when
        state = LOAD or
        state = WAIT_RESULT or
        state = CAPTURE
        else '0';

    done <= '1' when state = DONE_WAIT else '0';

    response <= response_reg;

end architecture rtl;
