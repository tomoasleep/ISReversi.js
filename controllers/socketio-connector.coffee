Reversi = require('./reversi')

# connector:
#   need to implement:
#     joinGroup
#     leaveGroup
#     notice
#     noticeToGroup
#     noticeAll
class SocketIOConnector
  constructor: (@operator) ->
    @operator.registerConnector(@)

  start: (@_sockets) ->
    self = @
    @_sockets.on 'connection', (socket) ->
      self.connectResponse(socket)

  connectResponse: (socket) ->
    self = @
    username = socket.id

    try
      @operator.register username, socket, self,
        maskName: true
        autoPass: true
      # self._userStates[socket.id] = state: 'waiting'

      socket.on 'room login', (roomname) ->
        # console.log "received/login: #{name}, id: #{socket.id}"
        self.operator.login username, roomname

      socket.on 'room logout', () ->
        # console.log "received/logout (id: #{socket.id})"
        self.operator.logout username

      socket.on 'room watchIn', (roomname) ->
        # console.log "received/login: #{name}, id: #{socket.id}"
        self.operator.watchIn username, roomname

      socket.on 'room watchOut', () ->
        # console.log "received/logout (id: #{socket.id})"
        self.operator.watchOut username

      socket.on 'disconnect', ->
        self.operator.disconnect username

      socket.on 'game move', (pt) ->
        self.operator.move username, pt.x, pt.y

      socket.on 'request roomlist', () ->
        self.operator.noticeRoomlist username

    catch error
      console.log "tcpConnector: error occured: #{error}"
      socket.disconnect()

  joinGroup: (username, client, groupname) ->
    client.join(groupname)

  leaveGroup: (username, client, groupname) ->
    client.leave(groupname)

  noticeAll: (type, data) ->
    console.log "noticeAll: #{type}"
    @notice(@_sockets, type, data)

  noticeToGroup: (groupname, type, data) ->
    console.log "noticeToGroup: #{groupname} #{type}"
    @notice(@_sockets.to(groupname), type, data)

  notice: (client, type, data) ->
    switch type
      when 'login'
        client.emit 'notice login',
          username: data.username
          roomname: data.roomname

      when 'logout'
        client.emit 'notice logout',
          username: data.username
          roomname: data.roomname

      when 'watchIn'
        client.emit 'notice watchIn',
          username: data.username
          roomname: data.roomname

      when 'watchOut'
        client.emit 'notice watchOut',
          username: data.username
          roomname: data.roomname

      when 'nextTurn'
        client.emit 'game turn',
          color: data.color

      when 'gameStart'
        client.emit 'game standby'

        if data.color == Reversi.black
          console.log client
          client.emit 'game turn',
            color: data.color

      when 'gameWatchStart'
        client.emit 'game watchStart', data

      when 'watchingGameEnd'
        client.emit 'game watchEnd', data

      when 'gameEnd'
        if data.reason == 'GAME_CANCELED'
          client.emit 'game cancel'
        else
          client.emit 'game end',
            data
            # color: data.color
            # issue: data.issue
            # black: data.black
            # white: data.white

      when 'move'
        client.emit 'game update',
          data.update
          # point: data.point
          # color: data.color
          # revPoints: data.revPoints
          
      when 'allUpdates'
        client.emit 'game all updates',
          data

      when 'roomlist'
        console.log data.roomlist
        client.emit 'roomlist',
          data.roomlist

      when 'move submitted'
        client.emit 'move submitted'



module.exports = SocketIOConnector

