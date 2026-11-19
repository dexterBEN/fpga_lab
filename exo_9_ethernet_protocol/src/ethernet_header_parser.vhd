library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ethernet_header_parser is
    port (
        clk          : in  std_logic;
        rst          : in  std_logic;
        data_in      : in  std_logic_vector(7 downto 0);
        data_valid   : in  std_logic;
        frame_ready  : in  std_logic;
        frame_size   : in  unsigned(11 downto 0);
        overflow     : in  std_logic;
        frame_ack    : in  std_logic;
        dst_mac      : out std_logic_vector(47 downto 0);
        src_mac      : out std_logic_vector(47 downto 0);
        ether_type   : out std_logic_vector(15 downto 0);
        header_done  : out std_logic;
        header_valid : out std_logic;
        is_ipv4      : out std_logic;
        is_arp       : out std_logic
    );
end entity;

architecture rtl of ethernet_header_parser is
    signal byte_count : integer range 0 to 14 := 0;
    signal dst_reg    : std_logic_vector(47 downto 0) := (others => '0');
    signal src_reg    : std_logic_vector(47 downto 0) := (others => '0');
    signal type_reg   : std_logic_vector(15 downto 0) := (others => '0');
    signal done_reg   : std_logic := '0';
    signal valid_reg  : std_logic := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                byte_count <= 0;
                dst_reg    <= (others => '0');
                src_reg    <= (others => '0');
                type_reg   <= (others => '0');
                done_reg   <= '0';
                valid_reg  <= '0';
            elsif frame_ack = '1' then
                byte_count <= 0;
                dst_reg    <= (others => '0');
                src_reg    <= (others => '0');
                type_reg   <= (others => '0');
                done_reg   <= '0';
                valid_reg  <= '0';
            else
                -- Les donnees sont capturees en parallele du buffer.
                -- Seuls les 14 premiers octets sont utiles.
                if data_valid = '1' and frame_ready = '0'
                   and done_reg = '0' then
                    case byte_count is
                        when 0 to 5 =>
                            dst_reg <= dst_reg(39 downto 0) & data_in;
                        when 6 to 11 =>
                            src_reg <= src_reg(39 downto 0) & data_in;
                        when 12 =>
                            type_reg(15 downto 8) <= data_in;
                        when 13 =>
                            type_reg(7 downto 0) <= data_in;
                        when others =>
                            null;
                    end case;
                    if byte_count < 14 then
                        byte_count <= byte_count + 1;
                    end if;
                end if;

                -- frame_ready est visible apres le dernier octet.
                -- Le buffer conserve ce niveau jusqu'a frame_ack.
                if frame_ready = '1' and done_reg = '0' then
                    done_reg <= '1';
                    if frame_size >= to_unsigned(14, frame_size'length)
                       and byte_count = 14 and overflow = '0' then
                        valid_reg <= '1';
                    else
                        valid_reg <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

    dst_mac      <= dst_reg;
    src_mac      <= src_reg;
    ether_type   <= type_reg;
    header_done  <= done_reg;
    header_valid <= valid_reg;
    is_ipv4      <= '1' when valid_reg = '1' and type_reg = x"0800" else '0';
    is_arp       <= '1' when valid_reg = '1' and type_reg = x"0806" else '0';
end architecture;
