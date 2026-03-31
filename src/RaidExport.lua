RollFor = RollFor or {}
local m = RollFor

if m.RaidExport then return end

local M = {}

local getn = m.getn

local INCLUDED_RANKS = {
  [ "Raider Gorilla" ] = "raider",
  [ "Core Silverback" ] = "core"
}

local NOTE_RANKS = {
  [ "Wise Monkey" ] = true,
  [ "Officer Wukong" ] = true
}

local function normalize_name( name )
  if not name then return nil end
  return string.gsub( name, "%-.+$", "" )
end

local function lowercase( value )
  return value and string.lower( value ) or ""
end

local function eligible_rank( rank, officernote )
  local note = lowercase( officernote )

  if string.find( note, "alt" ) then
    return nil
  end

  local direct = INCLUDED_RANKS[ rank ]
  if direct then
    return direct
  end

  if NOTE_RANKS[ rank ] then
    if string.find( note, "core" ) then
      return "core"
    end

    if string.find( note, "raider" ) then
      return "raider"
    end
  end

  return nil
end

---@param api table
---@param ace_timer AceTimer
---@param group_roster GroupRoster
---@param softres SoftRes
---@param db table
function M.new( api, ace_timer, group_roster, softres, db )
  local pending = false

  local function item_name( item_id )
    local name = api().GetItemInfo( item_id )
    return name or tostring( item_id )
  end

  local function build_export()
    local players = group_roster.get_all_players_in_my_group()
    local player_map = {}
    local entries = {}
    local guild_count = api().GetNumGuildMembers()
    local timestamp = date( "%Y-%m-%d %H:%M:%S" )

    for _, player in ipairs( players ) do
      local normalized_name = normalize_name( player.name )

      if normalized_name then
        player_map[ string.lower( normalized_name ) ] = {
          name = normalized_name,
          class = player.class or "",
          rank = "",
          officernote = ""
        }
      end
    end

    for i = 1, guild_count do
      local name, rank, _, _, _, _, _, officernote = api().GetGuildRosterInfo( i )
      local normalized_name = normalize_name( name )
      local key = normalized_name and string.lower( normalized_name )

      if key and player_map[ key ] then
        player_map[ key ].rank = rank or ""
        player_map[ key ].officernote = officernote or ""
      end
    end

    for _, item_id in ipairs( softres.get_item_ids() ) do
      local rollers = softres.get( item_id )

      for _, roller in ipairs( rollers ) do
        local normalized_name = normalize_name( roller.name )
        local key = normalized_name and string.lower( normalized_name )
        local player = key and player_map[ key ]
        local tier = player and eligible_rank( player.rank, player.officernote )

        if player and tier then
          local row = {
            ID = item_id,
            Item = item_name( item_id ),
            Boss = "",
            Attendee = player.name,
            Class = player.class,
            Specialization = "",
            Comment = (roller.rolls or 1) > 1 and string.format( "x%s", roller.rolls ) or "",
            Date = timestamp,
            SRPlus = roller.sr_plus or ""
          }

          table.insert( entries, row )

          if tier == "core" then
            table.insert( entries, m.clone( row ) )
          end
        end
      end
    end

    db.lastRaidExport = {
      time = timestamp,
      entries = entries
    }

    pending = false
    m.pretty_print( string.format( "Exported %s raidres entr%s to %s.", getn( entries ), getn( entries ) == 1 and "y" or "ies", m.colors.hl( "RollForDb.lastRaidExport" ) ) )
  end

  local function export()
    if not api().IsInGroup() then
      m.pretty_print( "Not in a group.", m.colors.red )
      return
    end

    if not api().GetGuildInfo( "player" ) then
      m.pretty_print( "You are not in a guild.", m.colors.red )
      return
    end

    if pending then
      m.pretty_print( "Raid export is already in progress.", m.colors.red )
      return
    end

    pending = true
    api().SetGuildRosterShowOffline( true )
    api().GuildRoster()
    ace_timer.ScheduleTimer( M, build_export, 1.0 )
    m.pretty_print( "Requesting guild roster for raid export..." )
  end

  return {
    export = export
  }
end

m.RaidExport = M
return M
