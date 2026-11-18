
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ethernet_frame_buffer_gpio_bridge is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;

        -- Registres AXI GPIO
        cmd_word    : in  std_logic_vector(31 downto 0);
        status_word : out std_logic_vector(31 downto 0);

        -- Interface vers ethernet_frame_buffer
        data_in     : out std_logic_vector(7 downto 0);
        data_valid  : out std_logic;
        data_last   : out std_logic;

        read_addr   : out unsigned(10 downto 0);
        read_data   : in  std_logic_vector(7 downto 0);

        frame_ack   : out std_logic;
        frame_ready : in  std_logic;
        frame_size  : in  unsigned(11 downto 0);
        overflow    : in  std_logic
    );
end ethernet_frame_buffer_gpio_bridge;


architecture Behavioral of ethernet_frame_buffer_gpio_bridge is

    type state_type is (
        IDLE,
        SEND_PULSE,
        ACK_PULSE,
        READ_WAIT,
        READ_CAPTURE
    );

    signal state : state_type := IDLE;

    -- Commandes vers le buffer
    signal data_reg       : std_logic_vector(7 downto 0)
                            := (others => '0');

    signal data_last_reg  : std_logic := '0';
    signal data_valid_reg : std_logic := '0';
    signal frame_ack_reg  : std_logic := '0';

    signal read_addr_reg  : unsigned(10 downto 0)
                            := (others => '0');

    signal read_data_reg  : std_logic_vector(7 downto 0)
                            := (others => '0');

    -- Confirmations de commandes
    signal send_seen : std_logic := '0';
    signal ack_seen  : std_logic := '0';
    signal read_seen : std_logic := '0';

    signal pending_toggle : std_logic := '0';

begin

    --------------------------------------------------
    -- Interface vers le buffer
    --------------------------------------------------

    data_in    <= data_reg;
    data_valid <= data_valid_reg;
    data_last  <= data_last_reg;

    read_addr  <= read_addr_reg;
    frame_ack  <= frame_ack_reg;


    --------------------------------------------------
    -- Registre de retour (32 bits)
    --------------------------------------------------

    status_word <=
        "0000000" &
        read_seen &
        ack_seen &
        send_seen &
        overflow &
        frame_ready &
        std_logic_vector(frame_size) &
        read_data_reg;


    --------------------------------------------------
    -- FSM de conversion des commandes GPIO
    --------------------------------------------------

    process(clk)
    begin
        if rising_edge(clk) then

            if rst = '1' then

                state          <= IDLE;

                data_reg       <= (others => '0');
                data_last_reg  <= '0';
                data_valid_reg <= '0';

                frame_ack_reg  <= '0';

                read_addr_reg  <= (others => '0');
                read_data_reg  <= (others => '0');

                send_seen      <= '0';
                ack_seen       <= '0';
                read_seen      <= '0';
                pending_toggle <= '0';

            else

                -- Valeurs par defaut :
                -- aucune impulsion hors d'une commande
                data_valid_reg <= '0';
                frame_ack_reg  <= '0';

                case state is

                    ----------------------------------
                    -- Attente d'une nouvelle commande
                    ----------------------------------
                    when IDLE =>

                        -- Priorite 1 : envoyer un octet
                        if cmd_word(9) /= send_seen then

                            data_reg      <= cmd_word(7 downto 0);
                            data_last_reg <= cmd_word(8);

                            pending_toggle <= cmd_word(9);

                            -- Le buffer prendra en compte
                            -- l'impulsion au prochain front
                            data_valid_reg <= '1';

                            state <= SEND_PULSE;

                        -- Priorite 2 : acquitter la trame
                        elsif cmd_word(10) /= ack_seen then

                            pending_toggle <= cmd_word(10);
                            frame_ack_reg <= '1';

                            state <= ACK_PULSE;

                        -- Priorite 3 : demander une lecture
                        elsif cmd_word(22) /= read_seen then

                            read_addr_reg <= unsigned(
                                cmd_word(21 downto 11)
                            );

                            pending_toggle <= cmd_word(22);

                            state <= READ_WAIT;

                        end if;


                    ----------------------------------
                    -- L'impulsion d'ecriture est
                    -- consommee par le buffer
                    ----------------------------------
                    when SEND_PULSE =>

                        data_valid_reg <= '0';

                        send_seen <= pending_toggle;

                        state <= IDLE;


                    ----------------------------------
                    -- L'impulsion ACK est consommee
                    -- par le buffer
                    ----------------------------------
                    when ACK_PULSE =>

                        frame_ack_reg <= '0';

                        ack_seen <= pending_toggle;

                        state <= IDLE;


                    ----------------------------------
                    -- Attendre la lecture synchrone
                    -- de la BRAM
                    ----------------------------------
                    when READ_WAIT =>

                        -- La BRAM echantillonne
                        -- read_addr_reg sur ce front.
                        state <= READ_CAPTURE;


                    ----------------------------------
                    -- Memoriser l'octet lu
                    ----------------------------------
                    when READ_CAPTURE =>

                        read_data_reg <= read_data;

                        -- Confirmer seulement apres
                        -- capture de la donnee
                        read_seen <= pending_toggle;

                        state <= IDLE;

                end case;
            end if;
        end if;
    end process;

end Behavioral;
