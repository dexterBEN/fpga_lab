# Exercice 7 — intégration PYNQ-Z2 / Python

## Périmètre et audit

Les modules `parallel_register`, `shift_register` et `register_system` sont
conservés sans modification. Ils utilisent un reset asynchrone actif à 1.
`load` et `shift` sont indépendants ; `mode` sélectionne uniquement `q`.
Le wrapper ajoute l'adaptation des commandes GPIO, pas une nouvelle interface AXI.

Le projet autonome `exo_7_four_bit_register.xpr` est conservé. Ses contraintes
`constraints/register_constraints.xdc` décrivent une entrée d'horloge externe
125 MHz sur H16, avec des E/S encore partiellement contraintes. Le slack de
6,777 ns obtenu précédemment ne valide pas cet overlay.

L'overlay utilise un **autre projet**, sous `build/pynq_overlay/`, et une horloge
PS `FCLK_CLK0` de **100 MHz**, commune à AXI GPIO, SmartConnect, l'adaptateur et
les registres. Il ne charge pas le XDC H16 et n'exporte pas les commandes vers
des broches physiques. Seules les interfaces PS DDR et FIXED_IO sont externes.
Flutter, WebSocket, Redis, boutons et breadboard restent hors périmètre.

## Contrat GPIO

IP du script : `register_gpio`, AXI GPIO double canal.

| Canal 1 : sortie du GPIO vers la logique | Bits | Valeur au reset GPIO |
|---|---|---|
| `d` | 3:0 | 0 |
| `serial_in` | 4 | 0 |
| `mode` | 5 | 0 : parallèle |
| `load_request` | 6 | 0 |
| `shift_request` | 7 | 0 |
| `reset_request` | 8 | 0 |

Le canal 1 est configuré en **sortie, largeur 9**, masque `0x1ff`.
Le canal 2 est configuré en **entrée, largeur 4**, masque `0xf`, et reçoit `q`.
Il n'est pas nécessaire d'utiliser deux IP GPIO.

Ne pas lire le canal de sortie pour reconstruire une commande : l'AXI GPIO
ne fournit pas cette relecture des bits configurés en sortie. Le pilote Python
conserve un mot miroir et écrit les neuf bits en une transaction.

## Fronts et stabilité des données

Chaque demande possède son propre état précédent. Hors reset :

```text
Front N : AXI GPIO met à jour son registre de sortie.
Après N : request=1 et previous=0 => pulse=1.
Front N+1 : le registre enfant consomme pulse et les données ;
            previous reçoit request=1.
Après N+1 : pulse=0, même si la demande reste haute.
```

L'impulsion est combinatoire entre deux sources synchrones enregistrées, pas
une impulsion enregistrée ajoutant un étage. Aucune commande ne sert d'horloge.
L'adaptateur ne capture pas les données : le logiciel doit maintenir `d` et
`serial_in` jusqu'à la consommation, puis peut les changer. Deux demandes
simultanées exécutent les deux opérations au même front.

Une demande doit rester basse au moins un front montant avant une nouvelle
montée. Une écriture `1` alors que la demande est déjà haute ne redéclenche pas
l'opération. Une impulsion qui ne traverse aucun front peut être perdue :
l'adaptateur n'est ni un synchroniseur d'entrée externe, ni un protocole CDC.

Protocole du pilote :

1. Écrire les données, série et mode avec les deux demandes basses.
2. Laisser passer les cycles nécessaires au réarmement.
3. Écrire la ou les demandes hautes, avec les mêmes données.
4. Attendre la consommation, puis redescendre les demandes.
5. Pour lire les deux états, sélectionner successivement les deux modes,
   sans nouvelles commandes, puis lire le canal 2.

Le pilote effectue **huit lectures MMIO terminées du canal 2 après chaque
écriture**. Chaque transaction AXI prend des cycles de l'horloge commune ;
avec le MMIO standard PYNQ non mis en cache, cela laisse plus de cycles que
le chemin commande, la désactivation du reset et le réarmement n'en demandent.
Il ne fabrique pas d'impulsion de 10 ns avec un `sleep` Python. Ce mécanisme
suppose une horloge active, un accès direct au GPIO et un seul écrivain.

**Il n'y a aucun ACK, compteur d'opérations ou signal busy.** Les lectures
ne prouvent pas à elles seules qu'une commande a été exécutée. Les assertions
du notebook vérifient les résultats attendus ; des commandes sans changement
d'état peuvent être indiscernables. Un accès concurrent, un proxy d'accès,
un autre domaine d'horloge ou une exigence transactionnelle demanderait une
capture des données et un échange request/ack adapté.

