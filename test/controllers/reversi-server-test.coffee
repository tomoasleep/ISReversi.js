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
  
  it 'registerConnector', ->
    revServer.connectors().length.should.eql(1)

  it 'register', ->
    username = 'testuser'
    testClient = 
      id: "test"

    revServer.register(username, testClient, testConnector)

    info = revServer.userInfo(username)

    info.state.type.should.eql('waiting')
    info.client.should.eql(testClient)
    info.connector.should.eql(testConnector)

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
      count = 0

      testConnector.noticeAllfunc = (type, data) ->
        type.should.eql 'login'
        data.username.should.eql username
        data.roomname.should.eql roomname
        done() if count++ > 0

      testConnector.noticefunc = (client, type, data) ->
        client.should.eql testClient
        type.should.eql 'login failed'
        done() if count++ > 0

      revServer.register(username, testClient, testConnector)
      revServer.login(username, roomname)
      revServer.login(username, roomname2)

  describe 'logout', ->
    it 'login and logout', (done) ->
      username = 'testuser'
      roomname = 'testroom'
      testClient = 
        id: "test"
      count = 0

      testConnector.noticeAllfunc = (type, data) ->
        switch type
          when 'login'
            data.username.should.eql username
            data.roomname.should.eql roomname
            count++
          when 'logout'
            data.username.should.eql username
            data.roomname.should.eql roomname
            done() if count++ > 0

      revServer.register(username, testClient, testConnector)
      revServer.login(username, roomname)
      revServer.logout(username, roomname)
    it 'cannot logout before login', (done) ->
      username = 'testuser'
      roomname = 'testroom'
      testClient = 
        id: "test"
      count = 0

      testConnector.noticefunc = (client, type, data) ->
        type.should.eql 'logout failed'
        done() 

      revServer.register(username, testClient, testConnector)
      revServer.logout(username, roomname)

  describe 'gamestart', ->
    it 'gamestart', (done) ->
      usernames = ['testuser1', 'testuser2']
      roomname = 'testroom'
      testClients = [{id: "test1"}, {id: "test2"}] 
      count = 0

      check = ->
        done() if count++ > 1

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

      testConnector.noticeToGroupfunc = (groupname, type, data) ->
        console.log arguments
        switch type
          when 'game standby'
            data.roomname.should.eql roomname
            data.nextColor.should.eql Reversi.black
            check()

      revServer.register(usernames[0], testClients[0], testConnector)
      revServer.register(usernames[1], testClients[1], testConnector)
      revServer.login(usernames[0], roomname)
      revServer.login(usernames[1], roomname)

    it 'gamecancel', (done) ->
      usernames = ['testuser1', 'testuser2']
      roomname = 'testroom'
      testClients = [{id: "test1"}, {id: "test2"}] 
      count = 0

      check = ->
        room = revServer.roomInfo(roomname)
        room.state.should.eql 'waiting'
        done()

      testConnector.noticeToGroupfunc = (groupname, type, data) ->
        switch type
          when 'game standby'
            data.roomname.should.eql roomname
            check() if count++ > 0
          when 'game cancel'
            data.roomname.should.eql roomname
            check() if count++ > 0

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
      count = 0

      check = ->
        done() if count++ > 1

      testConnector.noticeToGroupfunc = (groupname, type, data) ->
        groupname.should.eql(roomname)
        switch type
          when 'game standby'
            data.roomname.should.eql roomname
            data.nextColor.should.eql Reversi.black
            revServer.move(data.nextTurnPlayer, 3, 4)
            check()
          when 'game update'
            data.update.point.x.should.eql(3)
            data.update.point.y.should.eql(4)
            data.update.color.should.eql(Reversi.black)
            data.update.revPoints[0].x.should.eql(4)
            data.update.revPoints[0].y.should.eql(4)
            check()

      testConnector.noticefunc = (client, type, data) ->
        switch type
          when 'game turn'
            data.color.should.eql Reversi.white
          when 'move submitted'
            data.success.should.eql true
            check()

      revServer.register(usernames[0], testClients[0], testConnector)
      revServer.register(usernames[1], testClients[1], testConnector)
      revServer.login(usernames[0], roomname)
      revServer.login(usernames[1], roomname)

    it 'gameEnd', (done) ->
      usernames = ['testuser1', 'testuser2']
      roomname = 'testroom'
      testClients = [{id: "test1"}, {id: "test2"}] 
      count = 0

      turnPlayer = new Array(2)

      check =  ->
        if count++ > 1
          done()
          # room = revServer.roomInfo(roomname)

      testConnector.noticeToGroupfunc = (groupname, type, data) ->
        groupname.should.eql(roomname)
        switch type
          when 'game standby'
            room = revServer.roomInfo(roomname)

            data.nextColor.should.eql Reversi.black
            turnPlayer[0] = if data.nextTurnPlayer == 'testuser1' then 0 else 1
            turnPlayer[1] = 1 - turnPlayer[0]

            room.board.board[5][5] = Reversi.black
            revServer.move(data.nextTurnPlayer, 3, 4)
          when 'game update'
            data.update.point.x.should.eql(3)
            data.update.point.y.should.eql(4)
            data.update.color.should.eql(Reversi.black)
            data.update.revPoints[0].x.should.eql(4)
            data.update.revPoints[0].y.should.eql(4)
            check()

      testConnector.noticefunc = (client, type, data) ->
        switch type
          when 'game turn'
            data.color.should.eql Reversi.white
          when 'game end'
            switch client.id
              when testClients[turnPlayer[0]].id
                data.color.should.eql Reversi.black
                data.issue.should.eql 'WIN'
              when testClients[turnPlayer[1]].id
                data.color.should.eql Reversi.white
                data.issue.should.eql 'LOSE'
            data.black.should.eql(5)
            data.white.should.eql(0)
            check()

      revServer.register(usernames[0], testClients[0], testConnector, autoPass: true)
      revServer.register(usernames[1], testClients[1], testConnector, autoPass: true)
      revServer.login(usernames[0], roomname)
      revServer.login(usernames[1], roomname)

