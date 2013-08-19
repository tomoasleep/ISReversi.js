
machina = require('machina')

ReversiRoom = machina.Fsm.extend
  constructor: (@name) ->
    @board = null
    @_players = []
    @_watchers = []
    @colors = [ReversiBoard.black, ReversiBoard.white]
  initialState: 'empty'
  states:
    empty:
      login: (player) ->
        @_addUser(player)

      beginWatch: (player) ->
        @_addWatcher(player)
      
      goWaiting: 'waiting' 

    waiting:
      login: (player) ->
        @_addUser(player)

      logout: (player) ->
        @_removeUser(player)

      beginWatch: (player) ->
        @_addWatcher(player)

    game:
      _onEnter: ->
        @_suffleColor()
        blackplayer = @findPlayerByColor(ReversiBoard.black)
        whiteplayer = @findPlayerByColor(ReversiBoard.white)
        autoPassFlag = 
          black: @options[blackplayer].options.autoPass
          white: @options[whiteplayer].options.autoPass

        @board = new ReversiBoard(autoPassFlag)
        @emit 'gameStart', 
          turnPlayer: findPlayerByColor(ReversiBoard.black)

      logout: (player) ->
        @_removeUser(player)
      
      move: (player, x, y) ->
        @_parseMoveResult @board.put(x, y, @getColor(player))

      pass: (player) ->
        @_parseMoveResult @board.pass(@getColor(player))

      _onExit: ->
        @_stone = @board.countStone()
        @_result = @handle('gameResult')

    gameEnd:
      _onEnter: ->
        @emit 'gameEnd', @_result

      logout: (player) ->
        @_removeUser(player)

      gameResult: ->
        self = @

        result = {}
        @players.forEach (player) ->
          result[player.username] = self.handle('playerResult', player)
        result

      playerResult: (player) ->
        userColor = @getColor(username)

        issue = null
        reason = null
        if @_illigalPlayer
          issue = if @_illigalPlayer == username then 'LOSE' else 'WIN'
        else
          wl = new Array(2)
          if @_stone.white > @_stone.black
            wl = ['WIN', 'LOSE']
          else if @_stone.white < @_stone.black
            wl = ['LOSE', 'WIN']
          else
            wl = ['TIE', 'TIE']

          idx = [ReversiBoard.white, ReversiBoard.black].indexOf(userColor)
          issue = wl[idx]

        color: userColor
        issue: issue 
        reason: @_reason
        black: @_stone.black
        white: @_stone.white

  _parseMoveResult: (result) ->
    nextColor = @board.turn
    nextTurnPlayer = @turnPlayer()

    unless result.success
      @_endGame('ILLEGAL_MOVE', player) if player.options.illigalMoveLose
      throw 'illigalMove'

    if result.autoPass > 0
      @emit 'autoPass', result.autoPass

    @_endGame('DOUBLE_PASS') if @board.isGameEnd()

    if @state == 'game'
      @emit 'nextTurn',
        nextTurnPlayer: nextTurnPlayer
        nextColor: nextColor

    return @
  
  _endGame: (reason, illigalPlayer) ->
    @_illigalPlayer = illigalPlayer
    @_reason = reason
    @transition('gameEnd')

  _suffleColor: ->
    if Math.random() > 0.5
      tmp = @colors[0]
      @colors[0] = @colors[1]
      @colors[1] = tmp

  _addUser: (player) ->
    @_players.push username
    @handle('goWaiting')
    @transition('game') if @_players.length >= 2
    @
    
  _removeUser: (player) ->
    idx = @findIdxByName(@_players, player.name)
    if idx >= 0
      @_players.splice(idx, 1)
      @transition('waiting') if @_players.length < 2
      @
    else
      throw 'playerNotFound'

  _addWatcher: (player) ->
    @_watchers.push username
    @handle('goWaiting')
    @
    
  _removeWatcher: (player) ->
    idx = findIdxByName(@_watchers, player.name)
    if idx >= 0
      @_watchers.splice(idx, 1)
      @_emptyCheck()
      @
    else
      throw 'playerNotFound'
    
  _emptyCheck: ->
    if @_players.length + @_watchers.length == 0
      @transition('empty')
      
  getColor: (player) ->
    idx = @players.indexOf(player.username)
    return null if idx < 0 || idx > 1
    @colors[idx]

  findIdxByName: (array, username) ->
    for i, e of array
      return i if e.username == username
    return -1

  findPlayerByColor: (color) ->
    idx = @colors.indexOf(color)
    return null if idx < 0 || idx > 1
    @_players[idx]

  login: (player) ->
    @handle('login', player)

  logout: (player) ->
    @handle('logout', player)

  beginWatch: (player) ->
    @handle('beginWatch', player)

  endWatch: (player) ->
    @handle('endWatch', player)

ReversiRoom.login = (room, client) ->
  unless room then room = new ReversiRoom()
  room.login(client)

  room

ReversiRoom.logout = (room, client) ->
  room.logout(client)
  if room.state == 'empty'
    room = null

  room

ReversiRoom.beginWatch = (room, client) ->
  unless room then room = new ReversiRoom()
  room.beginWatch(client)

  room
    
ReversiRoom.endWatch = (room, client) ->
  room.endWatch(client)
  if room.state == 'empty'
    room = null

  room

    


