ReversiBoard = require('./reversi')
machina = require('machina')

class ReversiRoom
  constructor:  ->
    @state = 'waiting'
    @board = null
    @players = []
    @options = {}
    @illigalPlayer = null
    @illigalReason = null
    @colors = [ReversiBoard.black, ReversiBoard.white]

  _addUser: (username, options) ->
    if @players.length < 2
      if @players.indexOf(username) < 0
        @players.push username
        @options[username] = options
        return true
    false

  _removeUser: (username) ->
    if (idx = @players.indexOf(username)) >= 0
      @players.splice(idx, 1)
      delete @options[username]
      true
    else
      false

  turnPlayer: () ->
    return null unless @state == 'game'
    idx = @colors.indexOf(@board.turn)
    if idx > -1 
      @players[idx]
    else
      null

  isGameEnd: ->
    @board.isGameEnd()

  illigalMoveGameEnd: (username, reason) ->
    @illigalPlayer = username
    @illigalReason = reason
    @board.gameEnd()

  gameResult: ->
    self = @

    result = {}
    @players.forEach (username) ->
      result[username] = self.playerResult(username)
    result

  playerResult: (username) ->
    userColor = @getColor(username)
    stone = @board.countStone()

    issue = null
    reason = null
    if @illigalPlayer
      issue = if @illigalPlayer == username then 'LOSE' else 'WIN'
      reason = @illigalReason
    else
      wl = new Array(2)
      if stone.white > stone.black
        wl = ['WIN', 'LOSE']
      else if stone.white < stone.black
        wl = ['LOSE', 'WIN']
      else
        wl = ['TIE', 'TIE']

      idx = [ReversiBoard.white, ReversiBoard.black].indexOf(userColor)
      issue = wl[idx]
      reason = "DOUBLE_PASS"

    result =
      color: userColor
      issue: issue 
      reason: reason
      black: stone.black
      white: stone.white
  
  countStone: ->
    @board.countStone()

  startGame: () ->
    return false unless @state == 'waiting' && @players.length == 2
    @illigalPlayer = null
    @state = 'game'
    if Math.random() > 0.5
      tmp = @colors[0]
      @colors[0] = @colors[1]
      @colors[1] = tmp

    blackplayer = @findUserByColor(ReversiBoard.black)
    whiteplayer = @findUserByColor(ReversiBoard.white)

    # ap = @options[blackplayer].autoPass || @options[whiteplayer].autoPass
    autoPassFlag = 
      black: @options[blackplayer].autoPass
      white: @options[whiteplayer].autoPass

    @board = new ReversiBoard(autoPassFlag)

    true

  cancelGame: () ->
    @state = 'waiting'

  getColor: (username) ->
    idx = @players.indexOf(username)
    return null if idx < 0 || idx > 1
    @colors[idx]

  findUserByColor: (color) ->
    idx = @colors.indexOf(color)
    return null if idx < 0 || idx > 1
    @players[idx]

  move: (username, x, y) ->
    return null unless @state == 'game'
    result = @board.put(x, y, @getColor(username))

    update = if result then result.update else null
    autoPass = if result then result.autoPass else 0
    success = update != null
    gameEnd = @isGameEnd()
    @state = 'waiting' if gameEnd

    if !success && @options[username].illigalMoveLose
      @illigalMoveGameEnd(username,"ILLEGAL_MOVE")

    result =
      success: success 
      update: update
      autoPass: autoPass
      gameEnd: gameEnd
      nextTurnPlayer: @turnPlayer()
      nextColor: @board.turn

  pass: (username) ->
    return {success: false} unless @turnPlayer() == username
    result = @board.pass()
    gameEnd = @isGameEnd()
    @state = 'waiting' if gameEnd

    if !result.success && @options[username].illigalMoveLose
      @illigalMoveGameEnd(username, "ILLEGAL_MOVE")

    result =
      success: result.success
      autoPass: result.autoPass
      gameEnd: gameEnd
      nextTurnPlayer: @turnPlayer()
      nextColor: @board.turn


  _gameStartInfo: ->
    players: @players
    nextTurnPlayer: @turnPlayer()
    nextColor: @board.turn

  @login: (room, username, options, callback) ->
    if !room then room = new ReversiRoom
    success = room._addUser(username, options)
    isGameStart = room.startGame()
    status =
      success: success 
      gameStart: isGameStart
      gameInfo: room._gameStartInfo() if isGameStart

    callback(room, status) if callback

  @logout: (room, username, callback) ->
    success = false
    cancelflag = false
    if room
      success = room._removeUser(username)
      cancelflag = true if room.state == 'game'
      room = undefined if room.players.length == 0

    status = 
      success: success
      gameCancel: success && cancelflag

    room.cancelGame() if room && status.gameCancel 
    if callback then callback(room, status)

  @states: ['waiting', 'game']

