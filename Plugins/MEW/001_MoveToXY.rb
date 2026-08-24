module MoveToXY
  DIRS   = [2, 4, 6, 8].freeze
  DELTA  = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }.freeze
  # direction code (2/4/6/8) => PBMoveRoute command constant
  TO_CMD = {
    2 => PBMoveRoute::DOWN,
    4 => PBMoveRoute::LEFT,
    6 => PBMoveRoute::RIGHT,
    8 => PBMoveRoute::UP
  }.freeze

  # BFS on the tile grid.  Returns an array of direction codes (2/4/6/8) from
  # the event's current position to (goal_x, goal_y), or nil if unreachable.
  def self.pathfind(event, goal_x, goal_y)
    sx = event.x
    sy = event.y
    return [] if sx == goal_x && sy == goal_y

    # visited maps [x,y] => [parent_x, parent_y, dir] (nil for start)
    visited = { [sx, sy] => nil }
    queue   = [[sx, sy]]
    found   = nil
    limit   = $game_map.width * $game_map.height

    until queue.empty? || found
      cx, cy = queue.shift
      DIRS.each do |dir|
        next unless event.can_move_from_coordinate?(cx, cy, dir)
        dx, dy = DELTA[dir]
        nx = cx + dx
        ny = cy + dy
        next if visited.key?([nx, ny])
        visited[[nx, ny]] = [cx, cy, dir]
        if nx == goal_x && ny == goal_y
          found = [nx, ny]
          break
        end
        queue.push([nx, ny])
        return nil if visited.size > limit  # target unreachable
      end
    end

    return nil unless found

    path = []
    node = found
    while (entry = visited[node])
      px, py, dir = entry
      path.unshift(dir)
      node = [px, py]
    end
    path
  end

  # Build and force a move route from a direction-code path without THROUGH_ON,
  # so the character visually walks around walls (path is already passable).
  def self.apply_route(event, path, skippable: true)
    route            = RPG::MoveRoute.new
    route.repeat     = false
    route.skippable  = skippable
    route.list.clear
    path.each { |dir| route.list.push(RPG::MoveCommand.new(TO_CMD[dir])) }
    route.list.push(RPG::MoveCommand.new(0))
    event.force_move_route(route)
    route
  end

  def self.wait_for_route(event)
    while event.move_route_forcing
      Graphics.update
      Input.update
      pbUpdateSceneMap
    end
  end
end

# Move an event (NPC) to tile (x, y) along the shortest passable path.
# event can be a Game_Character object or an integer event ID.
# Returns true on success, false if the target is unreachable.
# Set wait:false to start the movement and return immediately.
def pbEventMoveToXY(event, x, y, wait: true)
  event = $game_map.events[event] if event.is_a?(Integer)
  return false if event.nil?
  path = MoveToXY.pathfind(event, x, y)
  return false if path.nil?
  return true  if path.empty?
  MoveToXY.apply_route(event, path)
  MoveToXY.wait_for_route(event) if wait
  true
end

# Move the player to tile (x, y) along the shortest passable path.
def pbPlayerMoveToXY(x, y, wait: true)
  pbEventMoveToXY($game_player, x, y, wait: wait)
end
