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
- **My macros.** Lists your game macros, opens them as blocks, binds a key to a macro, exports and imports a macro as a text string, and saves all your macros as a profile.
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
- **Home tab.** The window opens on a dashboard: your macro slot counts, a health summary, the main entries and up to five library macros your character can cast and does not have yet.
- **Upgrade my bar.** BlockForge shows your action bars slot by slot. Click a spell or an item, pick one of the Assistant's macros, and it is created and placed in that same slot. Two bulk buttons turn all your helpful or harmful spells into mouseover macros, with a before/after preview.
- **Undo.** The last change to your bars or macros is reverted in one click, even after a `/reload`. If the game does not confirm a placement, the macro stays on your cursor and a message names the slot.
- **Health check.** Sorts your game macros into broken, duplicates, orphans (on no bar, bound to no key) and at risk. Open, repair with the closest spellbook name, or archive: the macro is copied to My templates before it is deleted, after a confirmation.
- **Macro slot gauge.** General and character macro counts (for example 87 / 120 · 12 / 30) stay visible in the title bar and change color near the limit.
- **Living macros.** On a block, "Living..." puts a token in place of a fixed name: the best healing or mana potion in your bags, a healthstone, the best bandage, food, water, the trinket or weapon you wear, a mount carried in your bags, your pet's name, or the highest rank of a spell. The game macro always holds a real name; BlockForge rewrites it out of combat when your bags, gear, spellbook or pet change, keeping its place on your bars, its name and its icon. A log shows the last 20 rewrites, and a macro edited outside BlockForge is not rewritten again until you confirm it.
- **Survival button.** An Assistant recipe: healthstone, else your best healing potion, and a bandage with a key held. Another recipe uses your two trinkets by name before a spell.
- **Character kits.** "Equip my character": pick a role (leveling, dungeon/raid, PvP), mouseover or target aiming, with or without a pet, and get a checklist of 8 to 20 macros for your class. Macros whose spell you have not learned yet are grayed and unchecked; a macro you already have is never overwritten. "Install all" creates the checked macros; an optional step places them on a row of your bars, with a preview. When you learn a spell, the Home tab offers the kit macros that became usable.
- **Profiles.** A profile keeps your macros and, if you want, the keys bound to them and their place on your bars. Activating one first shows what will be created, rewritten or left, and what each key and slot loses; macros absent from the profile are removed only if you ask, and are archived in My templates first. Copy a profile from another character, link one to each specialization (BlockForge then offers it when you switch, out of combat), export and import a whole profile as text. Your old macro sets became profiles.
- **Automatic backups.** Every bulk operation (kit, profile, several living macros at once) first saves all your macros; the last five backups are kept, and one "Undo" reverts the whole operation.
- **Feature switches.** Every feature above the editor core (home tab, bar upgrade, health check, suggestions, gauge, Assistant, spellbook, macro exchange, automatic tour, colored preview, living macros, character kits, profiles, profile offer on specialization change) can be turned off in the settings, without reloading.
- **Settings.** Window scale, minimap button, per-character macros by default, confirmation before overwrite, accent color (your class color or gold).

## How to use it

- `/bf` or the minimap button opens the window.
- `/bf options` opens the settings.
- `/bf tuto` replays the guided tour.
- `/bf assistant` opens the macro assistant.
- `/bf barre` (or `/bf bars`) opens "Upgrade my bar"; `/bf bilan` (or `/bf health`) opens the health check.
- `/bf kit` opens "Equip my character"; `/bf profil` (or `/bf profile`) opens the profiles; `/bf vivant` opens the living macros and their log.
- `/bf test` runs a self-check of the add-on in game.
- Save creates a real game macro. Drag it to your action bar.

## Limits

