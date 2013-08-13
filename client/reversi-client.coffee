
ReversiRule =
  white : -1
  black : 1

# updateStones = {posPoint: Stone, revpoints: [Stone]}

class ReversiInterface
  board = (new Array(10) for _v in new Array(10))
  canKeyWait = false

  constructor: (target, @id) ->
    @canvas = cq(480, 480)
    @canvas.strokeStyle('#333333')
    @canvas.fillStyle('#00ff00').fillRect(0, 0, 480, 480)
    linePosList =  [60, 120, 180, 240, 300, 360, 420, 480]
    for val, i in linePosList
      @canvas.moveTo(val,0)
      @canvas.lineTo(val,480)
      @canvas.stroke()

    for val, i in linePosList
      @canvas.moveTo(0,val)
      @canvas.lineTo(480,val)
      @canvas.stroke()

    @renderStone(4, 4, ReversiRule.white)
    @renderStone(5, 5, ReversiRule.white)
    @renderStone(4, 5, ReversiRule.black)
    @renderStone(5, 4, ReversiRule.black)

    @canvas.save()
    $(target).empty()
    @canvas.appendTo(target)
    $(@canvas.canvas).attr('id', id)

  renderStone: (x, y, color) ->
    console.log("render: " + x + ", " + y + " (" + color + ")")
    return null unless x > 0 && x < 9 && y > 0 && y < 9
    board[x][y] = color

    if color == ReversiRule.black
      @canvas.fillStyle('#000000')
    else if color == ReversiRule.white
      @canvas.fillStyle('#ffffff')

    @canvas.beginPath().
      arc(x * 60 - 30, y * 60 - 30, 25, 0, Math.PI * 2, true).fill()

  mouseEvent: (screenx, screeny) ->
    console.log "mouseInputCan: #{canKeyWait}"
    return unless canKeyWait
    @stopKeyWait()

    canvasXY = $(@canvas.canvas).offset()
    px = (screenx - canvasXY.left) / 60
    py = (screeny - canvasXY.top) / 60

    putPos = x: Math.ceil(px), y: Math.ceil(py)
    console.log "position: (x: #{putPos.x}, y: #{putPos.y})"
    @client.sendCommand(putPos.x, putPos.y) if @client

  applyUpdate: (update) ->
    @renderStone(update.point.x, update.point.y, update.color)
    for stone, i in update.revPoints
      @renderStone(stone.x, stone.y, update.color)
    @canvas.save

  beginKeyWait: () -> canKeyWait = true
  stopKeyWait: () -> canKeyWait = false

class ReversiClient

  constructor: (@_interface, @socket, @name) ->
    self = @
    @_interface.client = @ if @_interface
    @_interface.beginKeyWait() if @_interface

  mouseEvent: (screenx, screeny) ->
    @_interface.mouseEvent(screenx, screeny) if @_interface

  sendCommand: (px, py) ->
    console.log "put: (x: #{px}, y: #{py})"
    @socket.emit('game board put', {x: px, y: py})

  updateLog: (update) ->
    html = "<p>#{if update.color == ReversiRule.black then "black" else "white" }: "
    html += "(#{update.point.x}, #{update.point.y})</p>"
    # update.revPoints.forEach (v) ->
    #   html += "<li>(#{v.x}, #{v.y})</li>"
    # html += "</p>"
    # console.log html
    $(html).hide().prependTo('#chatlog').slideDown()

  _updateCallback: (res) ->
    if res && @_interface
      @_interface.applyUpdate(res)
      @_interface.beginKeyWait()

  _submittedCallback: ->
    @_interface.beginKeyWait() if @_interface

  roomListRequest: ->
    @socket.emit('request roomlist')

  mouseEventOn: ->
    interfaceId = "##{@_interface.id}"
    self = @
    $(interfaceId).on 'click', (event) ->
      console.log ("click: " + event.pageX + ", " + event.pageY)
      self.mouseEvent(event.pageX, event.pageY)

  mouseEventOff: ->
    interfaceId = "##{@_interface.id}"
    $(interfaceId).off 'click'

$ ->
  socket = io.connect 'http://localhost:3000'
  revClient = null

  socket.on 'notice login', (msg) ->
    html = "<p>login(room: #{msg.roomname}): #{msg.username}</p>"
    $(html).hide().prependTo('#chatlog').slideDown()

  socket.on 'notice logout', (msg) ->
    html = "<p>logout(room: #{msg.roomname}): #{msg.username}</p>"
    $(html).hide().prependTo('#chatlog').slideDown()

  socket.on 'game standby', ->
    revInterface = new ReversiInterface "#reversi-space", "reversi-board"
    revClient = new ReversiClient(revInterface, socket)
    revClient.mouseEventOn()
    html = "<p>-- game start --</p>"
    $(html).hide().prependTo('#chatlog').slideDown()

  socket.on 'game cancel', ->
    html = "<p>-- game canceled --</p>"
    $(html).hide().prependTo('#chatlog').slideDown()
    revClient.mouseEventOff()
    revClient = null

  socket.on 'game result', (res) ->
    html = "<p>-- game end --</p>"
    $(html).hide().prependTo('#chatlog').slideDown()
    html = "<p>#{res.result}, black: #{res.black}, white: #{res.white}</p>"
    $(html).hide().prependTo('#chatlog').slideDown()
    revClient.mouseEventOff()
    revClient = null

  socket.on 'game turn', (color) ->
    html = "<p>Your Turn: #{if color == ReversiRule.black then 'black' else 'white'}</p>"
    $(html).hide().prependTo('#chatlog').slideDown()

  socket.on 'response roomlist', (res) ->
    for idx, val of res
      html = "<p>#{val.name}: #{val.players}</p>"
      $(html).hide().prependTo('#chatlog').slideDown()

  socket.on 'game board update', (res) ->
    console.log res
    return unless revClient
    revClient._updateCallback(res)
    revClient.updateLog(res)

  socket.on 'game board submitted', () ->
    revClient._submittedCallback() if revClient

  $('#loginRoom').on 'submit', ->
    console.log "submit: " + $("#loginRoomName").val()
    socket.emit 'room login', $('#loginRoomName').val()
    $('#loginRoomName').val('')

  $('#logoutRoom').on 'submit', ->
    console.log "logout submit"
    socket.emit 'room logout'

  $('#requestRoomList').on 'submit', ->
    socket.emit 'request roomlist'

  $('#deletelog').on 'submit', ->
    $('#chatlog').empty()

  socket.emit 'request roomlist'

# exports.ReversiClient = ReversiClient
# exports.ReversiInterface = ReversiInterface
  
