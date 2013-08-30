ReversiBoard = require('./reversi')
ReversiRoom = require('./reversi-room')
machina = require('machina')()
machina_extensions = require('../lib/machina_extensions')

class ReversiServer
  constructor: () ->
    @clearMem()

  clearMem: ->
    @_rooms = {}
    @_users = {}
    @_connectors = []

  login: (username, roomname) ->
    player = @_users[username]
    room = @_rooms[roomname]
    unless room
      room = new ReversiRoom(roomname)
      @_rooms[roomname] = room
      @_onRoomEvent room

    try
      player.login room
      player.joinGroup roomname
    catch error
      console.log 'loginFailed'
      console.log error
      if player
        player.notice 'loginFailed',
          reason: error
    finally
      room.saveTime() if room

  logout: (username) ->
    player = @_users[username]
    room = player.room()

    try
      player.logout()
      room.emit 'sendEvents'
      player.leaveGroup room.name
      if room.isEmpty()
        @_offRoomEvent room
        delete @_rooms[room.name]

    catch error
      console.log 'logoutFailed'
      console.log error
      if player
        player.notice 'logoutFailed',
          reason: error
    finally
      room.saveTime() if room

  watchIn: (username, roomname) ->
    user = @_users[username]
    room = @_rooms[roomname]
    unless room
      room = new ReversiRoom(roomname)
      @_rooms[roomname] = room
      @_onRoomEvent room

    try
      user.watchIn room
      user.joinGroup roomname

    catch error
      console.log 'watchInFailed'
      console.log error
      if user
        user.notice 'watchInFailed',
          reason: error
    finally
      room.saveTime() if room

  watchOut: (username) ->
    user = @_users[username]
    room = user.room()

    try
      user.watchOut()
      user.leaveGroup room.name

      if room.isEmpty()
        @_offRoomEvent room
        delete @_rooms[room.name]
    catch error
      console.log 'watchOutFailed'
      console.log error
      if user
        user.notice 'watchOutFailed',
          reason: error
    finally
      room.saveTime() if room

  disconnect: (username) ->
    @logout(username)
    @watchOut(username)
    @_remove(username)

  move: (username, x, y) ->
    player = @_users[username]
    room = player.room()

    try
      player.move x, y
    catch error
      console.log 'moveFailed'
      console.log error
      player.notice 'failed move',
        reason: error
        #throw error
    finally
      player.notice 'move submitted'
      if room
        room.emit 'sendEvents' 
        room.saveTime()

  pass: (username) ->
    player = @_users[username]
    room = player.room()

    try
      player.pass()
    catch error
      console.log 'passFailed'
      console.log error
      player.notice 'failed pass',
        reason: error
    finally
      player.notice 'pass submitted'
      if room
        room.emit 'sendEvents' 
        room.saveTime()

  timeCheck: (username) ->
    time = new Date().getTime()
    player = @_users[username]
    player.timeCheck(time)

  registerConnector: (connector) ->
    @_connectors.push connector

  register: (username, client, connector, options) ->
    if @_users[username]
      connector.notice client, 'registerFailed',
        reason: "ALREADY EXIST NAME"
      throw new Error('alreadyExistName')
    @_users[username] = new Player(username, client, connector, options)

  _remove: (username) ->
    delete @_users[username]

  requestNoticeAll: (type, data) ->
    @_connectors.forEach (connector) ->
      connector.noticeAll(type, data)
   
  requestNoticeToGroup: (groupname, type, data) ->
    @_connectors.forEach (connector) ->
      connector.noticeToGroup(groupname, type, data)

  noticeRoomlist: (username) ->
    roomlist = @genRoomListForMsg()
    player = @_users[username]

    player.notice 'roomlist',
      roomlist: roomlist

  genRoomListForMsg: () ->
    for idx, val of @_rooms
      if val
        players = for p in val.players()
          p.name
        watchers = for p in val.watchers()
          p.name

        name: idx
        players: players
        watchers: watchers

  _onRoomEvent: (room) ->
    self = @

    room.on 'login', (player) ->
      console.log "event: login #{room.name} <- #{player.name}"
      self.requestNoticeAll 'login',
        roomname: room.name
        username: player.name

    room.on 'logout', (player) ->
      console.log "event: logout #{room.name} <- #{player.name}"
      self.requestNoticeAll 'logout',
        roomname: room.name
        username: player.name

    room.on 'watchIn', (player) ->
      console.log "event: watchIn #{room.name} <- #{player.name}"
      self.requestNoticeAll 'watchIn',
        roomname: room.name
        username: player.name

    room.on 'watchOut', (player) ->
      console.log "event: watchOut #{room.name} <- #{player.name}"
      self.requestNoticeAll 'watchOut',
        roomname: room.name
        username: player.name

    room.on 'gameStart', (res) ->
      players = for _, p of res.colors
        p.name

      console.log "event: gameStart #{room.name} #{players}"
      for colorname, player of res.colors
        player.notice 'gameStart',
          color: if colorname == 'black' then ReversiBoard.black else ReversiBoard.white
          username: player.name
          players: players
          time: res.time

      for w in res.watchers
        w.notice 'gameWatchStart',
          blackplayer: res.colors.black.name
          whiteplayer: res.colors.white.name

    room.on 'gameEnd', (res) ->
      console.log "event: gameEnd #{room.name}"
      for i in res.forPlayer
        i.player.notice 'gameEnd', i.result

      for i in res.forWatcher.watchers
        i.notice 'watchingGameEnd',
          res.forWatcher.result

    room.on 'move', (res) ->
      console.log "event: move #{res.player.name}"
      self.requestNoticeToGroup room.name, 'move',
        update: res.update
        username: res.player.name

    room.on 'allUpdates', (res) ->
      console.log "event: allUpdates #{res.toSend.name}"
      res.toSend.notice 'allUpdates',
        updates: res.updates
        blackplayer: res.black.name
        whiteplayer: res.white.name

    room.on 'pass', (res) ->
      console.log "event: pass #{res.player.name}"
      self.requestNoticeToGroup room.name, 'pass',
        username: res.player.name

    room.on 'autoPass', (res) ->
      console.log "event: autoPass #{room.name} #{res}"
      self.requestNoticeToGroup room.name, 'autoPass',
        count: res

    room.on 'nextTurn', (res) ->
      console.log "event: nextTurn #{res.turnPlayer.name} #{res.color}"
      res.turnPlayer.notice 'nextTurn',
        color: res.color

    room.on 'ack', (res) ->
      console.log "event: ack #{res.player.name} #{res.time}"
      res.player.notice 'ack', 
        time: res.time

    room.on 'sendEvents', ->
      console.log "event: sendEvents #{room.name}"
      self.requestNoticeToGroup room.name, 'sendEvents'

  _offRoomEvent: (room) ->
    room.off()

