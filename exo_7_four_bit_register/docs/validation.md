# Validation de l'intégration — session du 5 novembre 2026

## GHDL, commandes réellement exécutées

Devcontainer du lab : `324df92db1c5`, utilisateur `vscode`, répertoire
`/workspaces/fpga_lab/exo_7_four_bit_register`.

Outil : GHDL **4.1.0**, backend mcode, GNAT 13.3.0, VHDL-2008.

```bash
docker exec --user vscode \
  --workdir /workspaces/fpga_lab/exo_7_four_bit_register \
  324df92db1c5 make sim
```

Le Makefile affiche et exécute les analyses `ghdl -a --std=08`,
l'élaboration `ghdl -e --std=08`, puis `ghdl -r --std=08` de chaque testbench.
Les listes exactes de sources figurent dans les recettes correspondantes.

| Testbench | Message de réussite observé à | Résultat |
|---|---|---|
| `parallel_register_tb` | 246 ns | réussite |
| `shift_register_tb` | 166 ns | réussite |
| `register_system_tb` | 137,5 ns | réussite |
| `command_adapter_tb` | 362 ns | réussite |
| `register_axi_wrapper_tb` | 517 ns | réussite |

Après déplacement des métadonnées d'interface du wrapper vers Tcl,
`make sim-integration` a aussi été relancé : réussite à **517 ns**.
Les trois anciens modules RTL n'ont pas été réécrits.

## Notebook

- Syntaxe Python du pilote et de toutes les cellules : vérifiée par `ast.parse`.
- Format du notebook : vérifié dans le devcontainer avec `nbformat.validate`.
- Mapping GPIO 9/4 bits : comparé au HWH réellement généré.
- Aucune cellule matérielle exécutée ; compteurs d'exécution et sorties vides.

## Vivado 2024.1, vérifications réellement exécutées

Le Block Design a été créé et `validate_bd_design` a réussi. L'implémentation
finale utilise le projet `build/pynq_overlay_script_check/registers.xpr`.
Les commandes suivantes ont été exécutées sur l'hôte disposant de Vivado,
depuis le dossier de l'exercice (en utilisant le chemin complet du binaire) :

```bash
PYNQ_OVERLAY_DIR="$PWD/build/pynq_overlay_script_check" \
  vivado -mode batch -log build/overlay_script_check.log \
  -journal build/overlay_script_check.jou -source scripts/build_overlay.tcl

PYNQ_OVERLAY_DIR="$PWD/build/pynq_overlay_script_check" \
  vivado -mode batch -log build/overlay_final.log \
  -journal build/overlay_final.jou -source scripts/build_overlay.tcl \
  -tclargs implement
```

Le second appel a terminé avec un code de retour **0** et le message
`EXO7_BITSTREAM_READY`. Le premier crée/valide le projet ; le second ouvre
ce projet et réalise synthèse, placement/routage et génération du bitstream.

Rapports : `build/pynq_overlay_script_check/reports/`.

| Vérification après routage | Résultat observé |
|---|---|
| Horloge `clk_fpga_0` | 100 MHz, période 10 ns |
| Setup WNS / TNS | +4,274 ns / 0 ns |
| Hold WHS / THS | +0,099 ns / 0 ns |
| Pulse width WPWS / TPWS | +4,020 ns / 0 ns |
| Registres sans horloge | 0 |
| Endpoints internes non contraints | 0 |
| Ports sans input/output delay signalés | 0 / 0 |
| DRC | 0 violation |
| Méthodologie | 0 violation |
| CDC | `All paths are Safely Timed.` |
| Génération bitstream | réussie |

Le HWH final confirme : AXI GPIO dual 9 bits en sortie / 4 bits en entrée,
fréquences PS FCLK0 et M_AXI_GP0 à 100 MHz, reset externe du contrôleur de
reset actif bas. La logique PL et les transactions AXI partagent l'horloge.

Les fichiers exportés ont été comparés octet par octet aux fichiers générés
du projet final : correspondance confirmée pour le BIT et le HWH.

| Livrable | SHA-256 |
|---|---|
| `overlay/registers.bit` | `5899d32dc28d3d58b51cd0be2764043209449a7eee911f9886ac1afed6e45229` |
| `overlay/registers.hwh` | `b65960fc2d358f328f448d473022f167d3ee1b6cda88f8f0cb105e9a8c7aae35` |

### Avertissements conservés et portée des rapports

Le preset PYNQ-Z2 téléchargé contient des valeurs DDR DQS-to-clock négatives
(-0,051, -0,006, -0,009 et -0,033 ns). Vivado les signale avec PSU-1 à PSU-4
pendant la configuration du PS. Ces valeurs proviennent du preset ; elles
n'ont pas été remplacées arbitrairement. Les rapports PL DRC/méthodologie
sans violation ne constituent pas une validation du fonctionnement DDR réel.
La compatibilité avec l'image PYNQ et le fonctionnement sur carte restent à
contrôler pendant la phase matérielle. L'overlay ne fournit pas de nouveau
bootloader et le notebook ne réinitialise pas la DDR du PS.

L'environnement signale aussi que le Tcl Store utilisateur n'est pas
accessible en écriture (`Common 17-741`) et utilise celui de l'installation.
Cela n'a pas empêché les commandes Vivado de terminer. Les avertissements
SmartConnect sur les WRAP bursts en mode Low-Area concernent une fonctionnalité
non utilisée par les lectures/écritures MMIO simples du notebook. Aucun
avertissement n'a été masqué par changement de sévérité ou contrainte inventée.

## Fichiers livrés

- `src/command_adapter.vhd` : impulsions indépendantes et traitement du reset.
- `src/register_axi_wrapper.vhd` : assemblage avec les registres existants.
- `sim/command_adapter_tb.vhd`, `sim/register_axi_wrapper_tb.vhd` : nouveaux tests.
- `Makefile` : cibles dédiées et inclusion dans `make sim`.
- `notebooks/register_system_test.ipynb`, `notebooks/register_control.py` : tests PYNQ.
- `scripts/fetch_board_files.py`, `scripts/build_overlay.tcl` : construction reproductible.
- `docs/integration_pynq.md`, ce rapport et `README.md` : protocole et preuves.
- `overlay/registers.bit`, `overlay/registers.hwh` : fichiers générés pour la carte.

## Limites

Les simulations RTL ne modélisent ni métastabilité, ni délais de routage,
ni l'exécution Python/Linux. Le testbench d'intégration modélise les sorties
GPIO synchrones ; il ne constitue pas une simulation complète du bus AXI.
Le protocole ne possède pas d'ACK et suppose un seul écrivain.

La validation finale sur PYNQ-Z2 reste à réaliser : copier les livrables
correspondants, charger l'overlay, exécuter toutes les cellules du notebook
et enregistrer les résultats réels. Aucun accès matériel n'a été utilisé ici.