## Resets et démarrage

Deux sources sont distinguées :

- Infrastructure : `aresetn`, issu de `proc_sys_reset/peripheral_aresetn`.
  Le bloc reset est cadencé par FCLK_CLK0 et reçoit FCLK_RESET0_N.
- Fonctionnelle : bit 8 du canal de commandes, initialement nul.

L'adaptateur utilise un conditionneur à deux bascules marquées `ASYNC_REG`.
L'infrastructure remet immédiatement le pipeline à `11` par ses entrées
asynchrones. La demande Python, déjà synchrone à FCLK_CLK0, le remet à `11`
au prochain front montant par le chemin D. Elle masque immédiatement les
impulsions de commande pour empêcher un stockage à ce même front. Cela évite
de combiner deux sources dans une LUT devant les entrées asynchrones.
Après désactivation de toutes les sources, le pipeline passe par `10`, puis `00`
sur deux fronts montants. Le reset enfant est donc libéré après le deuxième
front ; les enfants restent en reset pendant ce front lui-même.

Le reset fonctionnel doit donc être échantillonné au moins une fois à 1 ;
une impulsion ne traversant aucun front n'est pas garantie. Le pilote le
maintient pendant plusieurs transactions AXI. Le reset distribué aux trois
modules conserve leur interface asynchrone existante.

Le pipeline est initialisé à `11` pour le démarrage FPGA. L'infrastructure
doit aussi affirmer `aresetn=0` au démarrage. Les demandes précédentes sont
forcées à 1 pendant le reset : une demande haute à la sortie est **ignorée**.
Chaque demande doit ensuite être échantillonnée basse pour se réarmer.
Avec une demande basse pendant tout le reset, ce réarmement se fait au
troisième front après la levée des sources de reset. Le pilote attend les
transactions nécessaires avant la prochaine demande.

`reset_request` ne réinitialise pas l'AXI GPIO lui-même : le bus reste
accessible pour lever cette demande. En revanche, le reset d'infrastructure
réinitialise aussi le GPIO et l'interconnexion. Ne pas modifier ces rôles
sans traiter la séquence de reprise.

## Vérification RTL

Depuis le devcontainer, dans le dossier de l'exercice :

```bash
make sim
make sim-adapter
make sim-integration
```

Les nouvelles cibles font réellement `ghdl -a --std=08`, puis `-e`, puis `-r`
avec un fichier GHW et `--stop-time=1us`. Le Makefile montre les listes de
fichiers exactes et les commandes exécutées. Chaque compilation est isolée
dans `build/<cible>/`. Les cinq testbenches sont inclus dans `make sim`.

Les nouveaux watchdogs échouent à 900 ns, avant STOP_TIME. Les trois anciens
restent à 500 ns. Les nouveaux tests terminent explicitement avec `std.env.finish`.

Couverture nouvelle : démarrage avec demandes hautes, impulsions indépendantes,
requêtes maintenues pendant huit cycles, réarmement répété, opérations
simultanées, données stables avant consommation, données changées après
consommation, mode combinatoire, conservation, reset avec commandes actives,
deux fronts de désactivation, absence d'opération parasite et reprise.
Le test d'intégration reproduit aussi une mise à jour GPIO après un front N
et vérifie la consommation au front N+1.

Le testbench d'intégration pilote le bus GPIO en RTL ; il ne simule ni le
processeur Linux ni les transactions du contrôleur AXI GPIO AMD. Le câblage
de ces IP est vérifié séparément dans Vivado.

## Construction Vivado 2024.1

Le téléchargement des fichiers de carte utilise une révision fixe du dépôt
Xilinx, sans installation dans `/tools` ou dans le profil utilisateur :

```bash
python3 scripts/fetch_board_files.py
vivado -mode batch -source scripts/build_overlay.tcl -tclargs build
```

Sans `-tclargs build`, le script crée/valide le BD, génère les produits et le
HWH dans le projet, mais ne lance pas synthèse/implémentation. L'argument `build`
lance aussi ces étapes et la génération du bitstream. Les fichiers BIT/HWH
ne sont exportés ensemble vers `overlay/` qu'après réussite de la construction.
Les options Vivado `-log`/`-journal`,
si utilisées, doivent précéder `-tclargs`.

Le script refuse d'écraser un projet déjà présent. Pour implémenter un projet
créé en mode validation, utiliser le même répertoire avec `-tclargs implement`.
On peut aussi ouvrir le projet dans Vivado ; ne pas supprimer le projet autonome. Le
répertoire `build/` est généré et `make clean` le supprime, y compris le projet
overlay et les fichiers de carte téléchargés. Sauvegarder tout changement
manuel du BD avec `write_bd_tcl` avant un nettoyage.