machina_get = () ->

Player = machina.Fsm.extend
  initialize: (@name, @client, @connector, @options) ->
    @options = @options || {}

  initialState: 'waiting'
  states:
    waiting:
      login: (room) ->
        @_room = @
        @_room = room.login @
        @transition('login')
      watchIn: (room) ->
        @_room = @
        @_room = room.watchIn @
        @transition('watching')

    login:
      room: -> @_room
      login: ->
        throw new Error('Double login')
      watchIn: ->
        throw new Error('Double login')
      watchOut: ->
        throw new Error('not watchIn')
      logout: ->
        room = @_room
        room.logout @
        @_room = null
        @transition('waiting')
      move: (x, y) ->
        @_room.move(@, x, y)
      pass: ->
        @_room.pass(@)
      timeCheck: (time)->
        @_room.timeCheck(@, time)

    watching:
      room: -> @_room
      login: ->
        throw new Error('Double login')
      logout: ->
        throw new Error('not login')
      watchOut: ->
        room = @_room
        room.watchOut @
        @_room = null
        @transition('waiting')

  login: (room) ->
    @handle('login', room)
  logout: ->
    @handle('logout')
  watchIn: (room) ->
    @handle('watchIn', room)
  watchOut: ->
    @handle('watchOut')
  move: (x, y) ->
    @handle('move', x, y)
  pass: ->
    @handle('pass')
  timeCheck: (time) ->
    @handle('timeCheck', time)

  get: ->
    machina_extensions.get.apply @, arguments

  room: ->
    @get('room')

  notice: (type, data) ->
    @connector.notice(@client, type, data)

  joinGroup: (groupname) ->
    @connector.joinGroup(@name, @client, groupname)

  leaveGroup: (groupname) ->
    @connector.leaveGroup(@name, @client, groupname)

module.exports = ReversiServer

