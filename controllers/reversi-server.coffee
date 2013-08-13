ReversiBoard = require('./reversi')

class ReversiRoom
  constructor: () ->

  state: 'waiting'
  board: null
  players: []
  colors: [ReversiBoard.black, ReversiBoard.white]

  _addUser: (username) ->
    if @players.length < 2
      if @players.indexOf(username) < 0
        @players.push username
        return true
    false

  _removeUser: (username) ->
    if @state == 'waiting' && @players.length < 2
      if (idx = @players.indexOf(username)) >= 0
        @players.splice(idx, 1)
        return true
    false

  turnPlayer: () ->
    idx = @colors.indexOf(@board.turn)
    @players[idx]

  startGame: () ->
    return false unless @state == 'waiting' && @players.length == 2
    @state = 'game'
    @board = new ReversiBoard()
    if Math.random() > 0.5
      tmp = @colors[0]
      @colors[0] = @colors[1]
      @colors[1] = tmp
    true

  putStone: (x, y, username) ->
    return null unless @state == 'game'
    console.log "putStone x: #{x}, y: #{y}, color: #{@getColor(username)}"

    @board.put(x, y, @getColor(username))

  getColor: (username) ->
    idx = @players.indexOf(username)
    return null if idx < 0 || idx > 1
    @colors[idx]

  @login: (room, username, callback) ->
    if !room then room = new ReversiRoom
    success = room._addUser(username)

    if callback then callback(room, success)

  @logout: (room, username, callback) ->
    success = false
    if room
      success = room._removeUser(username)
      if room.players.length = 0 then room = undefined

    if callback then callback(room, success)

  @states: ['waiting', 'game']

class ReversiServer
  constructor: () ->
    @_roomList = {}
    @_userStates = {}
    
  start: (@_sockets) ->
    self = @

    @_sockets.on 'connection', (socket) ->
      self._userStates[socket.id] = state: 'waiting'

      socket.on 'room login', (name) ->
        self.performLogin(name, socket)

      socket.on 'room logout', (name) ->
        self.performLogout(name, socket)
 
      socket.on 'disconnect', ->
        if self._userStates[socket.id].state == 'login'
          self.performLogout(self._userStates[socket.id].roomname, socket)

      socket.on 'game board put', (pt) ->
        room = self._userStates[socket.id].room
        color = if room then room.getColor(socket.id) else null
        console.log "put: #{pt.x}, #{pt.y}, #{color}"
        self.performPutStone(pt.x, pt.y, socket)

      socket.on 'request roomlist', () ->
        socket.emit('response roomlist', self.genRoomList())

  performLogin: (name, socket) ->
    self = @
    ReversiRoom.login @_roomList[name], socket.id, (room, success) ->
      self._roomList[name] = room

      if success
        socket.join(name)
        self._sockets.emit('loginRoomMsg', 
          username: ReversiServer.mask socket.id
          roomname: name
        )
        self._userStates[socket.id] =
          state: 'login'
          room: self._roomList[name]
          roomname: name

        if room.startGame()
          self._sockets.to(name).emit('game standby', name)
          self.sendTurnNotify(room)

  performLogout: (name, socket) ->
    self = @
    ReversiRoom.logout @_roomList[name], socket.id, (room, success) ->
      self._roomList[name] = room

      if success
        socket.leave(name)
        self._sockets.emit('logoutRoomMsg',
          username: ReversiServer.mask socket.id
          roomname: name
        )
        self._userStates[socket.id] =
          state: 'waiting'
 
  performPutStone: (x, y, socket) ->
    usrst = @_userStates[socket.id]
    console.log usrst.state
    if usrst.state == 'login'
      update = usrst.room.putStone(x, y, socket.id)
      console.log update
      console.log usrst.roomname
      @_sockets.to(usrst.roomname).emit('game board update', update) if update
      @sendTurnNotify(usrst.room)
    socket.emit('game board submitted')

  sendTurnNotify: (room) ->
      @_sockets.socket(room.turnPlayer()).emit('game turn', room.board.turn)
  

  genRoomList: () ->
    for idx, val of @_roomList
      name: idx
      players: val.players if val
      
  @mask: (str) ->
    if str.length > 5 then str.slice(0, 4) + "*****" else str

 
module.exports = ReversiServer

