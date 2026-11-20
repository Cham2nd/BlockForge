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
- **Knows your character.** Warns about a spell your character does not know or a misspelled name, and offers the closest spellbook name in one click; the library greys out or hides macros you cannot use yet.
- **Simulator.** Shows which line of the macro would fire for a given modifier key, target, mouseover and focus.
- **My macros.** Lists your game macros, opens them as blocks, binds a key to a macro, exports and imports a macro as a text string, and saves and restores whole sets of macros.
- **Library search.** Search box, category filter and favorites.
- **Settings.** Window scale, minimap button, per-character macros by default, confirmation before overwrite.

## How to use it

- `/bf` or the minimap button opens the window.
- `/bf options` opens the settings.
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
- **Paramètres.** Échelle de la fenêtre, bouton de minicarte, macros par personnage par défaut, confirmation avant écrasement.

## Utilisation

- `/bf` ou le bouton de minicarte ouvre la fenêtre.
- `/bf options` ouvre les paramètres.
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
