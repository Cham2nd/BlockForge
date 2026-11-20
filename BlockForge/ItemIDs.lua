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

-- Objets des macros vivantes (ns.LivingItems, Core.lua) : ajoutes a la main, de memoire des donnees de l'ere classique,
-- pas depuis la table du client. A verifier en jeu par /bf test, qui liste les ID sans nom.
for name, id in pairs({
  ["Minor Healing Potion"] = 118, ["Lesser Healing Potion"] = 858, ["Healing Potion"] = 929, ["Greater Healing Potion"] = 1710,
  ["Superior Healing Potion"] = 3928,
  ["Minor Mana Potion"] = 2455, ["Lesser Mana Potion"] = 3385, ["Mana Potion"] = 3827, ["Greater Mana Potion"] = 6149,
  ["Superior Mana Potion"] = 13443, ["Major Mana Potion"] = 13444,
  ["Minor Healthstone"] = 5512, ["Lesser Healthstone"] = 5511, ["Healthstone"] = 5509, ["Greater Healthstone"] = 5510,
  ["Linen Bandage"] = 1251, ["Heavy Linen Bandage"] = 2581, ["Wool Bandage"] = 3530, ["Heavy Wool Bandage"] = 3531,
  ["Silk Bandage"] = 6450, ["Heavy Silk Bandage"] = 6451, ["Mageweave Bandage"] = 8544, ["Heavy Mageweave Bandage"] = 8545,
  ["Runecloth Bandage"] = 14529,
  ["Conjured Muffin"] = 5349, ["Conjured Bread"] = 1113, ["Conjured Rye"] = 1114, ["Conjured Pumpernickel"] = 1487,
  ["Conjured Sourdough"] = 8075, ["Conjured Sweet Roll"] = 8076, ["Conjured Cinnamon Roll"] = 22895,
  ["Tough Hunk of Bread"] = 4540, ["Freshly Baked Bread"] = 4541, ["Moist Cornbread"] = 4542, ["Mulgore Spice Bread"] = 4544,
  ["Soft Banana Bread"] = 4601, ["Homemade Cherry Pie"] = 8950,
  ["Tough Jerky"] = 117, ["Haunch of Meat"] = 2287, ["Mutton Chop"] = 3770, ["Wild Hog Shank"] = 3771, ["Cured Ham Steak"] = 4599,
  ["Conjured Water"] = 5350, ["Conjured Fresh Water"] = 2288, ["Conjured Purified Water"] = 2136, ["Conjured Spring Water"] = 3772,
  ["Conjured Mineral Water"] = 8077, ["Conjured Sparkling Water"] = 8078, ["Conjured Crystal Water"] = 8079,
  ["Refreshing Spring Water"] = 159, ["Ice Cold Milk"] = 1179, ["Melon Juice"] = 1205, ["Sweet Nectar"] = 1708,
  ["Moonberry Juice"] = 1645, ["Morning Glory Dew"] = 8766,
}) do ns.ItemIDs[name] = id end
