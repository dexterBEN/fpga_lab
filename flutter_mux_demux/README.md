# MUX / DEMUX Visualizer

Application Flutter de simulation des exercices 5 et 6 sur PYNQ-Z2.
Simulation locale et connexion optionnelle à un notebook via WebSocket.
Aucune connexion à la carte n’est nécessaire pour la simulation.

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

L’adaptateur WebSocket implémente `MuxDemuxRepository` et communique avec le
notebook via JSON. Le Cubit gère la connexion et le retour à la simulation.
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

## Connexion au notebook WebSocket

Démarrer le serveur de `notebooks/mux_demux_bridge.ipynb`, puis cliquer sur
**Connecter au serveur**. L’adresse par défaut est `ws://127.0.0.1:8765`.
Les commandes MUX et DEMUX utilisent alors le protocole JSON du notebook et
les indicateurs affichent ses réponses. **Revenir en simulation** restaure
la session locale. Le statut indique la connexion au serveur ; il ne prouve
pas une connexion matérielle à la FPGA (le notebook actuel simule la logique).

Pour utiliser une autre adresse :

```bash
flutter run -d chrome --dart-define=WEBSOCKET_URL=ws://127.0.0.1:8765
```

`127.0.0.1` désigne la machine qui exécute l’application (ou le navigateur).
Dans un Dev Container, vérifier le transfert du port 8765 dans VS Code.
Sur un appareil Android physique, utiliser une adresse joignable du serveur.
Une page web servie en HTTPS nécessite une connexion sécurisée `wss://`.
La connexion est manuelle ; le démarrage reste en simulation locale.
