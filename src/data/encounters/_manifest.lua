-- Manifest file: List all encounter files to load
-- Add new encounter files here as you create them
-- Format: { "subdirectory", "filename" } (without .lua extension)

return {
  -- Base encounters
  { "base", "solo" },
  { "base", "double" },
  
  -- Elite encounters
  { "elite", "crawler_boar" },
  { "elite", "crawler_fawn" },
  { "elite", "stagmaw_fawn" },
  { "elite", "bloodhound_menders" },
  
  -- Difficulty 2 encounters
  { "difficulty_2", "solo_boar" },
  { "difficulty_2", "double_boar" },
  { "difficulty_2", "boar_fawn" },
  { "difficulty_2", "solo_mender" },
  { "difficulty_2", "mender_boar" },
  { "difficulty_2", "solo_bloodhound" },
  { "difficulty_2", "spore_caller_boar" },
}