Un dépôt de carte déjà installé peut être utilisé avec `PYNQ_BOARD_REPO`.
Pour reconstruire sans écraser le projet précédent, utiliser un nouveau dossier :

```bash
PYNQ_OVERLAY_DIR="$PWD/build/pynq_overlay_v2" vivado -mode batch -source scripts/build_overlay.tcl -tclargs build
```

Le script n'importe aucune contrainte H16. Il respecte le preset PS PYNQ-Z2,
active M_AXI_GP0 et fixe FCLK_CLK0 à 100 MHz.

### Checklist de câblage, également applicable dans l'interface graphique

1. Créer le projet PYNQ-Z2 (`xc7z020clg400-1`), puis le BD `registers`.
2. Ajouter ZYNQ7 PS et appliquer le preset de carte, DDR et FIXED_IO externes.
3. Activer M_AXI_GP0 et FCLK_CLK0 à 100 MHz.
4. Relier M_AXI_GP0 à SmartConnect S00_AXI, puis M00_AXI à AXI GPIO S_AXI.
5. Configurer `register_gpio` : dual, canal 1 sortie 9 bits, canal 2 entrée 4 bits.
6. Ajouter `register_axi_wrapper` en Module Reference avec les cinq sources VHDL.
7. Relier `gpio_io_o` à `command`, et `q` à `gpio2_io_i`.
8. Relier FCLK_CLK0 aux horloges AXI, M_AXI_GP0_ACLK, wrapper et reset controller.
9. Relier FCLK_RESET0_N à ext_reset_in (polarité basse propagée), dcm_locked à 1,
   aux_reset_in et mb_debug_sys_rst à 0. Interconnect_aresetn va au SmartConnect ;
   peripheral_aresetn va au GPIO et au wrapper.
10. Attribuer les adresses avec l'Address Editor / `assign_bd_address`.
    L'adresse effective est exportée dans le HWH, jamais supposée dans Python.
11. Exécuter `validate_bd_design`, puis générer les produits et le wrapper top.
12. Après routage, examiner setup, hold, pulse width, chemins non contraints,
    DRC, méthodologie et CDC/reset. Le script exporte ces rapports et vérifie
    les pires slacks setup/hold avant de demander le bitstream.

Les avertissements de preset ou de timing ne doivent pas être remplacés par
des valeurs de contraintes inventées. Documenter les avertissements réellement
observés et distinguer ceux du PS, des blocs AXI et de notre logique.

## Déploiement et notebook

Livrables générés : `overlay/registers.bit` et `overlay/registers.hwh`.
Les deux noms de base doivent correspondre ; un HWH seul ne programme pas la PL.

Copier `overlay/` et `notebooks/` sur la PYNQ dans le même dossier parent.
Ouvrir `notebooks/register_system_test.ipynb` dans Jupyter sur la carte.
Le Python du devcontainer ne remplace pas le runtime PYNQ. Le chargement
de l'overlay remplace la configuration PL précédente.

Le notebook identifie le nom réel du GPIO à partir de `overlay.ip_dict` et
contrôle ses paramètres 9/4 bits avant d'utiliser le pilote AxiGPIO.
Il teste les 16 valeurs parallèles, les séquences SIPO, le maintien des
demandes, la conservation, le mode, les opérations simultanées, l'indépendance
des états, le reset et la reprise. Les cellules sont livrées sans sortie.
Enregistrer leurs résultats uniquement après exécution sur le matériel.

## Références

- [AMD UG835, validate_bd_design, Vivado 2024.1](https://docs.amd.com/r/2024.1-English/ug835-vivado-tcl-commands/validate_bd_design)
- [PYNQ, AxiGPIO](https://pynq.readthedocs.io/en/latest/pynq_libraries/axigpio.html)
- [PYNQ, Overlay Design](https://pynq.readthedocs.io/en/latest/overlay_design_methodology/overlay_design.html)
- [AMD PG144, registre GPIO_DATA](https://docs.amd.com/r/en-US/pg144-axi-gpio/AXI-GPIO-Data-Register-GPIOx_DATA)
- [Xilinx XUP, fichiers PYNQ-Z2 à la révision utilisée](https://github.com/Xilinx/xup_embedded_system_design_flow/tree/7a130a4f46db7b4c89871626093308c1642cb53c/board_files/pynq-z2/A.0)
