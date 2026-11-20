# BlockForge 0.8.0

- Nouveau look : barre de titre épurée avec le numéro de version, onglet actif bien visible, boutons plats, surbrillance au survol de tout ce qui se clique.
- Couleur d'accent : celle de votre classe par défaut, ou l'or d'origine (onglet Paramètres), appliquée tout de suite.
- Éditeur : blocs plus lisibles (icône plus grande, bloc choisi et repère de dépôt plus nets), et une zone vide qui explique par où commencer.
- Aperçu coloré : commandes, conditions, cibles (@unité) et arguments ont chacun leur couleur, dans l'éditeur, la bibliothèque et « Mes macros ».
- Bouton d'action : à côté de l'aperçu, l'icône et le nom de la macro tels qu'ils apparaîtront sur une barre.
- Icône de la macro : un clic sur ce bouton ouvre une grille (Automatique, icônes de votre grimoire, icônes de macro du jeu) ; l'icône choisie est enregistrée avec la macro, et retrouvée quand vous rouvrez la macro.
- Fondu à l'ouverture de la fenêtre.
- Sort mal écrit : l'éditeur propose le nom le plus proche de votre grimoire et le corrige d'un clic.
- Modèles : un modèle par technique du familier sorti (lancée sur l'unité survolée, sinon sur la cible).
- Éditeur : plus de limite à 12 lignes, la liste de blocs défile à la molette.
- Diagnostic : l'add-on garde ses 20 dernières erreurs ; `/bf test` lance un contrôle complet dans le jeu.
- Bibliothèque : recherche insensible aux accents et aux majuscules, affichage plus rapide.
- Jeux de macros : confirmation avant de remplacer un jeu du même nom.
- Fenêtre : l'échelle est plafonnée pour ne jamais dépasser l'écran.
- La liste des modèles ne laisse plus passer les clics.

# BlockForge 0.6.2

- Corrigé : l'add-on ne se chargeait plus en jeu (limite du Lua du jeu dépassée dans l'éditeur). Les versions 0.5.0 à 0.6.1 sont touchées.

# BlockForge 0.6.1

- Première version publiée sur CurseForge. Contenu identique à la 0.6.0, avec l'identifiant du projet CurseForge dans le TOC.
- Bibliothèque : les noms d'objets (pierres, potions, poisons, bandages, nourriture) sont traduits dans la langue du client, comme les sorts.
- Nouvel onglet « Mes macros », export/import par chaîne de texte, jeux de macros, raccourcis clavier, simulateur, modèles familier et PvP, recherche et favoris : voir les versions précédentes.

# BlockForge 0.6.0

- Bibliothèque : les noms d'objets (pierres, potions, poisons, bandages, nourriture) sont traduits dans la langue du client, comme les sorts.
- Contrôle automatique de la bibliothèque à chaque modification : champs, limites du jeu, identifiant de chaque sort.
- Tests automatiques sur GitHub ; un tag de version publie la release avec son zip.

# BlockForge 0.5.0

- Nouvel onglet « Mes macros » : liste des macros du jeu, détail, ouverture dans l'éditeur.
- Export et import d'une macro par chaîne de texte à partager (`BF1:…`).
- Jeux de macros : sauvegarde de toutes les macros, restauration et suppression, hors combat.
- Raccourci clavier attribué à une macro depuis l'add-on, avec confirmation si la touche est déjà prise.
- Éditeur : simulateur « quelle ligne part » selon la touche, la cible, le survol et le focus.

# BlockForge 0.4.0

- Éditeur : bouton « Modèles » avec cinq points de départ (familier : attaque + sort, familier : modes sur touches, PvP : interruption sur focus, PvP : contrôle sur survol, PvP : bijou puis sort).
- Éditeur : nouveaux blocs `/petstay`, `/petdefensive`, `/petaggressive`.
- Éditeur : nouvelles conditions en boutons : `spec:1`, `spec:2`, `group`, `group:raid`, `pvpcombat`, `swimming`, `indoors`, `outdoors`, `resting`.
- Éditeur : un sort glissé sur un bloc remplit son emplacement vide.
- Bibliothèque : recherche, filtre par catégorie, favoris.

# BlockForge 0.3.1

- Corrigé : une macro de plus de 12 lignes chargée dans l'éditeur était coupée sans avertir. Elle n'est plus chargée, avec un message.
- Éditeur : avertissement pour un sort inconnu du personnage ou mal écrit.
- Éditeur : avertissements pour des conditions contradictoires et pour un `#showtooltip` mal placé ou en double.
- Bibliothèque : macros grisées quand un de leurs sorts n'est pas connu du personnage ; case « Mes sorts seulement » pour les cacher.

# BlockForge 0.3.0

- Renommé : MacroForge devient BlockForge. Commandes `/bf`, `/blockforge`. Les réglages repartent de zéro.
- Add-on pour WoW Forever uniquement (interface 16001).
- Interface en anglais sur les clients non français ; descriptions anglaises pour toute la bibliothèque.
- Bibliothèque revue pour Forever : 39 macros corrigées, 12 retirées (sorts non apprenables sur Forever : Icy Veins, Living Bomb, Shadowfiend, Lifebloom, Lava Burst, Earth Shield, Kill Command…), 13 ajoutées (Shifting Power, appels de totems, Demonic Sacrifice, Light's Vigil…). 274 macros.
- Identifiants de sorts corrigés : Shadow Word: Death, Lacerate.
- Avertissement quand une macro combine descente de monture et ordre ou technique de familier.

# MacroForge 0.2.0

Première version publique.

- Éditeur de macros par blocs, avec glisser-déposer et aperçu du texte en direct.
- Conditions en boutons : cible survolée, focus, touche de modification, combat, furtivité, forme, etc.
- Bibliothèque de 273 macros prêtes à l'emploi pour les 9 classes.
- Noms de sorts de la bibliothèque traduits dans la langue du client.
- Avertissements : macro trop longue, sort sans argument, plusieurs sorts sur le temps de recharge global, ordre de familier après une descente de monture.
- Page de paramètres et bouton de minicarte.
- Commandes : `/mf`, `/macroforge`, `/mf options`.
