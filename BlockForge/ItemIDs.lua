-- BlockForge : nom anglais -> ID d'objet (genere depuis la table ItemSparse du client Forever 1.60.1.70959)
-- Le client traduit l'ID dans sa langue des que l'objet est en cache : la bibliotheque suit la langue du jeu.
local _, ns = ...
ns.ItemIDs = {
  ["Crippling Poison II"] = 3776, -- Poison affaiblissant II
  ["Deadly Poison V"] = 20844, -- Poison mortel V
  ["Heavy Runecloth Bandage"] = 14530, -- Bandage épais en étoffe runique
  ["Instant Poison VI"] = 8928, -- Poison instantané VI
  ["Major Healing Potion"] = 13446, -- Potion de soins majeure
  ["Major Healthstone"] = 9421, -- Pierre de soins majeure
  ["Major Soulstone"] = 16896, -- Pierre d'âme majeure
  ["Roasted Quail"] = 8952, -- Poulet rôti
  ["Wound Poison IV"] = 10922, -- Poison douloureux IV
}
