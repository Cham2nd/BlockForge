# BlockForge

**Build macros with blocks, or pick one from a library of 274 ready-made macros.**
For WoW Forever. Interface in English and French, following the game client language.

## What it does

- **Block editor.** Drag blocks (cast, use, cast sequence, stop casting, pet attack, target, focus, equip, dismount…) and reorder them. The macro text updates live.
- **Conditions as buttons.** Mouseover, focus, modifier key, combat, stealth, form, harm/help, dead… No syntax to remember.
- **Spell and item drop.** Drag a spell from the spellbook or an item from your bags onto a block.
- **Live checks.** Character counter (255 max), and warnings for common mistakes: missing spell, two spells on the global cooldown, pet command right after a dismount.
- **Macro library.** 274 macros for the 9 classes, sorted by PvE, PvP, pet and utility. Open one in the editor, change it, save it.
- **Client language.** Spell and item names in the library are translated to your game language.
- **Templates.** Five starting points for pet and PvP macros (pet attack + spell, pet modes on modifier keys, interrupt on focus, crowd control on mouseover, trinket then spell), plus one per ability of your current pet. Drop a spell on the empty slot.
- **Knows your character.** Warns about a spell your character does not know or a misspelled name, and offers the closest spellbook name in one click; the library grays out or hides macros you cannot use yet.
- **Simulator.** Shows which line of the macro would fire for a given modifier key, target, mouseover and focus.
- **My macros.** Lists your game macros, opens them as blocks, binds a key to a macro, exports and imports a macro as a text string, and saves and restores whole sets of macros.
- **Library search.** Search box, category filter and favorites.
- **Colored preview.** Commands, conditions, targets and arguments each get their own color in the macro text.
- **Macro icon.** An action-button preview shows the icon and name the macro will have on your bars; click it to pick an icon from your spellbook or the game's macro icons, or leave it on automatic.
- **Undo and redo.** Every change to the blocks can be undone and redone (buttons, or Ctrl+Z / Ctrl+Y), up to 50 steps.
- **Text editing.** Switch the preview to a text box and type or paste the macro by hand; the blocks follow, and a line the editor does not know is kept as it is.
- **Duplicate a block.** One click copies a line right below it.
- **My templates.** Keep your own macros in a personal library shared by all your characters: search, rename, notes, export and import.
- **Send to a player.** Send a macro in game to another player who has BlockForge. They are asked first, nothing is saved on their side without their consent, and receiving can be turned off in the settings.
- **Built-in spellbook.** A grid of your spells, your pet's abilities and the usable items in your bags, with a search box. One click adds the spell to your macro or fills the selected block.
- **Assistant.** Pick a spell and get ready-made macros for it (mouseover, focus with a modifier key, interrupt on focus, nearest enemy, self-cast with Alt, pet attack, trinkets, cast sequence), with three options. Create the macro in one click, or open it in the editor.
- **Guided tour.** A short tutorial walks through the window the first time you open it; `/bf tuto` replays it.
- **Settings.** Window scale, minimap button, per-character macros by default, confirmation before overwrite, accent color (your class color or gold).

## How to use it

- `/bf` or the minimap button opens the window.
- `/bf options` opens the settings.
- `/bf tuto` replays the guided tour.
- `/bf assistant` opens the macro assistant.
- `/bf test` runs a self-check of the add-on in game.
- Save creates a real game macro. Drag it to your action bar.

## Limits

- Macros cannot be created or edited in combat. This is a game rule.
- The add-on does not cast spells and does not read cooldowns. It only writes standard macros.
- A few library macros contain a placeholder to replace with your own item (mount name, weapon and shield names).
- Some library macros are not yet tested in game.

## Install

1. Download the zip from the releases, or clone this repository.
2. Copy the `BlockForge` folder to `World of Warcraft\_forever_\Interface\AddOns`.
3. Restart the game.

## License

MIT. See [LICENSE](LICENSE).

---

# BlockForge (français)

**Construisez vos macros avec des blocs, ou prenez-en une dans une bibliothèque de 274 macros prêtes à l'emploi.**
Pour WoW Forever. Interface en français et en anglais, selon la langue du client.

## Fonctions

