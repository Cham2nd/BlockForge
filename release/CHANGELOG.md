# BlockForge 1.0.0

- **Catégorie Vivantes** : six recettes communes dans la Bibliothèque avec recherche, favoris et création directe, un groupe Macros vivantes dans l’Assistant et un filtre Vivantes dans Mes macros ; masqués quand la fonction est désactivée.

- **Macros vivantes** : cinq recettes autonomes dans l’Assistant (survie, mana, manger et boire, bandage, soin), accessibles sans sort depuis le journal et l’Accueil ; les bijoux vivants acceptent aussi les sorts d’aide.

## Créer et comprendre, sans retenir la syntaxe

- **Assistant** : choisis un sort, une technique de familier ou un objet et une recette adaptée : survol, focus, interruption, ciblage, familier, bijoux, séquence, bouton de survie ou bijoux vivants. Les options refont l’aperçu en direct ; crée la macro ou ouvre-la dans l’éditeur.
- **Mon grimoire** : cherche dans tes sorts actifs, les techniques du familier et les objets utilisables. Un clic ajoute ou remplit un bloc ; Maj+clic ouvre l’Assistant.
- **Expliquer** : chaque ligne se lit en clair, avec ses conditions, alternatives, remises à zéro des séquences et noms des jetons vivants. Disponible dans l’éditeur, les détails de Bibliothèque et Mes macros, et les infobulles des recettes.
- **Traduire les sorts** : quand tu colles ou importes des noms anglais ou français, un bouton propose les noms du client. Les noms reconnus sont traduits, les autres restent intacts ; Annuler revient au texte précédent.
- **Raccourcir** : depuis Plus… ou l’avertissement des 255 caractères, vois chaque réduction sûre et le total gagné, puis applique. Les rangs, commandes et actions gardent leur sens ; les lignes inconnues restent intactes. Annuler et Rétablir fonctionnent sur le texte raccourci.

## Préparer ton personnage et tes barres

- **Améliorer ma barre** : transforme un sort ou un objet en macro de l’Assistant au même emplacement. Deux actions passent tes sorts d’aide ou offensifs au survol, avec aperçu avant/après, contrôle des places et conservation des rangs choisis. Si le client ne confirme pas une pose, la macro reste au curseur et le message indique sa destination.
- **Kits de personnage** : choisis ton rôle, ta visée et les options de familier, puis coche parmi 8 à 20 macros de ta classe. Les sorts non appris sont décochés, les macros existantes restent intactes. L’installation vérifie les places avant de commencer ; la pose sur une barre est facultative, avec aperçu, et ne lie aucune touche. L’Accueil signale les macros devenues utilisables après apprentissage.
- **Profils** : garde tes macros avec leurs touches et emplacements au choix. L’aperçu montre créations, réécritures, suppressions demandées et remplacements de touches ou de boutons avant activation. Les suppressions sont archivées dans Mes modèles. Copie un profil d’un autre personnage ou partage ses macros par export/import BF2. Les anciens jeux de macros sont repris sans perte.
- **Spécialisations** : associe un profil à chaque spécialisation si le client les expose. Le changement propose le profil hors combat ; rien ne s’active sans ton accord.

## Des macros qui suivent ton équipement

- **Macros vivantes** : un jeton remplace un nom fixe pour ta meilleure potion de soin ou de mana, une pierre de soins, un bandage, la nourriture, l’eau, un bijou ou une arme équipée, une monture en sac, le nom du familier ou le meilleur rang d’un sort. Le jeu reçoit toujours un vrai nom.
- Les changements de sacs, équipement, grimoire ou familier mettent à jour les macros hors combat, sans changer nom, icône ni place. Si l’objet manque, le dernier nom reste et l’état le signale. Une macro modifiée ailleurs attend ta confirmation avant de redevenir vivante.
- L’Accueil et /bf vivant montrent les états et les 20 dernières réécritures ; Mes macros affiche la mention Vivante. « Ne plus suivre » arrête le suivi sans modifier la macro.

## Contrôler, sauvegarder et revenir en arrière

- **Bilan de santé** : classe les macros cassées, doublons, orphelines et à risque. Ouvre, répare avec le nom proposé du grimoire ou archive après confirmation. Une copie rejoint Mes modèles avant suppression.
- **Sauvegardes et Annuler** : une opération de masse sauvegarde toutes les macros ; les cinq dernières sauvegardes automatiques restent disponibles. Annuler défait la dernière opération sur macros, touches et barres, même après /reload, en préservant les emplacements modifiés entre-temps.
- **Jauge** : les places générales et celles du personnage restent visibles dans le titre, avec avertissement près de la limite.
- **Bibliothèque** : les noms d’objets inconnus du client ne sont plus traduits à moitié. Les 274 descriptions et l’interface gardent une terminologie cohérente en français et en anglais.

## Découvrir la 1.0 et choisir tes outils

- **Accueil** : retrouve les outils, ton bilan, les comptes de macros et jusqu’à cinq suggestions utiles à ton personnage.
- **Présentation de la 1.0** : un écran autonome présente les dix nouveautés et les fonctions classiques, trois secondes après l’entrée en jeu, hors combat. Il distingue nouvelle installation et mise à jour, ne revient qu’une fois et évite une seconde bienvenue. Chaque tuile ouvre son outil ; une fonction désactivée l’indique.
- Rouvre la présentation avec /bf intro, /bf nouveautes, /bf whatsnew, le numéro de version ou Paramètres. La visite reste limitée à 12 étapes, saute les fonctions désactivées et propose une visite des nouveautés après mise à jour.
- **Paramètres** : chaque fonction facultative se désactive sans recharger, en coupant ses accès, événements et tâches de fond. La colonne Fonctions défile et accueille plus de vingt réglages ; les animations de présentation ont leur propre interrupteur. L’échange de macros coupe à la fois envoi et réception.
- **Commandes** : /bf aide et /bf ? donnent toutes les commandes et leurs alias dans la langue du client. /bf assistant, /bf barre, /bf bilan, /bf kit, /bf profil et /bf vivant ouvrent leurs outils.
- **Diagnostic** : /bf test vérifie notamment les 274 explications, les propriétés du raccourcissement, l’état de bienvenue, ses icônes, les fonctions actives, les recettes, les kits, les profils et les API facultatives, sans modifier tes macros.

# BlockForge 0.8.0

- Annuler / Rétablir : chaque modification des blocs s'annule et se rétablit (boutons en bas de la zone, ou Ctrl+Z / Ctrl+Y), jusqu'à 50 étapes.
- Édition du texte : « Éditer le texte » transforme l'aperçu en champ de saisie ; tapez ou collez la macro, les blocs suivent, et une ligne inconnue de l'éditeur est gardée telle quelle.
- Dupliquer : le bouton « x2 » d'une ligne copie le bloc juste en dessous.
- Bibliothèque personnelle : « Plus… » puis « Ajouter à ma bibliothèque » garde une macro dans « Mes modèles » (onglet Bibliothèque), pour tous vos personnages ; recherche, renommage, note, export et import.
- Envoi à un joueur : « Envoyer à… » (éditeur et « Mes macros ») envoie une macro à un autre joueur qui a BlockForge ; il doit l'accepter, rien n'est enregistré chez lui sans son accord, et la réception se coupe dans les Paramètres.
- Tutoriel : une visite guidée en 10 étapes à la première ouverture de la fenêtre ; `/bf tuto` ou le bouton « Revoir le tutoriel » des Paramètres la relance.
- Traductions : tous les textes de l'interface et les descriptions de la bibliothèque ont été relus, en français comme en anglais.
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
