
library ieee;
use ieee.std_logic_1164.all;

entity ethernet_parser_registers is
    port (
        dst_mac      : in std_logic_vector(47 downto 0);
        src_mac      : in std_logic_vector(47 downto 0);
        ether_type   : in std_logic_vector(15 downto 0);

        header_done  : in std_logic;
        header_valid : in std_logic;
        is_ipv4      : in std_logic;
        is_arp       : in std_logic;

        dst_low      : out std_logic_vector(31 downto 0);
        dst_high     : out std_logic_vector(31 downto 0);
        src_low      : out std_logic_vector(31 downto 0);
        src_high     : out std_logic_vector(31 downto 0)
    );
end entity ethernet_parser_registers;

architecture rtl of ethernet_parser_registers is
begin

    -- GPIO 2 : Canal 1
    dst_low <= dst_mac(31 downto 0);

    -- GPIO 2 : Canal 2
    dst_high <=
    (31 downto 20 => '0') &
    is_arp &
    is_ipv4 &
    header_valid &
    header_done &
    dst_mac(47 downto 32);

    -- GPIO 3 : Canal 1
    src_low <= src_mac(31 downto 0);

    -- GPIO 3 : Canal 2
    src_high <= ether_type & src_mac(47 downto 32);

end architecture rtl;