- Macros cannot be created or edited in combat, and action bars cannot be changed in combat. This is a game rule.
- The health check only sees the bars and key bindings of the character you are playing: a general macro used by another character, by `/click` or by another add-on looks orphaned. That is why macros are archived, not just deleted.
- The add-on does not cast spells and does not read cooldowns. It only writes standard macros.
- A living macro is rewritten out of combat only: a potion looted during a fight is taken into account when the fight ends. The item is picked from what is in your bags, never from cooldowns or health.
- The item lists behind living macros (potions, healthstones, bandages, food, water) cover the common classic items; `/bf test` lists the ones your client does not recognize.
- A kit never binds a key. A profile only restores the keys you chose to save in it, after showing what each one replaces.
- A few library macros contain a placeholder to replace with your own item (mount name, weapon and shield names).
- Some library macros are not yet tested in game.

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
- **Mes macros.** Liste vos macros du jeu, les ouvre en blocs, attribue un raccourci clavier, exporte et importe une macro par chaîne de texte, et sauvegarde toutes vos macros dans un profil.
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
- **Onglet Accueil.** La fenêtre s'ouvre sur un tableau de bord : le compte de vos macros, le bilan de santé en bref, les grandes entrées et jusqu'à cinq macros de la bibliothèque que votre personnage peut lancer et que vous n'avez pas encore.
- **Améliorer ma barre.** BlockForge affiche vos barres d'action emplacement par emplacement. Cliquez sur un sort ou un objet, choisissez une macro de l'Assistant : elle est créée et posée au même endroit. Deux boutons passent d'un coup tous vos sorts d'aide ou offensifs au survol, avec un aperçu avant/après.
- **Annuler.** La dernière modification de vos barres ou de vos macros se défait d'un clic, même après un `/reload`. Si le jeu ne confirme pas une pose, la macro reste sous votre curseur et un message indique l'emplacement.
- **Bilan de santé.** Classe vos macros du jeu en cassées, doublons, orphelines (sur aucune barre, liées à aucune touche) et à risque. Ouvrez, réparez avec le nom le plus proche du grimoire, ou archivez : la macro est copiée dans Mes modèles avant d'être supprimée, après confirmation.
- **Jauge des macros.** Le nombre de macros générales et du personnage (par exemple 87 / 120 · 12 / 30) reste affiché en haut de la fenêtre et change de couleur près de la limite.
- **Macros vivantes.** Sur un bloc, « Vivant… » met un jeton à la place d'un nom fixe : la meilleure potion de soin ou de mana de vos sacs, une pierre de soins, le meilleur bandage, la nourriture, l'eau, le bijou ou l'arme que vous portez, une monture rangée dans vos sacs, le nom de votre familier, ou le plus haut rang d'un sort. La macro du jeu porte toujours un vrai nom ; BlockForge la réécrit hors combat quand vos sacs, votre équipement, votre grimoire ou votre familier changent, en gardant sa place sur vos barres, son nom et son icône. Un journal montre les 20 dernières réécritures, et une macro modifiée hors de BlockForge n'est plus réécrite tant que vous ne l'avez pas confirmé.
- **Bouton de survie.** Une recette de l'Assistant : pierre de soins, sinon votre meilleure potion de soin, et un bandage avec une touche tenue. Une autre recette utilise vos deux bijoux par leur nom avant un sort.
- **Kits de personnage.** « Équiper mon personnage » : choisissez un rôle (montée de niveau, donjon/raid, JcJ), une visée au survol ou sur la cible, avec ou sans familier, et obtenez une liste de 8 à 20 macros à cocher pour votre classe. Les macros dont vous n'avez pas encore appris un sort sont grisées et décochées ; une macro que vous avez déjà n'est jamais écrasée. « Tout installer » crée les macros cochées ; une étape facultative les pose sur une rangée de vos barres, avec un aperçu. Quand vous apprenez un sort, l'onglet Accueil propose les macros du kit devenues utilisables.
- **Profils.** Un profil garde vos macros et, si vous le voulez, les touches qui y mènent et leur place sur vos barres. L'activer montre d'abord ce qui sera créé, réécrit ou laissé, et ce que chaque touche et chaque emplacement perd ; les macros absentes du profil ne sont retirées que si vous le demandez, et sont d'abord archivées dans Mes modèles. Copiez le profil d'un autre personnage, associez-en un à chaque spécialisation (BlockForge vous le propose alors au changement, hors combat), exportez et importez un profil entier en texte. Vos anciens jeux de macros sont devenus des profils.
- **Sauvegardes automatiques.** Chaque opération de masse (kit, profil, plusieurs macros vivantes d'un coup) enregistre d'abord toutes vos macros ; les cinq dernières sauvegardes sont gardées, et un seul « Annuler » défait toute l'opération.
- **Fonctions désactivables.** Chaque fonction autour de l'éditeur (onglet Accueil, amélioration de la barre, bilan de santé, suggestions, jauge, Assistant, grimoire, échange de macros, visite automatique, aperçu coloré, macros vivantes, kits de personnage, profils, proposition d'un profil au changement de spécialisation) se coupe dans les paramètres, sans recharger.
- **Paramètres.** Échelle de la fenêtre, bouton de minicarte, macros par personnage par défaut, confirmation avant écrasement, couleur d'accent (celle de votre classe ou or).

## Utilisation

- `/bf` ou le bouton de minicarte ouvre la fenêtre.
- `/bf options` ouvre les paramètres.
- `/bf tuto` relance la visite guidée.
- `/bf assistant` ouvre l'assistant de macros.
- `/bf barre` (ou `/bf bars`) ouvre « Améliorer ma barre » ; `/bf bilan` (ou `/bf health`) ouvre le bilan de santé.
- `/bf kit` ouvre « Équiper mon personnage » ; `/bf profil` (ou `/bf profile`) ouvre les profils ; `/bf vivant` ouvre les macros vivantes et leur journal.
- `/bf test` lance un contrôle de l'add-on dans le jeu.
- Enregistrer crée une vraie macro du jeu. Glissez-la dans votre barre d'action.

## Limites

- Impossible de créer ou modifier une macro en combat, ni de changer une barre d'action en combat. C'est une règle du jeu.
- Le bilan de santé ne voit que les barres et les raccourcis du personnage en jeu : une macro générale utilisée par un autre personnage, par `/click` ou par un autre add-on paraît orpheline. C'est pourquoi les macros sont archivées, pas seulement supprimées.
- L'add-on ne lance aucun sort et ne lit pas les temps de recharge. Il écrit seulement des macros standard.
- Une macro vivante n'est réécrite que hors combat : une potion ramassée en plein combat est prise en compte à la fin du combat. L'objet est choisi d'après le contenu de vos sacs, jamais d'après les temps de recharge ou les points de vie.
- Les listes d'objets des macros vivantes (potions, pierres de soins, bandages, nourriture, eau) couvrent les objets classiques courants ; `/bf test` liste ceux que votre client ne reconnaît pas.
- Un kit ne lie jamais de touche. Un profil ne remet que les touches que vous avez choisi d'y enregistrer, après avoir montré ce que chacune remplace.
- Quelques macros de la bibliothèque contiennent un nom à remplacer par le vôtre (monture, arme, bouclier).
- Certaines macros de la bibliothèque ne sont pas encore testées en jeu.
