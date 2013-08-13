// Generated by CoffeeScript 1.6.3
(function() {
  var ReversiClient, ReversiInterface, ReversiRule;

  ReversiRule = {
    white: -1,
    black: 1
  };

  ReversiInterface = (function() {
    var board, canKeyWait, _v;

    board = (function() {
      var _i, _len, _ref, _results;
      _ref = new Array(10);
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        _v = _ref[_i];
        _results.push(new Array(10));
      }
      return _results;
    })();

    canKeyWait = false;

    function ReversiInterface(target, id) {
      var i, linePosList, val, _i, _j, _len, _len1;
      this.canvas = cq(480, 480);
      this.canvas.strokeStyle('#333333');
      this.canvas.fillStyle('#00ff00').fillRect(0, 0, 480, 480);
      linePosList = [60, 120, 180, 240, 300, 360, 420, 480];
      for (i = _i = 0, _len = linePosList.length; _i < _len; i = ++_i) {
        val = linePosList[i];
        this.canvas.moveTo(val, 0);
        this.canvas.lineTo(val, 480);
        this.canvas.stroke();
      }
      for (i = _j = 0, _len1 = linePosList.length; _j < _len1; i = ++_j) {
        val = linePosList[i];
        this.canvas.moveTo(0, val);
        this.canvas.lineTo(480, val);
        this.canvas.stroke();
      }
      this.renderStone(4, 4, ReversiRule.white);
      this.renderStone(5, 5, ReversiRule.white);
      this.renderStone(4, 5, ReversiRule.black);
      this.renderStone(5, 4, ReversiRule.black);
      this.canvas.save();
      $(target).empty();
      this.canvas.appendTo(target);
      $(this.canvas.canvas).attr('id', id);
    }

    ReversiInterface.prototype.renderStone = function(x, y, color) {
      console.log("render: " + x + ", " + y + " (" + color + ")");
      if (!(x > 0 && x < 9 && y > 0 && y < 9)) {
        return null;
      }
      board[x][y] = color;
      if (color === ReversiRule.black) {
        this.canvas.fillStyle('#000000');
      } else if (color === ReversiRule.white) {
        this.canvas.fillStyle('#ffffff');
      }
      return this.canvas.beginPath().arc(x * 60 - 30, y * 60 - 30, 25, 0, Math.PI * 2, true).fill();
    };

    ReversiInterface.prototype.mouseEvent = function(screenx, screeny) {
      var canvasXY, putPos, px, py;
      console.log("mouseInputCan: " + canKeyWait);
      if (!canKeyWait) {
        return;
      }
      this.stopKeyWait();
      canvasXY = $(this.canvas.canvas).offset();
      px = (screenx - canvasXY.left) / 60;
      py = (screeny - canvasXY.top) / 60;
      putPos = {
        x: Math.ceil(px),
        y: Math.ceil(py)
      };
      console.log("position: (x: " + putPos.x + ", y: " + putPos.y + ")");
      if (this.client) {
        return this.client.sendCommand(putPos.x, putPos.y);
      }
    };

    ReversiInterface.prototype.applyUpdate = function(update) {
      var i, stone, _i, _len, _ref;
      this.renderStone(update.point.x, update.point.y, update.color);
      _ref = update.revPoints;
      for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
        stone = _ref[i];
        this.renderStone(stone.x, stone.y, update.color);
      }
      return this.canvas.save;
    };

    ReversiInterface.prototype.beginKeyWait = function() {
      return canKeyWait = true;
    };

    ReversiInterface.prototype.stopKeyWait = function() {
      return canKeyWait = false;
    };

    return ReversiInterface;

  })();

  ReversiClient = (function() {
    function ReversiClient(_interface, socket, name) {
      var self;
      this._interface = _interface;
      this.socket = socket;
      this.name = name;
      self = this;
      if (this._interface) {
        this._interface.client = this;
      }
      this.socket.on('game board update', function(res) {
        console.log(res);
        self._updateCallback(res);
        return self.updateLog(res);
      });
      this.socket.on('game board submitted', function() {
        return self._submittedCallback();
      });
      if (this._interface) {
        this._interface.beginKeyWait();
      }
    }

    ReversiClient.prototype.mouseEvent = function(screenx, screeny) {
      if (this._interface) {
        return this._interface.mouseEvent(screenx, screeny);
      }
    };

    ReversiClient.prototype.sendCommand = function(px, py) {
      console.log("put: (x: " + px + ", y: " + py + ")");
      return this.socket.emit('game board put', {
        x: px,
        y: py
      });
    };

    ReversiClient.prototype.updateLog = function(update) {
      var html;
      html = "<p>" + (update.color === ReversiRule.black ? "black" : "white") + ": ";
      html += "(" + update.point.x + ", " + update.point.y + ")</p>";
      return $(html).hide().prependTo('#chatlog').slideDown();
    };

    ReversiClient.prototype._updateCallback = function(res) {
      if (res && this._interface) {
        this._interface.applyUpdate(res);
        return this._interface.beginKeyWait();
      }
    };

    ReversiClient.prototype._submittedCallback = function() {
      if (this._interface) {
        return this._interface.beginKeyWait();
      }
    };

    ReversiClient.prototype.roomListRequest = function() {
      return this.socket.emit('request roomlist');
    };

    return ReversiClient;

  })();

  $(function() {
    var revClient, socket;
    socket = io.connect('http://localhost:3000');
    revClient = null;
    socket.on('loginRoomMsg', function(msg) {
      var html;
      html = "<p>login(room: " + msg.roomname + "): " + msg.username + "</p>";
      return $(html).hide().prependTo('#chatlog').slideDown();
    });
    socket.on('logoutRoomMsg', function(msg) {
      var html;
      html = "<p>logout(room: " + msg.roomname + "): " + msg.username + "</p>";
      return $(html).hide().prependTo('#chatlog').slideDown();
    });
    socket.on('game standby', function() {
      var revInterface;
      revInterface = new ReversiInterface("#reversi-space", "reversi-board");
      return revClient = new ReversiClient(revInterface, socket);
    });
    socket.on('game cancel', function() {
      var html;
      html = "<p>-- game canceled --</p>";
      $(html).hide().prependTo('#chatlog').slideDown();
      $('#reversi-board').off('click');
      return revClient = null;
    });
    socket.on('game turn', function(color) {
      var html;
      html = "<p>Your Turn: " + (color === ReversiRule.black ? 'black' : 'white') + "</p>";
      $(html).hide().prependTo('#chatlog').slideDown();
      return $('#reversi-board').on('click', function(event) {
        console.log("click: " + event.pageX + ", " + event.pageY);
        if (revClient) {
          return revClient.mouseEvent(event.pageX, event.pageY);
        }
      });
    });
    socket.on('response roomlist', function(res) {
      var html, idx, val, _results;
      _results = [];
      for (idx in res) {
        val = res[idx];
        html = "<p>" + val.name + ": " + val.players + "</p>";
        _results.push($(html).hide().prependTo('#chatlog').slideDown());
      }
      return _results;
    });
    $('#loginRoom').on('submit', function() {
      console.log("submit: " + $("#loginRoomName").val());
      socket.emit('room login', $('#loginRoomName').val());
      return $('#loginRoomName').val('');
    });
    $('#logoutRoom').on('submit', function() {
      console.log("logout submit");
      return socket.emit('room logout');
    });
    return socket.emit('request roomlist');
  });

}).call(this);
