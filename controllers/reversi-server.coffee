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
      console.log "removed:: players: #{@players} (length: #{@players.length})"
      return true
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

  gameResult: ->
    self = @

    result = {}
    @players.forEach (username) ->
      result[username] = self.playerResult(username)
    result

  playerResult: (username) ->
    userColor = @getColor(username)
    stone = @board.countStone()

    wl = new Array(2)
    if stone.white > stone.black
      wl = ['win', 'lose']
    else if stone.white < stone.black
      wl = ['lose', 'win']
    else
      wl = ['draw', 'draw']

    idx = [ReversiBoard.white, ReversiBoard.black].indexOf(userColor)
      
    result =
      color: userColor
      issue: wl[idx]
      black: stone.black
      white: stone.white
  
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
    console.log "move x: #{x}, y: #{y}, color: #{@getColor(username)}"
    update = @board.put(x, y, @getColor(username))

    result =
      success: update != null
      update: update
      gameEnd: @isGameEnd()
      nextTurnPlayer: @turnPlayer()
      nextColor: @board.turn

  @login: (room, username, callback) ->
    if !room then room = new ReversiRoom
    status =
      success: room._addUser(username)
      gameStart: room.startGame()
      nextTurnPlayer: room.turnPlayer()
      nextColor: room.board.turn if room.board

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
      options: options

  login: (username, roomname) ->
    self = @

    info = @_userInfo[username]
    return @fail(username, 'login failed') if info && info.state.type == 'login'
    maskedName = @maskName(username)

    ReversiRoom.login @_roomList[roomname], username, (room, status) ->
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

          self.requestNotice status.nextTurnPlayer, 'game turn',
            color: status.nextColor
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
    switch info.state.type 
      when 'login'
        roomname = info.state.roomname
        room = @_roomList[roomname]

        result = room.move(username, x, y)

        if result.success
          @requestNoticeToGroup roomname, 'game update',
            result.update

          if result.gameEnd
            @noticeGameEnd(roomname)
          else
            @requestNotice result.nextTurnPlayer, 'game turn',
              color: result.nextColor
    @requestNotice username, 'move submitted',
      success: result.success

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
    cinfo.connector.joinGroup(cinfo.client, groupname)

  requestLeaveGroup: (username, groupname) ->
    cinfo = @findConnectInfo(username)
    cinfo.connector.leaveGroup(cinfo.client, groupname)

  findConnectInfo: (username) ->
    client: @_userInfo[username].client
    connector: @_userInfo[username].connector

  noticeRoomlist: (username) ->
    roomlist = @genRoomListForMsg()
    console.log roomlist
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

module.exports = ReversiServer

