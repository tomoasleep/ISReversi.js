
{EventEmitter} = require 'events'

class UpdateStack

  constructor:->
    @list = []

  push: (pt, color) ->
    @list.push
      point: pt
      color: color
      revPoints: []

  add: (pt) ->
    @newest().revPoints.push pt

  newest: ->
    @list[@list.length - 1]

class Reversi extends EventEmitter
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
    @latestAutoPass = 0
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
    @updateStack = new UpdateStack()

  colorXY: (x, y) -> @board[x][y]

  canMoveCheck: ->
    for x in [1..8]
      for y in [1..8]
        return true if @canMove(x, y, @turn)
    false
  
  move: (x, y, color) ->
    throw new Error('illegalMove') unless @turn == color && @canMove(x, y, color)
    @passCount = 0
    @latestAutoPass = 0

    @updateStack.push(point(x, y), color)
    @board[x][y] = color
    vector = surrounds(0, 0)
    for pt, i in surrounds(x, y)
      seqEnd = @_findSeqEnd.call(@, pt.x, pt.y, vector[i].x, vector[i].y, color)
      if seqEnd
        @_reverseSeq.call(@, pt.x, pt.y, vector[i].x, vector[i].y, seqEnd.x, seqEnd.y)

    @turn = - @turn

    count = 0

    @emit 'update', @updateStack.newest()
    @autoPass()
    @

  _doPass: ->
    if @canMoveCheck()
      throw new Error('illegalPass')
    else
      if @passCount++ > 0
        @turn = Reversi.gameEnd
      else
        @turn = - @turn
        @autoPass()


  pass: (color) ->
    @latestAutoPass = 0
    if color == @turn
      @_doPass()
      @
    else
      throw new Error('illegalPass')
  
  autoPass: ->
    try
      colorKey = if @turn == Reversi.black then 'black' else 'white'
      if @autoPassFlags[colorKey]
        unless @turn == Reversi.gameEnd
          @_doPass()
          @emit 'autoPass'
          @latestAutoPass++
    catch _

  canMove: (x, y, color) ->
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

