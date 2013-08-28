ReversiRoom = require('../../controllers/reversi-room')
Reversi = require('../../controllers/reversi')
chai = require('chai')
chai.should()

describe 'ReversiRoom', ->

  room = null

  beforeEach ->
    room = new ReversiRoom('testroom')

  describe 'login', ->
    it 'login (create room and response)', (done) ->
      testname = 'testuser'
      user =
        name: testname

      room.on 'login', (res) ->
        res.name.should.eql testname
        done()

      room.login(user)

  describe 'logout', ->
    it 'login and logout', (done) ->
      count = 1
      testname = 'testuser'
      user =
        name: testname

      check = ->
        if count-- <= 0
          done()

      room.on 'login', (res) ->
        res.name.should.eql testname
        check()

      room.on 'logout', (res) ->
        res.name.should.eql testname
        check()

      room.login(user)
      room.logout(user)

  describe 'pass', ->
    it 'pass', (done) ->
      count = 1
      testname1 = 'testuser1'
      testname2 = 'testuser2'
      user1 =
        name: testname1
        options: 
          autoPass: true
      user2 =
        name: testname2
        options: 
          autoPass: true
      turnPlayer = null

      check = ->
        if count-- <= 0
          done()

      room.on 'gameStart', (res) ->
        console.log arguments
        turnPlayer = res.colors.black
        check()

      room.on 'pass', (res) ->
        console.log arguments
        check()

      room.login(user1)
      room.login(user2)

      room.board.board[4][4] = Reversi.black
      room.board.board[5][5] = Reversi.black
      room.pass(turnPlayer)

