
class UpdateStack
  constructor: (@point, @color, @next) ->
    @revPoints = []

  add: (pt) ->
    @revPoints.push pt

  newest: () ->
    point: @point
    color: @color
    revPoints: @revPoints

class Reversi
  @black = 1
  @white = -1
  @gameEnd = 0

  point = (x, y) -> x: x, y: y

  surrounds = (x, y) ->
    [point(x - 1, y - 1), point(x - 1, y), point(x - 1, y + 1),
     point(x, y - 1),     point(x, y),     point(x, y + 1),
     point(x + 1, y - 1), point(x + 1, y), point(x + 1, y + 1)]

  _findSeqEnd:  (x, y, dx, dy, color, count) ->
    count = count || 0
    if @colorXY(x, y) == color && count > 0
      point(x, y)
    else if @colorXY(x, y) == color * -1
      @_findSeqEnd(x + dx, y + dy, dx, dy, color, count + 1)
    else
      null

  _reverseSeq: (x, y, dx, dy, endx, endy) ->
    return true if x == endx && y == endy
    if @colorXY(x, y)
      @board[x][y] = - @colorXY(x, y)
      @updateStack.add point(x, y)
      @_reverseSeq.call(@, x + dx, y + dy, dx, dy, endx, endy)
    else
      false

  constructor: (@autoPassFlags) ->
    @autoPassFlags = @autoPassFlags || {black: true, white: true}
    @passCount = 0
    @board = (new Array(10) for _v in new Array(10))
    for val, i in @board
      for _v, j in val
        if (0 < i && i < 9) && (0 < j && j < 9)
          @board[i][j] = 0

    @board[4][4] = Reversi.white
    @board[5][5] = Reversi.white
    @board[4][5] = Reversi.black
    @board[5][4] = Reversi.black

    @turn = Reversi.black
    @updateStack = null

  colorXY: (x, y) -> @board[x][y]

  canPutCheck: ->
    for x in [1..8]
      for y in [1..8]
        return true if @canPut(x, y, @turn)
    false
  
  put: (x, y, color) ->
    return null unless @turn == color && @canPut(x, y, color)
    @passCount = 0

    @updateStack = new UpdateStack(point(x, y), color, @updateStack)
    @board[x][y] = color
    vector = surrounds(0, 0)
    for pt, i in surrounds(x, y) 
      seqEnd = @_findSeqEnd.call(@, pt.x, pt.y, vector[i].x, vector[i].y, color)
      if seqEnd
        @_reverseSeq.call(@, pt.x, pt.y, vector[i].x, vector[i].y, seqEnd.x, seqEnd.y)

    @turn = - @turn

    count = 0

    autoPassCount = @autoPass()
    { update: @updateStack.newest(), autoPass: autoPassCount }

  _pass: ->
    unless @canPutCheck()
      if @passCount++ > 0
        @turn = Reversi.gameEnd
        {success: true, autoPass: 0}
      else
        @turn = - @turn
        autoPassCount = @autoPass()
        {success: true, autoPass: autoPassCount}
    else
      {success: false, autoPass: 0}

  pass: (color) ->
    if color == @turn
      @pass()
    else
      return {success: false, autoPass: 0} 
  
  autoPass: ->
    colorKey = if @turn == Reversi.black then 'black' else 'white'
    if @autoPassFlags[colorKey]
      unless @turn == Reversi.gameEnd
        result = @_pass()
        return if result.success then result.autoPass + 1 else result.autoPass
    return 0

  canPut: (x, y, color) ->
    return false unless @colorXY(x, y) == 0
    vector = surrounds(0, 0)
    for pt, i in surrounds(x, y)
      seqEnd = @_findSeqEnd.call(@, pt.x, pt.y, vector[i].x, vector[i].y, color)
      return true if seqEnd
    false

  isGameEnd: -> @turn == Reversi.gameEnd
  gameEnd: -> @turn = Reversi.gameEnd

  countStone: ->
    blackStones = 0
    whiteStones = 0
    for x in [1..8]
      for y in [1..8]
        blackStones++ if @colorXY(x, y) == Reversi.black
        whiteStones++ if @colorXY(x, y) == Reversi.white

    black: blackStones
    white: whiteStones


module.exports = Reversi

