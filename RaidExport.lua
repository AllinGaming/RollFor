RollFor = RollFor or {}
local m = RollFor

if m.RaidExport then return end

local M = {}

local getn = m.getn
local MAX_ITEM_INFO_RETRIES = 5
local ITEM_INFO_RETRY_DELAY_SECONDS = 1.0

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

local function count_keys( t )
  local count = 0

  for _ in pairs( t ) do
    count = count + 1
  end

  return count
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
    return name
  end

  local function build_export( item_info_attempt )
    item_info_attempt = item_info_attempt or 1

    local players = group_roster.get_all_players_in_my_group()
    local player_map = {}
    local entries = {}
    local missing_item_names = {}
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
      local resolved_item_name = item_name( item_id )

      if not resolved_item_name then
        missing_item_names[ item_id ] = true
      end

      local rollers = softres.get( item_id )

      for _, roller in ipairs( rollers ) do
        local normalized_name = normalize_name( roller.name )
        local key = normalized_name and string.lower( normalized_name )
        local player = key and player_map[ key ]
        local tier = player and eligible_rank( player.rank, player.officernote )

        if player and tier then
          local row = {
            ID = item_id,
            Item = resolved_item_name or tostring( item_id ),
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
            local duplicated_row = m.clone( row )
            duplicated_row.SRPlus = "yes"
            table.insert( entries, duplicated_row )
          end
        end
      end
    end

    if next( missing_item_names ) and item_info_attempt < MAX_ITEM_INFO_RETRIES then
      for item_id in pairs( missing_item_names ) do
        api().GetItemInfo( item_id )
      end

      ace_timer.ScheduleTimer( M, function() build_export( item_info_attempt + 1 ) end, ITEM_INFO_RETRY_DELAY_SECONDS )
      m.pretty_print( string.format( "Waiting for %s item name%s to load before raid export (%s/%s)...",
        count_keys( missing_item_names ),
        count_keys( missing_item_names ) == 1 and "" or "s",
        item_info_attempt,
        MAX_ITEM_INFO_RETRIES ) )
      return
    end

    db.lastRaidExport = {
      time = timestamp,
      entries = entries
    }

    pending = false

    if next( missing_item_names ) then
      m.pretty_print( string.format( "Some item names were unavailable after %s attempt%s and were exported as item IDs.",
        item_info_attempt,
        item_info_attempt == 1 and "" or "s" ) )
    end

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

    for _, item_id in ipairs( softres.get_item_ids() ) do
      api().GetItemInfo( item_id )
    end

    ace_timer.ScheduleTimer( M, build_export, 1.0 )
    m.pretty_print( "Requesting guild roster for raid export..." )
  end

  return {
    export = export
  }
end

m.RaidExport = M
return M
