TcpConnector = require('../../controllers/tcp-connector')
net = require('net')
chai = require('chai')
chai.should()

class TestOperator
  registerConnector: ->

  register: ->
    @registerfunc.apply(@, arguments) if @registerfunc

  login: ->
    @loginfunc.apply(@, arguments) if @loginfunc

  move: ->
    @movefunc.apply(@, arguments) if @movefunc

  disconnect: ->
    @disconnectfunc.apply(@, arguments) if @disconnectfunc

port = 5000
describe 'TcpConnector', ->
  connector = null
  operator = null
  beforeEach ->
    operator = new TestOperator()
    connector = new TcpConnector(operator)
    connector.start(port)

  afterEach ->
    connector.close()

  it 'OPEN', (done) ->
    count = 0
    testuser = "testuser"
    
    check = ->
      if count++ > 0
        client.end()
        done() 

    client = net.createConnection port: port, ->
      console.log arguments
      check()
      client.write("OPEN #{testuser}\n")

    operator.loginfunc = (username, roomname) ->
      username.should.eql testuser
      roomname.should.eql testuser
      check()

  it 'game standby', (done) -> 
    count = 0
    testuser = "testuser"
    
    check = ->
      if count++ > 0
        socket.end()
        done() 

    socket = net.createConnection port: port, ->
      client = 
        socket: socket
        username: testuser
      check()
      socket.write("OPEN #{testuser}\n")

    operator.registerfunc = (username, client) ->
      connector.notice client, 'game standby',
        players: ["testuser", "dummyuser"]
        nextTurnPlayer: "testuser" 

    socket.on 'data', (data) ->
      console.log data.toString()
      data.toString().should.eql("START BLACK dummyuser 60000\n")
      check()

  it 'game update', (done) -> 
    count = 0
    testuser = "testuser"
    
    check = ->
      if count++ > 0
        socket.end()
        done() 

    socket = net.createConnection port: port, ->
      client = 
        socket: socket
        username: testuser
      check()
      socket.write("OPEN #{testuser}\n")

    operator.registerfunc = (username, client) ->
      connector.notice client, 'game update',
        username: 'testuser'
        update: 
          point:
            x: 7
            y: 2

      connector.notice client, 'game update',
        username: 'dummyuser'
        update: 
          point:
            x: 3
            y: 5

    socket.on 'data', (data) ->
      data.toString().should.eql("MOVE C5\n")
      check()
    





