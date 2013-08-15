
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

    @operator.register username, socket, self,
      maskName: true

    # self._userStates[socket.id] = state: 'waiting'

    socket.on 'room login', (roomname) ->
      # console.log "received/login: #{name}, id: #{socket.id}"
      self.operator.login username, roomname

    socket.on 'room logout', () ->
      # console.log "received/logout (id: #{socket.id})"
      self.operator.logout username

    socket.on 'disconnect', ->
      self.operator.disconnect username

    socket.on 'game move', (pt) ->
      self.operator.move username, pt.x, pt.y

    socket.on 'request roomlist', () ->
      self.operator.noticeRoomlist username

  joinGroup: (client, groupname) ->
    client.join(groupname)

  leaveGroup: (client, groupname) ->
    client.leave(groupname)

  noticeAll: (type, data) ->
    @notice(@_sockets, type, data)

  noticeToGroup: (groupname, type, data) ->
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

      when 'game turn'
        client.emit 'game turn',
          color: data.color

      when 'game standby'
        client.emit 'game standby',
          name: data.name

      when 'game cancel'
        client.emit 'game cancel',
          name: data.name

      when 'game update'
        client.emit 'game update',
          data
          # point: data.point
          # color: data.color
          # revPoints: data.revPoints
          
      when 'game end'
        client.emit 'game end',
          data
          # color: data.color
          # issue: data.issue
          # black: data.black
          # white: data.white

      when 'roomlist'
        client.emit 'roomlist',
          data.roomlist

      when 'move submitted'
        client.emit 'move submitted',
          success: data.success



module.exports = SocketIOConnector

