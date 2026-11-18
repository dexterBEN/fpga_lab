
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ethernet_frame_buffer is
    generic (
        BUFFER_SIZE : positive := 2048
    );
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;

        -- Reception des octets
        data_in     : in  std_logic_vector(7 downto 0);
        data_valid  : in  std_logic;
        data_last   : in  std_logic;

        -- Lecture de la memoire
        read_addr   : in  unsigned(10 downto 0);
        read_data   : out std_logic_vector(7 downto 0);

        -- Controle de la trame
        frame_ack   : in  std_logic;
        frame_ready : out std_logic;
        frame_size  : out unsigned(11 downto 0);
        overflow    : out std_logic
    );
end ethernet_frame_buffer;


architecture Behavioral of ethernet_frame_buffer is

    --------------------------------------------------
    -- Machine a etats
    --------------------------------------------------

    type state_type is (
        IDLE,
        RECEIVE,
        READY,
        DROP
    );

    signal state : state_type := IDLE;


    --------------------------------------------------
    -- Memoire de stockage
    --------------------------------------------------

    type ram_type is array (0 to BUFFER_SIZE - 1)
        of std_logic_vector(7 downto 0);

    signal ram : ram_type;

    -- Favoriser l'inference d'une Block RAM
    attribute ram_style : string;
    attribute ram_style of ram : signal is "block";


    --------------------------------------------------
    -- Signaux internes
    --------------------------------------------------

    -- Nombre d'octets stockes
    signal write_addr : integer range 0 to BUFFER_SIZE := 0;

    -- Controle du port d'ecriture
    signal mem_we    : std_logic;
    signal mem_waddr : integer range 0 to BUFFER_SIZE - 1 := 0;

    -- Indicateur de depassement
    signal overflow_reg : std_logic := '0';

begin

    --------------------------------------------------
    -- Controle des ecritures memoire
    --------------------------------------------------

    -- Autoriser l'ecriture uniquement pendant
    -- la reception d'une trame.
    mem_we <= '1' when
        rst = '0' and
        data_valid = '1' and
        (
            state = IDLE or
            (
                state = RECEIVE and
                write_addr < BUFFER_SIZE
            )
        )
        else '0';

    -- La premiere adresse est 0.
    -- Les suivantes utilisent write_addr.
    -- En dehors d'une ecriture valide, l'adresse
    -- est maintenue dans la plage de la memoire.
    mem_waddr <= 0 when state = IDLE
                 else write_addr
                 when write_addr < BUFFER_SIZE
                 else 0;


    --------------------------------------------------
    -- FSM : gestion de la reception
    --------------------------------------------------

    process(clk)
    begin
        if rising_edge(clk) then

            if rst = '1' then
                state        <= IDLE;
                write_addr   <= 0;
                overflow_reg <= '0';

            else
                case state is

                    ----------------------------------
                    -- IDLE
                    ----------------------------------
                    when IDLE =>

                        write_addr   <= 0;
                        overflow_reg <= '0';

                        if data_valid = '1' then

                            -- Premier octet stocke
                            -- par le processus memoire
                            write_addr <= 1;

                            if data_last = '1' then
                                state <= READY;
                            else
                                state <= RECEIVE;
                            end if;

                        end if;


                    ----------------------------------
                    -- RECEIVE
                    ----------------------------------
                    when RECEIVE =>

                        if data_valid = '1' then

                            if write_addr < BUFFER_SIZE then

                                -- L'octet est stocke
                                -- par le processus memoire
                                write_addr <= write_addr + 1;

                                if data_last = '1' then
                                    state <= READY;
                                end if;

                            else

                                -- Memoire pleine :
                                -- rejeter la trame
                                overflow_reg <= '1';

                                if data_last = '1' then
                                    state <= READY;
                                else
                                    state <= DROP;
                                end if;

                            end if;

                        end if;


                    ----------------------------------
                    -- DROP
                    ----------------------------------
                    when DROP =>

                        -- Ignorer les octets restants
                        -- jusqu'a la fin de la trame
                        if data_valid = '1' and
                           data_last = '1' then

                            state <= READY;

                        end if;


                    ----------------------------------
                    -- READY
                    ----------------------------------
                    when READY =>

                        -- Conserver la trame et
                        -- ses informations jusqu'a ACK
                        if frame_ack = '1' then
                            state <= IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;


    --------------------------------------------------
    -- Memoire : lecture et ecriture synchrones
    --------------------------------------------------

    process(clk)
    begin
        if rising_edge(clk) then

            -- Un seul point d'ecriture
            if mem_we = '1' then
                ram(mem_waddr) <= data_in;
            end if;

            -- Lecture synchrone
            if to_integer(read_addr) < BUFFER_SIZE then
                read_data <= ram(to_integer(read_addr));
            end if;

        end if;
    end process;


    --------------------------------------------------
    -- Signaux de statut
    --------------------------------------------------

    frame_ready <= '1' when state = READY else '0';

    frame_size <= to_unsigned(
        write_addr,
        frame_size'length
    );

    overflow <= overflow_reg;

end Behavioral;