class ReversiServer
  constructor: () ->
    @clearMem()

  clearMem: ->
    @_roomList = {}
    @_userInfo = {}
    @_connectors = []

  userInfo: (username) ->
    @_userInfo[username]
  
  roomInfo: (roomname) ->
    @_roomList[roomname]
 
  connectors: ->
    @_connectors

  registerConnector: (connector) ->
    @_connectors.push connector

  register: (username, client, connector, options) ->
    @_userInfo[username] =
      state: {type: 'waiting'}
      client: client
      connector: connector
      options: options || {}

  login: (username, roomname) ->
    self = @

    info = @_userInfo[username]
    return @fail(username, 'login failed') if info && info.state.type == 'login'
    maskedName = @maskName(username)

    ReversiRoom.login @_roomList[roomname], username, info.options, (room, status) ->
      self._roomList[roomname] = room

      if status.success
        self._userInfo[username].state = 
          type: 'login'
          roomname: roomname
        self.requestJoinGroup(username, roomname)

        self.requestNoticeAll 'login',
          username: maskedName
          roomname: roomname

        if status.gameStart
          self.requestNoticeToGroup roomname, 'game standby',
            roomname: roomname
            players: status.gameInfo.players
            nextTurnPlayer: status.gameInfo.nextTurnPlayer
            nextColor: status.gameInfo.nextColor
        console.log "done/login room: #{roomname}, id: #{username}"
      else
        self.fail(username, 'login failed')
        console.log "fault/login room: #{roomname}, id: #{username}"

  logout: (username) ->
    self = @

    info = @_userInfo[username]
    unless info && info.state.type == 'login'
      return self.fail(username, 'logout failed') 
    maskedName = @maskName(username)

    roomname = info.state.roomname
    ReversiRoom.logout @_roomList[roomname], username, (room, status) ->
      self._roomList[roomname] = room
      delete self._roomList[roomname] unless room

      if status.success
        self._userInfo[username].state =
          type: 'waiting'

        self.requestNoticeAll 'logout',
          username: maskedName
          roomname: roomname

        if status.gameCancel
          self.requestNoticeToGroup roomname, 'game cancel',
            roomname: roomname

        self.requestLeaveGroup(username, roomname)
        console.log "done/logout room: #{roomname}, id: #{username}"

      else
        self.fail(username, 'logout failed') 
        console.log "fault/logout room: #{roomname}, id: #{username}"

  disconnect: (username) -> @logout(username)

  move: (username, x, y) ->
    info = @_userInfo[username]
    return @moveResponseNotice(username, false) unless info
    switch info.state.type 
      when 'login'
        roomname = info.state.roomname
        room = @_roomList[roomname]
        
        result = if x && y then room.move(username, x, y) else room.pass(username)

        @moveResponseNotice(username, result.success)
        if result.success
          if result.update
            @requestNoticeToGroup roomname, 'game update',
              update: result.update
              username: username
              isLastTurn: result.gameEnd
          else
            @requestNoticeToGroup roomname, 'game pass',
              username: username
              isLastTurn: result.gameEnd

          if result.autoPass > 0
            @requestNoticeToGroup roomname, 'game autopass',
              username: username 
              isLastTurn: result.gameEnd

          if result.gameEnd
            @noticeGameEnd(roomname)
          else
            @requestNotice result.nextTurnPlayer, 'game turn',
              color: result.nextColor
      else
        @moveResponseNotice(username, false)
 
  pass: (username) ->
    @move(username, null, null)

  moveResponseNotice: (username, success) ->
    @requestNotice username, 'move submitted',
      success: success

  fail: (username, msg) ->
    @requestNotice username, msg

  noticeGameEnd: (roomname) ->
    room = @_roomList[roomname]
    results = room.gameResult()
    for username, result of results
      @requestNotice username, 'game end', 
        result

  requestNoticeAll: (type, data) ->
    @_connectors.forEach (connector) ->
      connector.noticeAll(type, data)
   
  requestNoticeToGroup: (groupname, type, data) ->
    @_connectors.forEach (connector) ->
      connector.noticeToGroup(groupname, type, data)

  requestNotice: (username, type, data) ->
    cinfo = @findConnectInfo(username)
    cinfo.connector.notice(cinfo.client, type, data)

  requestJoinGroup: (username, groupname) ->
    cinfo = @findConnectInfo(username)
    cinfo.connector.joinGroup(username, cinfo.client, groupname)

  requestLeaveGroup: (username, groupname) ->
    cinfo = @findConnectInfo(username)
    cinfo.connector.leaveGroup(username, cinfo.client, groupname)

  findConnectInfo: (username) ->
    client: @_userInfo[username].client
    connector: @_userInfo[username].connector

  noticeRoomlist: (username) ->
    roomlist = @genRoomListForMsg()
    @requestNotice username, 'roomlist',
      roomlist: roomlist

  genRoomListForMsg: () ->
    for idx, val of @_roomList
      if val
        name: idx
        players: val.players

  maskName: (username) ->
    info = @_userInfo[username]
    if info.options && info.options.maskName
      ReversiServer.genMaskName(username)
    else
      username

  @genMaskName: (str) ->
    if str.length > 5 then str.slice(0, 5) + "*****" else str

