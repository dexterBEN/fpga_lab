# MUX / DEMUX Visualizer

Application Flutter de simulation des exercices 5 et 6 sur PYNQ-Z2.
Le premier jalon est entièrement local : aucune connexion à la carte n’est nécessaire.

## Lancer

```bash
cd flutter_mux_demux
flutter pub get
flutter run -d linux
# Ou dans Chrome :
flutter run -d chrome
```

Android, Linux et web sont initialisés. Le lancement Linux nécessite les outils
Flutter desktop usuels (Clang, CMake, Ninja, GTK). `flutter doctor` indique les
prérequis manquants sur votre machine.

## Utilisation

- Onglets MUX 4→1 et DEMUX 1→4.
- Entrées modifiables par les interrupteurs ou directement dans le graphe.
- Sélecteur réglable via 00…11, les interrupteurs S1/S0 ou la table.
- Chemin sélectionné turquoise, même au niveau logique 0 ; impulsions lorsque
  le signal transporté vaut 1. Les animations respectent la réduction des mouvements.
- Inspecteur des sorties et table de sélection synchronisés.
- Sur un écran étroit, le graphe défile horizontalement pour conserver sa lisibilité.

Les valeurs d’entrée sont conservées lors du changement d’onglet, durant la session.
Le sélecteur est partagé entre les deux modes. Rien n’est persisté au redémarrage.

## Architecture

`lib/app` : thème et injection du Cubit.

`lib/features/mux_demux` :
- `model/circuit_state.dart` : état immuable et résultats combinatoires.
- `bloc/mux_demux_cubit.dart` : actions de l’utilisateur.
- `data/mux_demux_repository.dart` : contrat et simulation locale.
- `view/` : commandes, inspecteur, table, graphe CustomPainter animé.

Le futur adaptateur notebook implémentera `MuxDemuxRepository`. Le transport
et son cycle de connexion asynchrone seront définis au second jalon ; cette
version ne prétend pas accéder au FPGA. Aucun notebook matériel n’est créé ici.
Les exercices VHDL existants ne sont pas modifiés.

Les visuels de référence sont conservés dans `assets/design/` : fond sombre,
nœuds encadrés, routes turquoise et sélecteur sous le composant.

## Vérification

```bash
flutter analyze
flutter test
flutter build web
```

Les tests couvrent toutes les combinaisons binaires MUX/DEMUX, les transitions
Cubit et les interactions de l’interface sur écran large et étroit.
