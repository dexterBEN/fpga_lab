library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ethernet_header_parser_tb is
end entity;

architecture tb of ethernet_header_parser_tb is
    constant CLK_PERIOD : time := 20 ns;
    signal clk          : std_logic := '0';
    signal rst          : std_logic := '1';
    signal data_in      : std_logic_vector(7 downto 0) := (others => '0');
    signal data_valid   : std_logic := '0';
    signal data_last    : std_logic := '0';
    signal read_addr    : unsigned(10 downto 0) := (others => '0');
    signal read_data    : std_logic_vector(7 downto 0);
    signal frame_ack    : std_logic := '0';
    signal frame_ready  : std_logic;
    signal frame_size   : unsigned(11 downto 0);
    signal overflow     : std_logic;
    signal dst_mac      : std_logic_vector(47 downto 0);
    signal src_mac      : std_logic_vector(47 downto 0);
    signal ether_type   : std_logic_vector(15 downto 0);
    signal header_done  : std_logic;
    signal header_valid : std_logic;
    signal is_ipv4      : std_logic;
    signal is_arp       : std_logic;

    type bytes_t is array (natural range <>) of std_logic_vector(7 downto 0);
    constant IPV4_HEADER : bytes_t(0 to 13) := (
        x"00", x"E0", x"4C", x"68", x"27", x"F6",
        x"76", x"D6", x"D6", x"82", x"15", x"66",
        x"08", x"00"
    );
    constant ARP_HEADER : bytes_t(0 to 13) := (
        x"FF", x"FF", x"FF", x"FF", x"FF", x"FF",
        x"12", x"34", x"56", x"78", x"9A", x"BC",
        x"08", x"06"
    );
begin
    clk <= not clk after CLK_PERIOD / 2;

    u_buffer : entity work.ethernet_frame_buffer
        generic map (BUFFER_SIZE => 16)
        port map (
            clk => clk, rst => rst,
            data_in => data_in, data_valid => data_valid,
            data_last => data_last,
            read_addr => read_addr, read_data => read_data,
            frame_ack => frame_ack, frame_ready => frame_ready,
            frame_size => frame_size, overflow => overflow
        );

    u_parser : entity work.ethernet_header_parser
        port map (
            clk => clk, rst => rst,
            data_in => data_in, data_valid => data_valid,
            frame_ready => frame_ready, frame_size => frame_size,
            overflow => overflow, frame_ack => frame_ack,
            dst_mac => dst_mac, src_mac => src_mac,
            ether_type => ether_type,
            header_done => header_done, header_valid => header_valid,
            is_ipv4 => is_ipv4, is_arp => is_arp
        );

    stimulus : process
        procedure send_byte(
            constant value : in std_logic_vector(7 downto 0);
            constant last  : in std_logic
        ) is
        begin
            wait until falling_edge(clk);
            data_in <= value;
            data_valid <= '1';
            data_last <= last;
            wait until rising_edge(clk);
            wait for 1 ns;
            data_valid <= '0';
            data_last <= '0';
        end procedure;

        procedure send_frame(constant frame : in bytes_t) is
        begin
            for i in frame'range loop
                if i = frame'high then
                    send_byte(frame(i), '1');
                else
                    send_byte(frame(i), '0');
                end if;
            end loop;
            wait until rising_edge(clk);
            wait for 1 ns;
        end procedure;

        procedure acknowledge is
        begin
            wait until falling_edge(clk);
            frame_ack <= '1';
            wait until rising_edge(clk);
            wait for 1 ns;
            frame_ack <= '0';
            wait until rising_edge(clk);
            wait for 1 ns;
            assert frame_ready = '0' and header_done = '0'
                report "ACK must clear ready and parser done" severity error;
        end procedure;
    begin
        wait for 2 * CLK_PERIOD;
        wait until falling_edge(clk);
        rst <= '0';

        -- Test 1 : en-tete IPv4 de la capture.
        send_frame(IPV4_HEADER);
        assert frame_ready = '1' and header_done = '1' and header_valid = '1'
            report "IPv4 header not ready/valid" severity error;
        assert frame_size = to_unsigned(14, 12) and overflow = '0'
            report "Wrong IPv4 frame size/overflow" severity error;
        assert dst_mac = x"00E04C6827F6" severity error;
        assert src_mac = x"76D6D6821566" severity error;
        assert ether_type = x"0800" severity error;
        assert is_ipv4 = '1' and is_arp = '0' severity error;
        report "IPv4 header OK" severity note;
        acknowledge;

        -- Test 2 : ARP apres ACK, valide la reutilisation.
        send_frame(ARP_HEADER);
        assert header_done = '1' and header_valid = '1'
            report "ARP header invalid" severity error;
        assert dst_mac = x"FFFFFFFFFFFF" severity error;
        assert src_mac = x"123456789ABC" severity error;
        assert ether_type = x"0806" severity error;
        assert is_ipv4 = '0' and is_arp = '1' severity error;
        report "ARP header OK" severity note;
        acknowledge;

        -- Test 3 : trame trop courte : resultat non valide.
        send_byte(x"11", '0');
        send_byte(x"22", '0');
        send_byte(x"33", '1');
        wait until rising_edge(clk);
        wait for 1 ns;
        assert header_done = '1' and header_valid = '0'
            report "Short frame must be rejected" severity error;
        assert is_ipv4 = '0' and is_arp = '0' severity error;
        report "Short header rejected OK" severity note;
        acknowledge;

        -- Test 4 : 17 octets dans buffer de 16 : overflow.
        -- Les 14 premiers octets ressemblent a IPv4, mais
        -- l'indicateur overflow doit invalider le resultat.
        for i in IPV4_HEADER'range loop
            send_byte(IPV4_HEADER(i), '0');
        end loop;
        send_byte(x"AA", '0');
        send_byte(x"BB", '0');
        send_byte(x"CC", '1');
        wait until rising_edge(clk);
        wait for 1 ns;
        assert overflow = '1' and header_done = '1' and header_valid = '0'
            report "Overflow frame must be invalid" severity error;
        assert is_ipv4 = '0' and is_arp = '0' severity error;
        report "Overflow rejected OK" severity note;
        acknowledge;

        report "All Ethernet parser tests passed!" severity note;
        wait;
    end process;
end architecture;
