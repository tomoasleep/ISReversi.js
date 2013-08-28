assert = require('chai').assert
expect = require('chai').expect
ReversiBoard = require('../../controllers/reversi')
chai = require('chai')
chai.should()

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

  describe '.canMove(x, y, color)', ->
    rev = null
    beforeEach ->
      rev = new ReversiBoard()

    it 'canMove (3, 4, black)', ->
      assert.equal true, rev.canMove(3, 4, ReversiBoard.black)
    
    it '!canMove (3, 3, black) (cannot reverse any stone)', ->
      assert.equal false, rev.canMove(3, 3, ReversiBoard.black)

    it '!canMove (3, 4, white) (cannot reverse any stone)', ->
      assert.equal false, rev.canMove(3, 3, ReversiBoard.black)

    it '!canMove (4, 4, black) (already a stone exist)', ->
      assert.equal false, rev.canMove(4, 4, ReversiBoard.black)

  describe '.move(x, y, color)', ->
    rev = null
    beforeEach ->
      rev = new ReversiBoard()

    it 'move (3, 4, black)', (done) ->

      rev.once 'update', (update) ->
        assert.equal 3, update.point.x
        assert.equal 4, update.point.y
        assert.equal ReversiBoard.black, update.color
        assert.equal 1, update.revPoints.length
        assert.equal 4, update.revPoints[0].x
        assert.equal 4, update.revPoints[0].y
        done()

      rev.move(3, 4, ReversiBoard.black).update

    it 'move (3, 4, white)', ->
      domove = -> rev.move(3, 4, ReversiBoard.white)
      expect(domove).to.throw(Error)

  describe 'countStone', ->
    rev = null
    beforeEach ->
      rev = new ReversiBoard()

    it 'move (3, 4, black)', ->
      rev.move(3, 4, ReversiBoard.black)
      stone = rev.countStone()
      assert.equal 4, stone.black
      assert.equal 1, stone.white

    it 'move (3, 4, black)', ->
      rev.board[5][5] = ReversiBoard.black
      rev.move(3, 4, ReversiBoard.black)

      stone = rev.countStone()
      assert.equal 5, stone.black
      assert.equal 0, stone.white

      assert.equal true, rev.isGameEnd()
    it 'pass', ->
      rev = new ReversiBoard
        black: false
        white: false

      rev.board[4][4] = ReversiBoard.black
      rev.board[5][5] = ReversiBoard.black

      rev.pass(ReversiBoard.black)
      #update1 = rev.updateStack.newest()
      rev.pass(ReversiBoard.white)
      #update2 = rev.updateStack.newest()


      stone = rev.countStone()

      # assert.equal 0, res1.autoPass
      # assert.equal 0, res2.autoPass

      assert.equal 4, stone.black
      assert.equal 0, stone.white

      assert.equal true, rev.isGameEnd()
    it 'auto pass', ->
      rev = new ReversiBoard
        black: false
        white: true

      rev.board[4][4] = ReversiBoard.black
      rev.board[5][5] = ReversiBoard.black

      rev.pass(ReversiBoard.black)

      # console.log res
      # assert.equal 1, res.autoPass

      stone = rev.countStone()
      assert.equal 4, stone.black
      assert.equal 0, stone.white

      assert.equal true, rev.isGameEnd()



