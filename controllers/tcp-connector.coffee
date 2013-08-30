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
      eventStocks: {}

    console.log 'server -> tcp server created.'

    socket.on 'data', (data) ->
      try
        console.log "server<- #{data}/ from: #{socket.remoteAddress}:#{socket.remotePort}"
        parseCmd = TcpConnector.parser(client.buffer, data.toString())
        client.buffer = parseCmd.buffer
        if parseCmd.success
          self.doCommand(parseCmd, client)
      catch error
        console.log "tcpConnector: error occured: #{error}"
        socket.end()


    socket.on 'close', ->
      console.log "server -/- close connection #{socket.remoteAddress}:#{socket.remotePort}"
      self.operator.disconnect client.username if client.username
    
    socket.on 'error', ->
      console.log "error occured"
      self.operator.disconnect client.username if client.username
      socket.end()

  doCommand: (com, client) ->
    switch com.command
      when 'OPEN'

        nameSplit = com.args[0].split(":") 
        console.log nameSplit
        roomname = if nameSplit.length > 1 then nameSplit[0] else nameSplit[0]
        username = if nameSplit.length > 1 then nameSplit[1] else nameSplit[0]

        client.username = username
        @clients[username] = client
        @operator.register username, client, this,
          illigalMoveLose: true
          autoPass: false
        @operator.login username, roomname

      when 'MOVE'
        @operator.timeCheck(client.username)
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
    @groups[groupname][username] = client

  leaveGroup: (username, client, groupname) ->
    if @groups[groupname][username]
      g = @groups[groupname]
      delete g[username]

  noticeAll: (type, data) ->
    for idx, val of @clients
      @notice(val, type, data) if val

  noticeToGroup: (groupname, type, data) ->
    for idx, val of @groups[groupname]
      @notice(val, type, data) if val

  notice: (client, type, data) ->
    username = client.username
    eventStocks = client.eventStocks

    switch type
      when 'gameStart'
        oppPlayer = data.players[1 - data.players.indexOf(username)]
        if data.color == Reversi.black
          @socketWrite client, "START BLACK #{oppPlayer} #{data.time}\n"
        else
          @socketWrite client, "START WHITE #{oppPlayer} #{data.time}\n"
      when 'ack'
        @socketWrite client, "ACK #{data.time}\n"
      when 'move'
        console.log "stock: MOVE #{username} #{data}"
        eventStocks.move = data
      when 'pass'
        console.log "stock: PASS #{username} #{data}"
        eventStocks.pass = data
      when 'autoPass'
        console.log "stock: AUTOPASS #{username} #{data}"
        eventStocks.autoPass = data
      when 'sendEvents'
        emitMove = true
        emitPass = true
        emitAutoPass = true
        isMyTurn = false

        if eventStocks.gameEnd
          if eventStocks.autoPass
            emitAutoPass = false
          else
            emitMove = false
            emitPass = false
        
        if eventStocks.move && emitMove
          sdata = eventStocks.move
          if username == sdata.username
            isMyTurn = true
          else
            ptstr = TcpConnector.convertPos(sdata.update.point.x, sdata.update.point.y)
            @socketWrite client, "MOVE #{ptstr}\n"

        if eventStocks.pass && emitPass
          sdata = eventStocks.pass
          if username == sdata.username
            isMyTurn = true
          else
            @socketWrite client, "MOVE PASS\n"

        if eventStocks.autoPass && emitAutoPass
          sdata = eventStocks.autoPass
          if isMyTurn && sdata.count >= 1
            @socketWrite client, "MOVE PASS\n"


        if eventStocks.gameEnd
          sdata = eventStocks.gameEnd
          if sdata.color == Reversi.black
            @socketWrite client, "END #{sdata.issue} #{sdata.black} #{sdata.white} #{sdata.reason}\n"
          else
            @socketWrite client, "END #{sdata.issue} #{sdata.white} #{sdata.black} #{sdata.reason}\n"
          client.socket.write "BYE\n"

        client.eventStocks = {}
      when 'gameEnd'
        eventStocks.gameEnd = data
      when 'registerFailed'
        @socketWrite client, "ERROR REGISTER_FAILED #{data.reason}"

  socketWrite: (client, msg) ->
    console.log "server-> #{msg}/ to: #{client.socket.remoteAddress}:#{client.socket.remotePort}"
    client.socket.write msg
        
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

      

