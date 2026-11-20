# BlockForge 1.0.0

- Macros vivantes : dans l'éditeur, le bouton « Vivant… » d'un bloc met un jeton à la place d'un nom fixe : meilleure potion de soin ou de mana de vos sacs, pierre de soins, meilleur bandage, nourriture, eau, bijou du haut ou du bas, arme en main droite ou gauche, monture rangée dans vos sacs, nom de votre familier, plus haut rang d'un sort. La macro du jeu contient toujours un vrai nom, jamais le jeton.
- BlockForge réécrit une macro vivante quand vos sacs, votre équipement, votre grimoire ou votre familier changent, seulement hors combat (en combat, il attend la fin), seulement si son texte change, et sans toucher à sa place sur vos barres, à son nom ni à son icône. Quand il n'y a plus rien dans les sacs, le dernier nom est gardé et la macro est marquée « rien dans les sacs ».
- Une macro vivante modifiée ailleurs (fenêtre de macros du jeu, autre add-on) n'est plus réécrite : elle est marquée « modifiée ailleurs » jusqu'à ce que vous cliquiez « Redevenir vivante ». « Ne plus suivre » oublie le jeton sans toucher à la macro.
- Journal : l'onglet Accueil et `/bf vivant` montrent vos macros vivantes, leur état et les 20 dernières réécritures (par exemple « Potion de soin : Potion de soins supérieure -> Potion de soins majeure »). Dans « Mes macros », une macro vivante est marquée « Vivante ».
- Assistant : deux nouvelles recettes, « Bouton de survie » (pierre de soins, sinon meilleure potion de soin ; bandage avec une touche tenue) et « Bijoux vivants » (vos deux bijoux par leur nom, puis le sort).
- Kits de personnage : « Équiper mon personnage », sur l'Accueil ou par `/bf kit`. Choisissez le rôle (montée de niveau, donjon/raid, JcJ), la visée (survol ou cible) et, pour le chasseur et le démoniste, avec ou sans familier : BlockForge propose 8 à 20 macros de votre classe, chacune avec sa description et son état : utilisable maintenant, sort pas encore appris (grisée et décochée), ou déjà là.
- « Tout installer » crée les macros cochées. Une macro que vous avez déjà n'est jamais écrasée ; s'il n'y a pas assez de places, rien n'est créé et le message donne le compte. Si l'onglet de macros que vous préférez est plein, les macros vont dans l'autre et BlockForge le dit.
- Après l'installation, « Poser sur une barre… » est une étape à part : vous choisissez une rangée de 12 emplacements et voyez ce qui sera posé avant de confirmer. Seuls les emplacements vides sont utilisés, sauf si vous cochez « Remplacer ce qui s'y trouve ». Aucune touche n'est liée par un kit.
- Nouveau sort appris : quand un sort que vous apprenez rend utilisable une macro de votre kit, une ligne de l'Accueil (et une seule ligne de discussion par session) vous le signale, avec un clic pour l'installer.
- Profils : les sauvegardes de « Mes macros » deviennent des profils. Un profil garde vos macros et, si vous le cochez, les touches liées à ces macros et leur place sur vos barres. Vos anciennes sauvegardes sont reprises sans perte.
- Activer un profil (`/bf profil`, ou « Restaurer ») affiche d'abord un aperçu : macros créées, réécrites ou laissées, touches changées avec ce qu'elles remplacent, emplacements changés avec ce qu'ils contenaient. Chaque partie se coche ou se décoche. Les macros absentes du profil ne sont retirées que si vous cochez la case, et sont d'abord archivées dans « Mes modèles ». S'il n'y a pas assez de places, rien n'est changé.
- « Autres personnages » liste les profils enregistrés par vos autres personnages : à l'activation, les noms de sorts passent dans la langue du jeu et l'aperçu compte les macros dont ce personnage ne connaît pas un sort.
- Double spécialisation : si le jeu la propose, associez un profil à chaque spécialisation ; au changement, BlockForge vous propose ce profil, une fois sorti de combat. Rien n'est activé sans votre accord.
- Export et import d'un profil entier en texte « BF2: » (macros seules, sans touches ni barres). Un profil importé s'ajoute à la liste avec son aperçu : rien n'est créé avant « Activer ».
- Sauvegarde automatique : avant chaque opération de masse (kit, profil, plusieurs macros vivantes réécrites d'un coup), toutes vos macros sont enregistrées dans un profil « Auto … » ; les cinq derniers sont gardés. Un seul « Annuler » défait toute l'opération : macros, touches et emplacements.
- Fonctions : quatre cases de plus dans les Paramètres, « Macros vivantes », « Kits de personnage », « Profils » et « Proposer un profil au changement de spé ». Une fonction désactivée n'a plus ni bouton ni commande et n'écoute plus rien ; les sauvegardes automatiques, elles, restent faites.
- Tutoriel : une étape présente les kits, les profils et les macros vivantes (12 étapes ; elle ne parle que des fonctions actives).
- Nouvelles commandes : `/bf kit`, `/bf profil` (ou `/bf profile`) et `/bf vivant`.
- `/bf test` relève aussi ce que chaque jeton vivant trouve pour votre personnage, les objets des listes que le jeu ne reconnaît pas, l'état des kits et des profils, la double spécialisation et l'aller-retour de l'export « BF2: ».
- Bibliothèque : un nom d'objet pas encore connu du jeu n'est plus traduit à moitié (« Heavy Runecloth Bandage » restait en anglais sauf son dernier mot).
- Accueil : la fenêtre s'ouvre sur un nouvel onglet « Accueil », avec le nom de votre personnage, le compte de vos macros, le bilan de santé en bref, les grandes entrées (Assistant, Améliorer ma barre, Bibliothèque, Mes macros) et jusqu'à cinq macros de la bibliothèque que votre personnage peut lancer et que vous n'avez pas encore (« Ouvrir » ou « Créer »).
- Jauge : le nombre de macros générales et de macros du personnage (par exemple « 87 / 120 · 12 / 30 ») reste affiché en haut de la fenêtre ; il passe à l'orange près de la limite, au rouge quand un onglet est plein.
- Améliorer ma barre : BlockForge affiche vos barres d'action, emplacement par emplacement, avec les touches. Cliquez sur un sort ou un objet : l'Assistant propose ses macros, et celle que vous choisissez est créée et posée au même endroit, à la place du sort.
- Conversion en masse : « Passer mes sorts d'aide au survol » et « Passer mes sorts offensifs au survol » transforment d'un coup tous les sorts concernés de vos barres. Une liste avant/après et le nombre de macros à créer s'affichent avant de confirmer ; l'opération est refusée s'il ne reste pas assez de places. Un rang de sort plus bas que votre meilleur rang est conservé dans la macro.
- Annuler : la dernière opération sur vos barres ou vos macros se défait d'un clic, même après un `/reload` : les sorts reviennent à leur place et les macros créées sont supprimées. Un emplacement que vous avez changé entre-temps n'est pas touché.
- Si le jeu ne confirme pas la pose d'une macro, elle reste sous votre curseur et un message indique sur quel emplacement la déposer.
- Bilan de santé : toutes vos macros sont classées en quatre groupes : cassées (sort inconnu, avec le nom le plus proche de votre grimoire), doublons, orphelines (sur aucune barre et liées à aucune touche) et à risque (avertissements de l'éditeur). Pour chaque macro : « Ouvrir », « Réparer », « Archiver ».
- Archiver : la macro est d'abord copiée dans « Mes modèles », puis supprimée du jeu après une confirmation qui indique le nombre de macros ; « Annuler » la recrée. « Archiver les orphelines… » le fait pour tout le groupe.
- Fonctions : dans l'onglet Paramètres, une case par fonction permet de la désactiver sans recharger l'interface : onglet Accueil, Améliorer ma barre, Bilan de santé, suggestions, jauge, Assistant, Mon grimoire, échange de macros entre joueurs, visite guidée automatique, aperçu coloré. Une fonction désactivée n'a plus ni bouton ni commande, et ne fait plus rien en arrière-plan.
- L'ancien réglage « Accepter les macros envoyées par d'autres joueurs » devient la fonction « Échange de macros entre joueurs » : décochée, elle coupe aussi l'envoi.
- Nouvelles commandes : `/bf barre` et `/bf bilan`.
- Tutoriel : la visite commence par l'accueil (12 étapes) et saute les fonctions désactivées.
- `/bf test` relève aussi, en lecture seule, ce que le jeu répond sur les barres d'action, les raccourcis, les spécialisations et quelques fonctions prévues pour la suite, ainsi que l'état de chaque fonction.
- Mon grimoire : le bouton « Mon grimoire » de l'éditeur ouvre, à la place de la liste des blocs, une grille de vos sorts (sans les passifs), des techniques de votre familier et des objets utilisables de vos sacs et de vos deux emplacements de bijou, avec un champ de recherche.
- Un clic sur une icône ajoute le bloc « Lancer un sort » ou « Utiliser un objet » en bas de la macro, ou remplit le bloc choisi s'il attend encore son sort. Maj+clic ouvre l'Assistant pour ce sort.
- Assistant : choisissez un sort, une technique de familier ou un objet, et l'Assistant propose des macros toutes faites adaptées (sort offensif ou d'aide) : survol puis cible, focus avec Maj, interruption sur le focus, ennemi le plus proche, sur soi avec Alt, avec le familier, bijoux puis sort, annuler l'incantation en cours, séquence, objet puis sort.
- Trois options refont toutes les macros proposées en direct : « #showtooltip », « Ne pas viser les morts » et « Arrêter l'attaque avant ».
- « Créer la macro » enregistre tout de suite une macro du jeu au nom du sort (16 caractères au plus, icône automatique) ; « Ouvrir dans l'éditeur » permet de la retoucher d'abord.
- L'Assistant s'ouvre par le bouton « Assistant » de l'éditeur ou par `/bf assistant`.
- Tutoriel : deux étapes de plus, pour le grimoire et l'Assistant (12 étapes).
- `/bf test` compte aussi les sorts, les techniques de familier et les objets trouvés, et contrôle les recettes de l'Assistant.

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
