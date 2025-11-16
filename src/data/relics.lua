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
  rally_banner = {
    id = "rally_banner",
    name = "Rally Banner",
    rarity = relics.Rarity.UNCOMMON,
    slot = "passive",
    type = "passive",
    icon = "assets/images/relics/rally_banner.png",
    tags = { "defense", "start_of_battle" },
    description = "Start each battle with +6 armor.",
    flavor = "When the banner rises, shields lock and spirits harden.",
    effects = {
      {
        trigger = "battle_start",
        action = "add_player_armor",
        value = 6,
        source = "rally_banner",
      },
    },
  },
  first_aid_satchel = {
    id = "first_aid_satchel",
    name = "First Aid Satchel",
    rarity = relics.Rarity.COMMON,
    slot = "passive",
    type = "passive",
    icon = "assets/images/relics/lifebound_talisman.png",
    tags = { "healing", "post_battle" },
    description = "At the end of combat, heal 8 HP.",
    flavor = "Bandages, tinctures, and a promise to fight another day.",
    effects = {
      {
        trigger = "battle_end",
        action = "heal_player",
        value = 8,
        source = "first_aid_satchel",
      },
    },
  },
  hunters_mark = {
    id = "hunters_mark",
    name = "Hunter's Mark",
    rarity = relics.Rarity.UNCOMMON,
    slot = "passive",
    type = "passive",
    icon = "assets/images/relics/hunters_mark.png",
    tags = { "elite", "offense" },
    description = "Elite enemies have 20% less HP.",
    flavor = "A sigil etched to cull the strongest before the charge.",
    effects = {
      {
        trigger = "elite_enemy_hp_multiplier",
        value = 0.8, -- 20% less HP
        source = "hunters_mark",
      },
    },
  },
  power_core = {
    id = "power_core",
    name = "Power Core",
    rarity = relics.Rarity.RARE,
    slot = "passive",
    type = "passive",
    icon = "assets/images/relics/power_core.png",
    tags = { "offense", "orb" },
    description = "+1 base damage to all your orbs.",
    flavor = "A crystalline core that resonates with every projectile, sharpening their impact.",
    effects = {
      {
        trigger = "orb_base_damage_bonus",
        mode = "add",
        value = 1,
        source = "power_core",
      },
    },
  },
  travelers_boots = {
    id = "travelers_boots",
    name = "Traveler's Boots",
    rarity = relics.Rarity.RARE,
    slot = "passive",
    type = "passive",
    icon = "assets/images/relics/travelers_boots.png",
    tags = { "exploration", "movement" },
    description = "+2 additional steps each day.",
    flavor = "Well-worn boots that carry you further with each stride.",
    effects = {
      {
        trigger = "daily_steps_bonus",
        mode = "add",
        value = 2,
        source = "travelers_boots",
      },
    },
  },
  camp_rations = {
    id = "camp_rations",
    name = "Camp Rations",
    rarity = relics.Rarity.UNCOMMON,
    slot = "passive",
    type = "passive",
    icon = "assets/images/relics/camp_rations.png",
    tags = { "healing", "rest" },
    description = "Rest sites heal +30% more.",
    flavor = "Carefully preserved provisions that restore more than just hunger.",
    effects = {
      {
        trigger = "rest_site_heal_multiplier",
        mode = "multiply",
        value = 1.3,
        source = "camp_rations",
      },
    },
  },
  lifebound_talisman = {
    id = "lifebound_talisman",
    name = "Lifebound Talisman",
    rarity = relics.Rarity.RARE,
    slot = "passive",
    type = "passive",
    icon = "assets/images/relics/lifebound_talisman.png",
    tags = { "healing", "combat", "rest" },
    description = "Heal 4 HP after every attack. Rest sites no longer heal you.",
    flavor = "The charm drinks from every strike, but lies dormant at campfires.",
    effects = {
      {
        trigger = "player_attack_resolved",
        action = "heal_player",
        value = 4,
        source = "lifebound_talisman",
      },
      {
        trigger = "rest_site_heal_multiplier",
        mode = "override",
        value = 0,
        source = "lifebound_talisman",
      },
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