- **Éditeur par blocs.** Glissez les blocs (lancer un sort, utiliser un objet, séquence, arrêter l'incantation, attaque du familier, cibler, focus, équiper, descendre de monture…) et changez leur ordre. Le texte de la macro se met à jour en direct.
- **Conditions en boutons.** Cible survolée, focus, touche de modification, combat, furtivité, forme, ennemi/allié, mort… Aucune syntaxe à retenir.
- **Dépôt de sorts et d'objets.** Glissez un sort du grimoire ou un objet des sacs sur un bloc.
- **Contrôles en direct.** Compteur de caractères (255 max) et avertissements : sort manquant, deux sorts sur le temps de recharge global, ordre de familier juste après une descente de monture.
- **Bibliothèque.** 274 macros pour les 9 classes, classées en PvE, PvP, familier et utilitaire. Ouvrez-en une dans l'éditeur, modifiez-la, enregistrez-la.
- **Langue du client.** Les noms de sorts et d'objets de la bibliothèque sont traduits dans la langue du jeu.
- **Modèles.** Cinq points de départ pour les macros de familier et de PvP (attaque du familier + sort, modes du familier sur touches, interruption sur focus, contrôle sur survol, bijou puis sort), plus un par technique du familier sorti. Glissez un sort sur l'emplacement vide.
- **Connaît votre personnage.** Avertit d'un sort inconnu de votre personnage ou mal écrit, et propose en un clic le nom le plus proche du grimoire ; la bibliothèque grise ou cache les macros que vous ne pouvez pas encore utiliser.
- **Simulateur.** Montre quelle ligne de la macro partirait selon la touche, la cible, le survol et le focus.
- **Mes macros.** Liste vos macros du jeu, les ouvre en blocs, attribue un raccourci clavier, exporte et importe une macro par chaîne de texte, sauvegarde et restaure des jeux de macros.
- **Recherche dans la bibliothèque.** Champ de recherche, filtre par catégorie et favoris.
- **Aperçu coloré.** Commandes, conditions, cibles et arguments ont chacun leur couleur dans le texte de la macro.
- **Icône de la macro.** Un bouton d'action montre l'icône et le nom qu'aura la macro sur vos barres ; cliquez dessus pour choisir une icône de votre grimoire ou parmi celles du jeu, ou laissez le choix automatique.
- **Annuler et rétablir.** Chaque modification des blocs s'annule et se rétablit (boutons, ou Ctrl+Z / Ctrl+Y), jusqu'à 50 étapes.
- **Édition du texte.** Transformez l'aperçu en champ de saisie et tapez ou collez la macro à la main ; les blocs suivent, et une ligne que l'éditeur ne connaît pas est gardée telle quelle.
- **Dupliquer un bloc.** Un clic copie une ligne juste en dessous.
- **Mes modèles.** Gardez vos propres macros dans une bibliothèque personnelle commune à tous vos personnages : recherche, renommage, notes, export et import.
- **Envoi à un joueur.** Envoyez une macro en jeu à un autre joueur qui a BlockForge. Il doit d'abord l'accepter, rien n'est enregistré chez lui sans son accord, et la réception se coupe dans les paramètres.
- **Grimoire intégré.** Une grille de vos sorts, des techniques de votre familier et des objets utilisables de vos sacs, avec un champ de recherche. Un clic ajoute le sort à la macro ou remplit le bloc choisi.
- **Assistant.** Choisissez un sort et obtenez des macros toutes faites pour lui (survol, focus avec touche de modification, interruption sur focus, ennemi le plus proche, sur soi avec Alt, attaque du familier, bijoux, séquence), avec trois options. Créez la macro en un clic, ou ouvrez-la dans l'éditeur.
- **Visite guidée.** Un court tutoriel présente la fenêtre à la première ouverture ; `/bf tuto` le relance.
- **Paramètres.** Échelle de la fenêtre, bouton de minicarte, macros par personnage par défaut, confirmation avant écrasement, couleur d'accent (celle de votre classe ou or).

## Utilisation

- `/bf` ou le bouton de minicarte ouvre la fenêtre.
- `/bf options` ouvre les paramètres.
- `/bf tuto` relance la visite guidée.
- `/bf assistant` ouvre l'assistant de macros.
- `/bf test` lance un contrôle de l'add-on dans le jeu.
- Enregistrer crée une vraie macro du jeu. Glissez-la dans votre barre d'action.

## Limites

- Impossible de créer ou modifier une macro en combat. C'est une règle du jeu.
- L'add-on ne lance aucun sort et ne lit pas les temps de recharge. Il écrit seulement des macros standard.
- Quelques macros de la bibliothèque contiennent un nom à remplacer par le vôtre (monture, arme, bouclier).
- Certaines macros de la bibliothèque ne sont pas encore testées en jeu.

## Installation

1. Téléchargez le zip, ou clonez ce dépôt.
2. Copiez le dossier `BlockForge` dans `World of Warcraft\_forever_\Interface\AddOns`.
3. Relancez le jeu.

## Licence

MIT. Voir [LICENSE](LICENSE).
