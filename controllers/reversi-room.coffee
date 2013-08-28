ReversiBoard = require('./reversi')
machina = require('machina')()
machina_extensions = require('../lib/machina_extensions')

STARTTIME = 60000
TIME_DEADLINE = -200

ReversiRoom = machina.Fsm.extend
  initialize: (@name) ->
    @board = null
    @_players = []
    @_watchers = []
    @colors = [ReversiBoard.black, ReversiBoard.white]
    @latestTime = undefined
    @leftTime = {}

  initialState: 'empty'
  states:
    empty:
      login: (player) ->
        @_addUser(player)

      watchIn: (player) ->
        @_addWatcher(player)
      
      watchOut: (player) ->
        @_removeWatcher(player)

      transitionCheck: ->
        if @_players.length >= 2
          @handle('goFull')
        else if @_players.length + @_watchers.length == 0
          @handle('goEmpty')
        else
          @handle('goWaiting')
      
      goWaiting: 'waiting'
      goFull: 'full'

    waiting:
      login: (player) ->
        @_addUser(player)

      logout: (player) ->
        @_removeUser(player)

      watchIn: (player) ->
        @_addWatcher(player)

      watchOut: (player) ->
        @_removeWatcher(player)
      
      transitionCheck: ->
        if @_players.length >= 2
          @handle('goFull')
        else if @_players.length + @_watchers.length == 0
          @handle('goEmpty')
        else
          @handle('goWaiting')
      
      goEmpty: 'empty'
      goFull: 'full'

    full:
      _onEnter: ->
        @transition('game')

      startGame: ->
        @_doStartGame()

      logout: (player) ->
        @_removeUser(player)

      watchIn: (player) ->
        @_addWatcher(player)

      watchOut: (player) ->
        @_removeWatcher(player)
      
      transitionCheck: ->
        if @_players.length >= 2
          @handle('goFull')
        else if @_players.length + @_watchers.length == 0
          @handle('goEmpty')
        else
          @handle('goWaiting')
      
      goWaiting: 'waiting'
      goEmpty: 'empty'

    game:
      _onEnter: ->

        @_suffleColor()
        blackplayer = @findPlayerByColor(ReversiBoard.black)
        whiteplayer = @findPlayerByColor(ReversiBoard.white)
        autoPassFlag =
          black: blackplayer.options.autoPass
          white: whiteplayer.options.autoPass

        @leftTime = {}
        @leftTime[blackplayer.name] = STARTTIME
        @leftTime[whiteplayer.name] = STARTTIME

        @board = new ReversiBoard(autoPassFlag)
        @emit 'gameStart',
          colors:
            black: blackplayer
            white: whiteplayer
          time: STARTTIME

      _onExit: ->
        @_stone = @board.countStone()

      cancelGame: ->
        @handle 'endGame', 'GAME_CANCELED',
          black: 'TIE'
          white: 'TIE'

      illegalEndGame: (illigalPlayer, reason) ->
        blackplayer = @findPlayerByColor(ReversiBoard.black)
        whiteplayer = @findPlayerByColor(ReversiBoard.white)
        @handle 'endGame', reason,
          black: if blackplayer.name == illigalPlayer.name then 'LOSE' else 'WIN'
          white: if whiteplayer.name == illigalPlayer.name then 'LOSE' else 'WIN'
       
      illegalCheck: (player, error) ->
        @handle('illegalEndGame', player, 'ILLIGAL_MOVE') if player.options.illigalMoveLose
        throw error

      timeCheck: (player, time) ->
        diff = @timeDiff(time)
        console.log "timeBefore: #{@latestTime}"
        console.log "timeAfter: #{time}"
        console.log "timeDiff: #{diff}"

        lTime = (@leftTime[player.name] || STARTTIME) - diff
        if lTime < TIME_DEADLINE
          @handle 'illegalEndGame', player, "TIME_UP"
          return
        else if lTime < 0
          lTime = 0

        @leftTime[player.name] = lTime
        @emit 'ack', 
          player: player
          time: lTime

      endGame: (@_reason, @_wlSpecial) ->
        @transition('gameEnd')

      logout: (player) ->
        @_removeUser(player)
      
      watchIn: (player) ->
        @_addWatcher(player)

      watchOut: (player) ->
        @_removeWatcher(player)
      
      move: (player, x, y) ->
        update = null
        autoPassCount = 0

        @board.once 'update', (res) ->
          update = res
        @board.on 'autoPass', ->
          autoPassCount++

        try
          @board.move(x, y, @getColor(player))
          @board.removeAllListeners()
          @_parseMoveResult player,
            update: update
            autoPassCount: autoPassCount
        catch error
          @board.removeAllListeners()
          @handle 'illegalCheck', player, error
          

      pass: (player) ->
        autoPassCount = 0

        @board.on 'autoPass', ->
          autoPassCount++

        try
          @board.pass(@getColor(player))
          @board.removeAllListeners()
          @_parseMoveResult player,
            autoPassCount: autoPassCount
        catch error
          @board.removeAllListeners()
          @handle 'illegalCheck', player, error

      transitionCheck: ->
        if @_players.length <= 2
          @handle('cancelGame')
        else if @_players.length + @_watchers.length == 0
          @handle('goEmpty')
      
      emitTurn: ->
        nextColor = @turnColor()
        nextTurnPlayer = @turnPlayer()
        @emit 'nextTurn',
          turnPlayer: nextTurnPlayer
          color: nextColor

      emitAllUpdates: (player) ->
        @emit 'allUpdates',
          toSend: player
          updates: @board.updateStack.list

      turnColor: ->
        @board.turn

      turnPlayer: ->
        @findPlayerByColor(@turnColor())

    gameEnd:
      _onEnter: ->
        @handle('gameResult')
        @emit 'gameEnd', @_result

      logout: (player) ->
        @_removeUser(player)

      gameResult: ->
        self = @

        playerResult = []
        @_players.forEach (player) ->
          playerResult.push
            player: player
            result: self.get('playerResult', player)
            
        @_result =
          forPlayer: playerResult
          forWatcher:
            watchers: @_watchers
            result:
              reason: @_reason
              black: @_stone.black
              white: @_stone.white

      playerResult: (player) ->
        userColor = @getColor(player)

        issue = null
        reason = null
        wl = new Array(2)

        if @_wlSpecial
          wl = [@_wlSpecial.white, @_wlSpecial.black]
        else
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
        
      transitionCheck: ->
        if @_players.length + @_watchers.length == 0
          @handle('goEmpty')
        else
          @handle('goWaiting')

      goWaiting: 'waiting'
      goEmpty: 'empty'

  _parseMoveResult: (player, result) ->
    if result.update
      @emit 'move',
        update: result.update
        player: player
    else
      @emit 'pass',
        player: player

    if result.autoPassCount > 0
      @emit 'autoPass', result.autoPassCount

    @handle('endGame', 'DOUBLE_PASS') if @board.isGameEnd()
    @handle('emitTurn')

    return @
  
  _suffleColor: ->
    if Math.random() > 0.5
      tmp = @colors[0]
      @colors[0] = @colors[1]
      @colors[1] = tmp

  _transitionCheck: ->
    if @_players.length >= 2
      @handle('goFull')
    else if @_players.length + @_watchers.length == 0
      @handle('goEmpty')
    else
      @handle('goWaiting')

  _nameValidation: (name) ->
    for arr in [@_players, @_watchers]
      for p in arr
        if p.name == name
          throw new Error('alreadyExistName')


  _addUser: (player) ->
    @_nameValidation()
    @_players.push player

    @emit 'login', player
    @handle 'transitionCheck'
    @
    
  _removeUser: (player) ->
    idx = @findIdxByName(@_players, player.name)
    if idx >= 0
      @_players.splice(idx, 1)

      @emit 'logout', player
      @handle 'transitionCheck'
      @
    else
      throw new Error('playerNotFound')

  _addWatcher: (player) ->
    @_nameValidation()
    @_watchers.push player
    @handle('goWaiting')

    @emit 'watchIn', player
    @handle 'emitAllUpdates', player
    @handle 'transitionCheck'
    @
    
  _removeWatcher: (player) ->
    idx = findIdxByName(@_watchers, player.name)
    if idx >= 0
      @_watchers.splice(idx, 1)

      @emit 'watchOut', player
      @handle 'transitionCheck'
      @
    else
      throw new Error('playerNotFound')
    
  getColor: (player) ->
    idx = @findIdxByName(@_players, player.name)
    return null if idx < 0 || idx > 1
    @colors[idx]

  findIdxByName: (array, name) ->
    for i, e of array
      return i if e.name == name
    return -1

  findPlayerByColor: (color) ->
    idx = @colors.indexOf(color)
    return null if idx < 0 || idx > 1
    @_players[idx]

  login: (player) ->
    @handle('login', player)
    @

  logout: (player) ->
    @handle('logout', player)
    @

  startGame: ->
    @handle('startGame')

  watchIn: (player) ->
    @handle('watchIn', player)
    @

  watchOut: (player) ->
    @handle('watchOut', player)
    @

  move: (player, x, y) ->
    @handle('move', player, x, y)
    @

  pass: (player) ->
    @handle('pass', player)
    @

  isEmpty: ->
    @state == 'empty'

  get: ->
    machina_extensions.get.apply @, arguments

  turnColor: ->
    @get('turnColor')

  turnPlayer: ->
    @get('turnPlayer')

  saveTime: ->
    @latestTime = new Date().getTime()

  timeDiff: (time) ->
    time - @latestTime

  timeCheck: (player, time) ->
    @handle('timeCheck', player, time)

  players: -> @_players
  watchers: -> @_watchers

module.exports = ReversiRoom