class ReversiServer
  login: (username, roomname) ->
    player = @_players[username]
    room = @_rooms[roomname]
    unless room
      room = new ReversiRoom(roomname)
      @_room[roomname] = room
      @_setEvRecv room

    try
      player.login room

      player.notice 'login',
        username: username
        roomname: roomname
    catch error
      player.notice 'failed login',
        reason: error
  logout: (username) ->
    player = @_players[username]

    try
      player.logout

      player.notice 'logout',
        username: username
    catch error
      player.notice 'failed logout',
        reason: error 
  move: (username, x, y) ->
    player = @_players[username]

  _setEvRecv: (room) ->
    room.on 'gameStart', (res) ->
      turnPlayer = res.turnPlayer

    room.on 'gameEnd', (res) ->

    room.on 'autoPass', (res) ->
      autoPassCount = res

    room.on 'nextTurn', (res) ->
      turnPlayer = res.turnPlayer
      color = res.color

Player = machina.Fsm.extend
  constructor: (@username, @client, @connector, @options) ->
    @options = @options || {}

  initialState: 'waiting'
  states:
    waiting: 
      login: (room) ->
        result = ReversiRoom.login room, @
        if result.success
          @_room = result.room 
          @transition('login')
        result
      beginWatch: (room) ->
        result = ReversiRoom.beginWatch room, @
        if result.success
          @_room = result.room 
          @transition('login')
        result

    login:
      room: -> @_room
      logout: ->
        result = ReversiRoom.logout @_room, @
        if result.success
          @_room = null
          @transition('waiting')
        result
      move: (x, y) ->
        @_room.move(@, x, y) 
      pass: ->
        @_room.pass(@)

    watching: 
      room: -> @_room
      endWatch: ->
        result = ReversiRoom.endWatch @_room, @
        if result.success
          @_room = null
          @transition('waiting')
        result

  login: (room) ->
    @handle('login', room)
  logout: ->
    @handle('logout')
  beginWatch: (room) ->
    @handle('beginWatch', room)
  endWatch: ->
    @handle('endWatch')
  room: ->
    @handle('room')





module.exports = ReversiServer

