ReversiBoard = require('./reversi')

class ReversiRoom
  constructor:  ->
    @state = 'waiting'
    @board = null
    @players = []
    @colors = [ReversiBoard.black, ReversiBoard.white]

  _addUser: (username) ->
    console.log "players: #{@players} (length: #{@players.length})"
    if @players.length < 2
      if @players.indexOf(username) < 0
        @players.push username
        return true
    false

  _removeUser: (username) ->
    console.log "players: #{@players} (length: #{@players.length})"
    if (idx = @players.indexOf(username)) >= 0
      @players.splice(idx, 1)
      console.log "players: #{@players} (length: #{@players.length})"
      return true
    false

  turnPlayer: () ->
    idx = @colors.indexOf(@board.turn)
    if idx > -1 
      @players[idx]
    else
      null

  isGameEnd: ->
    @board.isGameEnd()
  
  countStone: ->
    @board.countStone()

  startGame: () ->
    return false unless @state == 'waiting' && @players.length == 2
    @state = 'game'
    @board = new ReversiBoard()
    if Math.random() > 0.5
      tmp = @colors[0]
      @colors[0] = @colors[1]
      @colors[1] = tmp
    true

  cancelGame: () ->
    @state = 'waiting'

  putStone: (x, y, username) ->
    return null unless @state == 'game'
    console.log "putStone x: #{x}, y: #{y}, color: #{@getColor(username)}"

    @board.put(x, y, @getColor(username))

  getColor: (username) ->
    idx = @players.indexOf(username)
    return null if idx < 0 || idx > 1
    @colors[idx]

  findUserByColor: (color) ->
    idx = @colors.indexOf(color)
    return null if idx < 0 || idx > 1
    @players[idx]

  @login: (room, username, callback) ->
    if !room then room = new ReversiRoom
    success = room._addUser(username)

    if callback then callback(room, success)

  @logout: (room, username, callback) ->
    success = false
    if room
      success = room._removeUser(username)
      if room.players.length == 0 then room = undefined

    if callback then callback(room, success)

  @states: ['waiting', 'game']

class ReversiServer
  constructor: () ->
    @clearMem()
    
  start: (@_sockets) ->
    self = @

    @_sockets.on 'connection', (socket) ->
      self._userStates[socket.id] = state: 'waiting'

      socket.on 'room login', (name) ->
        console.log "received/login: #{name}, id: #{socket.id}"
        self.performLogin(name, socket)

      socket.on 'room logout', () ->
        console.log "received/logout (id: #{socket.id})"
        self.performLogout(socket)
 
      socket.on 'disconnect', ->
        if self._userStates[socket.id].state == 'login'
          console.log "automatically logout: #{socket.id}"
          self.performLogout(socket)

      socket.on 'game board put', (pt) ->
        room = self._userStates[socket.id].room
        color = if room then room.getColor(socket.id) else null
        console.log "put: #{pt.x}, #{pt.y}, #{color}"
        self.performPutStone(pt.x, pt.y, socket)

      socket.on 'request roomlist', () ->
        socket.emit('response roomlist', self.genRoomListForMsg())

  clearMem: ->
    @_roomList = {}
    @_userStates = {}

  performLogin: (name, socket) ->
    self = @
    usrst = @_userStates[socket.id]
    return if usrst && usrst.status == 'login'
    ReversiRoom.login @_roomList[name], socket.id, (room, success) ->
      self._roomList[name] = room

      if success
        console.log "done/login room: #{name}, id: #{socket.id}"
        socket.join(name)
        self._sockets.emit('notice login',
          username: ReversiServer.socketidMask socket.id
          roomname: name
        )
        self._userStates[socket.id] =
          state: 'login'
          room: room
          roomname: name

        if room.startGame()
          self._sockets.to(name).emit('game standby', name)
          self.sendTurnNotify(room)
      else
        console.log "fault/login room: #{name}, id: #{socket.id}"

  performLogout: (socket) ->
    self = @

    usrst = @_userStates[socket.id]
    return unless usrst.state == 'login'
    roomname = usrst.roomname

    ReversiRoom.logout @_roomList[roomname], socket.id, (room, success) ->
      self._roomList[roomname] = room

      if success
        console.log "done/logout room: #{roomname}, id: #{socket.id}"
        if room && room.state == 'game'
          room.cancelGame()
          self._sockets.to(roomname).emit('game cancel', roomname)

        socket.leave(roomname)
        self._sockets.emit 'notice logout',
          username: ReversiServer.socketidMask socket.id
          roomname: roomname

        self._userStates[socket.id] =
          state: 'waiting'
      else
        console.log "fault/logout room: #{roomname}, id: #{socket.id}"
 
  performPutStone: (x, y, socket) ->
    usrst = @_userStates[socket.id]
    console.log usrst.state
    if usrst.state == 'login'
      update = usrst.room.putStone(x, y, socket.id)
      console.log update
      console.log usrst.roomname
      @_sockets.to(usrst.roomname).emit('game board update', update) if update
      if usrst.room.isGameEnd()
        @performGameEnd(usrst.room)
      else if update
        @sendTurnNotify(usrst.room)
    socket.emit('game board submitted')

  performGameEnd: (room) ->
    self = @
    room.countStone()
    stone = room.countStone()
    console.log stone

    result = new Array(2)
    if stone.white > stone.black
      result = ['win', 'lose']
    else if stone.white < stone.black
      result = ['lose', 'win']
    else
      result = ['draw', 'draw']
    [ReversiBoard.white, ReversiBoard.black].forEach (e, i) ->
      self._sockets.socket(room.findUserByColor(e)).emit 'game result', 
        result: result[i]
        black: stone.black
        white: stone.white

  sendTurnNotify: (room) ->
    @_sockets.socket(room.turnPlayer()).emit('game turn', room.board.turn)

  genRoomListForMsg: () ->
    for idx, val of @_roomList
      name: idx
      players: val.players if val
      
  @socketidMask: (str) ->
    if str.length > 5 then str.slice(0, 4) + "*****" else str

module.exports = ReversiServer

