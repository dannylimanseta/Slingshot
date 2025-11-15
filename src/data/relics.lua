local relics = {}

relics.Rarity = {
  COMMON = "common",
  UNCOMMON = "uncommon",
  RARE = "rare",
  EPIC = "epic",
  LEGENDARY = "legendary",
}

local CATALOG = {
  stoneguard_brooch = {
    id = "stoneguard_brooch",
    name = "Stoneguard Brooch",
    rarity = relics.Rarity.UNCOMMON,
    slot = "passive",
    type = "passive",
    icon = "assets/images/relics/defense_brooch.png",
    tags = { "defense", "armor" },
    description = "Armor blocks grant +5 armor instead of +3.",
    flavor = "Basalt inlays etched with warding runes, worn by the plateau's shieldbearers.",
    effects = {
      {
        trigger = "armor_block_reward",
        mode = "override",
        value = 5,
        source = "stoneguard_brooch",
      },
    },
    metadata = {
      armorBlockBase = 3,
      armorBlockOverride = 5,
    },
  },
}

function relics.get(id)
  return CATALOG[id]
end

function relics.list()
  local list = {}
  for _, relic in pairs(CATALOG) do
    table.insert(list, relic)
  end
  table.sort(list, function(a, b)
    return (a.sortKey or a.id) < (b.sortKey or b.id)
  end)
  return list
end

return relics


