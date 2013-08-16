net = require('net')
Reversi = require('./reversi')

class TcpConnector
  constructor: (@operator) ->
    @operator.registerConnector @
    @groups = {}
    @clients = {}

  start: (@port) ->
    self = @
    @server = net.createServer (client) ->
      self.tcpResponse(client)
    @server.listen(@port)
    console.log("listening on port #{@port}")

  close: ->
    @server.close()

  tcpResponse: (socket) ->
    self = @
    client =
      socket: socket
      buffer: ""
      username: null

    console.log 'server -> tcp server created.'

    socket.on 'data', (data) ->
      console.log "server-> #{data}/ from: #{socket.remoteAddress}:#{socket.remotePort}"
      parseCmd = TcpConnector.parser(client.buffer, data.toString())
      client.buffer = parseCmd.buffer
      if parseCmd.success
        self.doCommand(parseCmd, client)

    socket.on 'close', ->
      console.log "server-> close connection #{socket.remoteAddress}:#{socket.remotePort}"
      self.operator.disconnect client.username if client.username


  doCommand: (com, client) ->
    switch com.command
      when 'OPEN'
        username = com.args[0]

        nameSplit = username.split(",") 
        console.log nameSplit
        roomname = if nameSplit.length > 1 then roomname = nameSplit[0] else username

        client.username = username
        @clients[username] = client
        @operator.register username, client, this,
          loseIlligalMove: true
        @operator.login username, roomname 

      when 'MOVE'
        if com.args[0] == "PASS"
          @operator.pass client.username
        else
          posChar = com.args[0]
          posCharX = posChar[0]
          posCharY = posChar[1]

          charParseArr = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']
          
          charIdx = charParseArr.indexOf(posCharX) + 1
          pos =
            x: charIdx
            y: parseInt(posCharY, 10)

          @operator.move client.username, pos.x, pos.y

  joinGroup: (username, client, groupname) ->
    @groups[groupname] = {} unless @groups[groupname]
    @groups[groupname][client.username] = client

  leaveGroup: (username, client, groupname) ->
    delete @groups[groupname][client.username]

  noticeAll: (type, data) ->
    for idx, val of @clients
      @notice(val, type, data) if val

  noticeToGroup: (groupname, type, data) ->
    for idx, val of @groups[groupname]
      @notice(val, type, data) if val

  notice: (client, type, data) ->
    username = client.username

    switch type
      when 'game standby'
        oppPlayer = data.players[1 - data.players.indexOf(username)]
        if username == data.nextTurnPlayer
          client.socket.write "START BLACK #{oppPlayer} 60000\n"
        else
          client.socket.write "START WHITE #{oppPlayer} 60000\n"
      when 'game update'
        unless username == data.username || data.isLastTurn
          ptstr = TcpConnector.convertPos(data.update.point.x, data.update.point.y)
          client.socket.write "MOVE #{ptstr}\n"
      when 'move submitted'
        if data.success
          client.socket.write "ACK 60000\n"
      when 'game end'
        if data.color == Reversi.black
          client.socket.write "END #{data.issue} #{data.black} #{data.white} DOUBLE_PASS\n"
        else
          client.socket.write "END #{data.issue} #{data.white} #{data.black} DOUBLE_PASS\n"
        client.socket.write "BYE\n"
        
  @parser: (buffer, str) ->
    constr = buffer + str
    spstr = constr.split("\n")

    if spstr.length > 1
      strArray = spstr[0].split(' ')

      success: true
      buffer: spstr[1]
      command: strArray[0]
      args: strArray.slice(1)
    else
      success: false
      buffer: constr

  @convertPos: (x, y) ->
    charParseArr = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']
    "#{charParseArr[x - 1]}#{y}"
        

module.exports = TcpConnector

      

