ReversiServer = require('../../controllers/reversi-server')
Reversi = require('../../controllers/reversi')
chai = require('chai')
chai.should()

class TestConnector
  constructor: (@operator) ->
    @operator.registerConnector(@)

  joinGroup: ->
    @joinfunc.apply(this, arguments) if @joinfunc

  leaveGroup: ->
    @leavefunc.apply(this, arguments) if @leavefunc

  notice: ->
    @noticefunc.apply(this, arguments) if @noticefunc

  noticeToGroup: ->
    @noticeToGroupfunc.apply(this, arguments) if @noticeToGroupfunc

  noticeAll: ->
    @noticeAllfunc.apply(this, arguments) if @noticeAllfunc

describe 'ReversiServer', ->

  testConnector = null
  revServer = null

  beforeEach ->
    revServer = new ReversiServer()
    testConnector = new TestConnector(revServer)
  
  it 'registerConnector', (done) ->
    # revServer.connectors().length.should.eql(1)
    testConnector.noticeAllfunc = (type, data) ->
        type.should.eql 'test'
        data.should.eql 'testdata'
        done()

    revServer.requestNoticeAll('test', 'testdata')

  it 'register', ->
    username = 'testuser'
    testClient =
      id: "test"


    revServer.register(username, testClient, testConnector)



    # info = revServer.userInfo(username)

    # info.state.type.should.eql('waiting')
    # info.client.should.eql(testClient)
    # info.connector.should.eql(testConnector)

  describe 'login', ->
    it 'login (create room and response)', (done) ->
      username = 'testuser'
      roomname = 'testroom'
      testClient =
        id: "test"

      testConnector.noticeAllfunc = (type, data) ->
        type.should.eql 'login'
        data.username.should.eql username
        data.roomname.should.eql roomname
        done()

      revServer.register(username, testClient, testConnector)
      revServer.login(username, roomname)

    it 'double login', (done) ->
      username = 'testuser'
      roomname = 'testroom'
      roomname2 = 'testroom2'
      testClient =
        id: "test"
      count = 2

      check = ->
        if count-- <= 1
          done()

      testConnector.noticeAllfunc = (type, data) ->
        type.should.eql 'login'
        data.username.should.eql username
        data.roomname.should.eql roomname
        check()

      testConnector.noticefunc = (client, type, data) ->
        client.should.eql testClient
        type.should.eql 'loginFailed'
        check()

      revServer.register(username, testClient, testConnector)
      revServer.login(username, roomname)
      revServer.login(username, roomname2)

  describe 'logout', ->
    it 'login and logout', (done) ->
      username = 'testuser'
      roomname = 'testroom'
      testClient =
        id: "test"
      count = 2

      check = ->
        console.log count
        if count-- <= 1
          done()

      testConnector.noticeAllfunc = (type, data) ->
        switch type
          when 'login'
            data.username.should.eql username
            data.roomname.should.eql roomname
            check()
          when 'logout'
            data.username.should.eql username
            data.roomname.should.eql roomname
            check()
          when 'loginFailed', 'logoutFailed'
            console.log 'fail'
            1.should.eql 2

      revServer.register(username, testClient, testConnector)
      revServer.login(username, roomname)
      revServer.logout(username)

    it 'cannot logout before login', (done) ->
      username = 'testuser'
      roomname = 'testroom'
      testClient =
        id: "test"
      count = 0

      testConnector.noticefunc = (client, type, data) ->
        type.should.eql 'logoutFailed'
        done()

      revServer.register(username, testClient, testConnector)
      revServer.logout(username, roomname)

  describe 'gamestart', ->
    it 'gamestart', (done) ->
      usernames = ['testuser1', 'testuser2']
      roomname = 'testroom'
      testClients = [{id: "test1"}, {id: "test2"}] 
      count = 4

      check = ->
        done() if count-- <= 1

      testConnector.noticeAllfunc = (type, data) ->
        console.log arguments
        switch type
          when 'login'
            switch data.username
              when usernames[0]
                data.roomname.should.be.eql roomname
                check()
              when usernames[1]
                data.roomname.should.be.eql roomname
                check()

      testConnector.noticefunc = (client, type, data) ->
        console.log arguments
        switch type
          when 'gameStart'
            data.time.should.eql(60000)
            check()



      revServer.register(usernames[0], testClients[0], testConnector)
      revServer.register(usernames[1], testClients[1], testConnector)
      revServer.login(usernames[0], roomname)
      revServer.login(usernames[1], roomname)

    it 'gamecancel', (done) ->
      usernames = ['testuser1', 'testuser2']
      roomname = 'testroom'
      testClients = [{id: "test1"}, {id: "test2"}] 
      count = 3

      check = ->
        done() if count-- <= 1

      testConnector.noticefunc = (client, type, data) ->
        console.log arguments
        switch type
          when 'gameStart'
            check()
          when 'gameEnd'
            data.reason.should.eql('GAME_CANCELED')
            check()

      revServer.register(usernames[0], testClients[0], testConnector)
      revServer.register(usernames[1], testClients[1], testConnector)
      revServer.login(usernames[0], roomname)
      revServer.login(usernames[1], roomname)
      revServer.logout(usernames[0], roomname)

  describe 'move', ->
    it 'move', (done) ->
      usernames = ['testuser1', 'testuser2']
      roomname = 'testroom'
      testClients = [{id: "test1"}, {id: "test2"}]
      nextTurnPlayer = null
      count = 2

      check = ->
        done() if count-- <= 1

      testConnector.noticeToGroupfunc = (groupname, type, data) ->
        groupname.should.eql(roomname)
        console.log arguments
        switch type
          when 'move'
            data.update.point.x.should.eql(3)
            data.update.point.y.should.eql(4)
            data.update.color.should.eql(Reversi.black)
            data.update.revPoints[0].x.should.eql(4)
            data.update.revPoints[0].y.should.eql(4)
            check()

      testConnector.noticefunc = (client, type, data) ->
        console.log arguments
        switch type
          when 'nextTurn'
            data.color.should.eql Reversi.white
            check()
          when 'gameStart'
            if data.color == Reversi.black
              nextTurnPlayer = data.username

      revServer.register(usernames[0], testClients[0], testConnector)
      revServer.register(usernames[1], testClients[1], testConnector)
      revServer.login(usernames[0], roomname)
      revServer.login(usernames[1], roomname)
      revServer.move(nextTurnPlayer, 3, 4)

    it 'gameEnd', (done) ->
      usernames = ['testuser1', 'testuser2']
      roomname = 'testroom'
      testClients =
        [{id: "test1", name: 'testuser1'},
        {id: "test2", name: 'testuser2'}]
      count = 3

      nextTurnPlayerName = null
      nonTurnPlayerName = null

      check =  ->
        if count-- <= 1
          done()
          # room = revServer.roomInfo(roomname)

      testConnector.noticeToGroupfunc = (groupname, type, data) ->
        groupname.should.eql(roomname)
        console.log arguments
        switch type
          when 'move'
            data.update.point.x.should.eql(3)
            data.update.point.y.should.eql(4)
            data.update.color.should.eql(Reversi.black)
            data.update.revPoints[0].x.should.eql(4)
            data.update.revPoints[0].y.should.eql(4)
            check()

      testConnector.noticefunc = (client, type, data) ->
        console.log arguments
        switch type
          when 'gameStart'

            if data.color == Reversi.black
              nextTurnPlayerName = data.username
            else
              nonTurnPlayerName = data.username

          when 'nextTurn'
            data.color.should.eql Reversi.white
          when 'gameEnd'
            switch client.name
              when nextTurnPlayerName
                data.color.should.eql Reversi.black
                data.issue.should.eql 'WIN'
              when nonTurnPlayerName
                data.color.should.eql Reversi.white
                data.issue.should.eql 'LOSE'
            data.black.should.eql(5)
            data.white.should.eql(0)
            check()

      revServer.register(usernames[0], testClients[0], testConnector, autoPass: true)
      revServer.register(usernames[1], testClients[1], testConnector, autoPass: true)
      revServer.login(usernames[0], roomname)
      revServer.login(usernames[1], roomname)

      revServer._rooms[roomname].board.board[5][5] = Reversi.black
      revServer.move(nextTurnPlayerName, 3, 4)

