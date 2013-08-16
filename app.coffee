
###
Module dependencies.
###
express = require("express")
socketIO = require("socket.io")
http = require("http")
path = require("path")
ReversiServer = require("./controllers/reversi-server")
SocketIOConnector = require("./controllers/socketio-connector")
TcpConnector = require("./controllers/tcp-server")

app = express()
server = module.exports = http.createServer(app)
sioServer = module.exports.sioServer = socketIO.listen(server)

# all environments
app.set "port", process.env.PORT or 3000
app.set "tcp_port", process.env.TCP_PORT or 4000
app.set "url", process.env.SERVER_URL or "localhost"
app.set "views", __dirname + "/views"
app.set "view engine", "ejs"
app.use express.favicon()
app.use express.logger("dev")
app.use express.bodyParser()
app.use express.methodOverride()
app.use app.router
app.use express.static(path.join(__dirname, "public"))

# development only
app.use express.errorHandler()  if "development" is app.get("env")

app.get "/", (req, res) ->
  res.render "index", 
    url: app.get("url")
    port: app.get("port")
    tcp_port: app.get("tcp_port")

server.listen app.get("port"), ->
  console.log "Express server listening on port " + app.get("port")

revServer = module.exports.revServer = new ReversiServer()

sioConnector = module.exports.sioConnector = new SocketIOConnector(revServer)
sioConnector.start(sioServer.sockets)
tcpConnector = new TcpConnector(revServer)
tcpConnector.start(app.get "tcp_port")
