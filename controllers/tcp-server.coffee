net = require('net')

class TcpConnector
  constructor: (port) ->
    server = net.createServer tcpResponse
    server.listen(port)
    console.log('listening on port 3000')

  tcpResponse: (client) ->
    console.log 'server -> tcp server created.'

    client.on 'data', (data) ->
      console.log "server-> #{data}/ from: #{client.remoteAddress}:#{client.remotePort}"
      client

    client.on 'close', ->
      console.log "server-> close connection #{client.remoteAddress}:#{client.remotePort}"

  doCommand: (com, client) ->
    switch com.command
      when 'OPEN'
        username = com.args[0]

        nameSplit = username.split(",") 
        roomname = if nameSplit.length > 1 then roomname = nameSplit[0] else username

      when 'MOVE'
        posChar = com.args[0]
        posCharX = posChar[0]
        posCharY = posChar[1]

        charParseArr = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']
        
        charIdx = charParseArr.indexOf(posCharX) + 1
        pos =
          x: charIdx
          y: parseInt(posCharY, 10)

  @parser: (str) ->
    strArray = str.split(' ')

    command: strArray[0]
    args: strArray.slice(1)


      

      
      

