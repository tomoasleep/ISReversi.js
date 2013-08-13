assert = require('assert')
ReversiBoard = require('../../controllers/reversi')

describe 'Reversi', ->
  describe '.constructor()', ->
    rev = null
    before ->
      rev = new ReversiBoard()

    it '(4,4) = white', ->
      assert.equal ReversiBoard.white, rev.board[4][4]

    it '(4,5) = black', ->
      assert.equal ReversiBoard.black, rev.board[4][5]

    it '(5,4) = black', ->
      assert.equal ReversiBoard.black, rev.board[5][4]

    it '(5,5) = white', ->
      assert.equal ReversiBoard.white, rev.board[5][5]

    it 'if x = 0,9 then wall', ->
      for x in [0, 9]
        for y in [0..9]
          assert.equal null, rev.board[x][y]

    it 'if y = 0,9 then wall', ->
      for y in [0, 9]
        for x in [0..9]
          assert.equal null, rev.board[x][y]

    it 'first turn is black', ->
      assert.equal ReversiBoard.black, rev.turn

  describe '.canPut(x, y, color)', ->
    rev = null
    beforeEach ->
      rev = new ReversiBoard()

    it 'canPut (3, 4, black)', ->
      assert.equal true, rev.canPut(3, 4, ReversiBoard.black)
    
    it '!canPut (3, 3, black) (cannot reverse any stone)', ->
      assert.equal false, rev.canPut(3, 3, ReversiBoard.black)

    it '!canPut (3, 4, white) (cannot reverse any stone)', ->
      assert.equal false, rev.canPut(3, 3, ReversiBoard.black)

    it '!canPut (4, 4, black) (already a stone exist)', ->
      assert.equal false, rev.canPut(4, 4, ReversiBoard.black)

  describe '.put(x, y, color)', ->
    rev = null
    beforeEach ->
      rev = new ReversiBoard()

    it 'put (3, 4, black)', ->
      update = rev.put(3, 4, ReversiBoard.black)
      assert.equal 3, update.point.x
      assert.equal 4, update.point.y
      assert.equal ReversiBoard.black, update.color
      assert.equal 1, update.revPoints.length
      assert.equal 4, update.revPoints[0].x
      assert.equal 4, update.revPoints[0].y

    it 'put (3, 4, white)', ->
      update = rev.put(3, 4, ReversiBoard.white)
      assert.equal null, update

  describe 'countStone', ->
    rev = null
    beforeEach ->
      rev = new ReversiBoard()

    it 'put (3, 4, black)', ->
      rev.put(3, 4, ReversiBoard.black)
      stone = rev.countStone()
      assert.equal 4, stone.black
      assert.equal 1, stone.white

    it 'put (3, 4, black)', ->
      rev.board[5][5] = ReversiBoard.black
      rev.put(3, 4, ReversiBoard.black)

      stone = rev.countStone()
      assert.equal 5, stone.black
      assert.equal 0, stone.white

      assert.equal true, rev.isGameEnd()



