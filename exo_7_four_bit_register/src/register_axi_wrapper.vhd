library ieee;
use ieee.std_logic_1164.all;

-- Module Reference IP Integrator : AXI GPIO reste une IP separee.
entity register_axi_wrapper is
    port (
        clk     : in  std_logic;
        aresetn : in  std_logic;
        command : in  std_logic_vector(8 downto 0);
        q       : out std_logic_vector(3 downto 0)
    );
    -- Les metadonnees de l'horloge/reset sont configurees dans le BD Tcl,
    -- pour conserver un VHDL standard compatible GHDL et Vivado.
end entity register_axi_wrapper;

architecture rtl of register_axi_wrapper is
    signal d : std_logic_vector(3 downto 0);
    signal serial_in, mode, load, shift, reset : std_logic;
begin
    adapter_inst : entity work.command_adapter(rtl)
        port map (
            clk => clk, aresetn => aresetn, command => command,
            d => d, serial_in => serial_in, mode => mode,
            load_pulse => load, shift_pulse => shift, reset => reset
        );

    system_inst : entity work.register_system(rtl)
        port map (
            clk => clk, reset => reset, load => load, shift => shift,
            mode => mode, d => d, serial_in => serial_in, q => q
        );
end architecture rtl;
