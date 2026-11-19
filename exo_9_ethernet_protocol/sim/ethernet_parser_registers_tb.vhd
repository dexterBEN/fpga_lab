
library ieee;
use ieee.std_logic_1164.all;

entity ethernet_parser_registers_tb is
end entity;

architecture tb of ethernet_parser_registers_tb is

    signal dst_mac : std_logic_vector(47 downto 0);
    signal src_mac : std_logic_vector(47 downto 0);
    signal ether_type : std_logic_vector(15 downto 0);

    signal header_done : std_logic;
    signal header_valid : std_logic;
    signal is_ipv4 : std_logic;
    signal is_arp : std_logic;

    signal dst_low  : std_logic_vector(31 downto 0);
    signal dst_high : std_logic_vector(31 downto 0);
    signal src_low  : std_logic_vector(31 downto 0);
    signal src_high : std_logic_vector(31 downto 0);

begin

    uut : entity work.ethernet_parser_registers
        port map (
            dst_mac      => dst_mac,
            src_mac      => src_mac,
            ether_type   => ether_type,

            header_done  => header_done,
            header_valid => header_valid,
            is_ipv4      => is_ipv4,
            is_arp       => is_arp,

            dst_low      => dst_low,
            dst_high     => dst_high,
            src_low      => src_low,
            src_high     => src_high
        );

    stimulus : process
    begin

        -- Test 1 : En-tete Ethernet IPv4
        dst_mac <= x"00E04C6827F6";
        src_mac <= x"76D6D6821566";
        ether_type <= x"0800";

        header_done <= '1';
        header_valid <= '1';
        is_ipv4 <= '1';
        is_arp <= '0';

        wait for 10 ns;

        assert dst_low = x"4C6827F6"
            report "IPv4: dst_low incorrect"
            severity error;

        assert dst_high = x"000700E0"
            report "IPv4: dst_high incorrect"
            severity error;

        assert src_low = x"D6821566"
            report "IPv4: src_low incorrect"
            severity error;

        assert src_high = x"080076D6"
            report "IPv4: src_high incorrect"
            severity error;

        report "IPv4 register mapping OK" severity note;

        -- Test 2 : En-tete Ethernet ARP
        dst_mac <= x"FFFFFFFFFFFF";
        src_mac <= x"123456789ABC";
        ether_type <= x"0806";

        header_done <= '1';
        header_valid <= '1';
        is_ipv4 <= '0';
        is_arp <= '1';

        wait for 10 ns;

        assert dst_low = x"FFFFFFFF"
            report "ARP: dst_low incorrect"
            severity error;

        assert dst_high = x"000BFFFF"
            report "ARP: dst_high incorrect"
            severity error;

        assert src_low = x"56789ABC"
            report "ARP: src_low incorrect"
            severity error;

        assert src_high = x"08061234"
            report "ARP: src_high incorrect"
            severity error;

        report "ARP register mapping OK" severity note;

        -- Test 3 : Indicateurs a zero
        dst_mac <= (others => '0');
        src_mac <= (others => '0');
        ether_type <= (others => '0');

        header_done <= '0';
        header_valid <= '0';
        is_ipv4 <= '0';
        is_arp <= '0';

        wait for 10 ns;

        assert dst_low = x"00000000"
            report "Reset: dst_low incorrect"
            severity error;

        assert dst_high = x"00000000"
            report "Reset: dst_high incorrect"
            severity error;

        assert src_low = x"00000000"
            report "Reset: src_low incorrect"
            severity error;

        assert src_high = x"00000000"
            report "Reset: src_high incorrect"
            severity error;

        report "Zero input mapping OK" severity note;

        report "All Ethernet parser register tests passed!"
            severity note;

        wait;
    end process;

end architecture;
