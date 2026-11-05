# PYNQ-Z2 : horloge de la logique programmable, 125 MHz (periode 8 ns).
set_property PACKAGE_PIN H16 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -name sys_clk -period 8.000 [get_ports clk]

# Contraintes partielles pour une premiere analyse des chemins synchrones.
# Les autres ports ne sont pas encore affectes aux broches de la carte.
# Les chemins d'E/S restent incompletement contraints : leurs contraintes
# dependront de l'interface retenue et de ses caracteristiques temporelles.
# Les entrees physiques asynchrones necessiteront une synchronisation et,
# pour les boutons, un anti-rebond dans le module d'integration sur carte.
# Aucun false_path global n'est applique pour masquer les chemins restants.
