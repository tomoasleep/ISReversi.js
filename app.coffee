
###
Module dependencies.
###
express = require("express")
socketIO = require("socket.io")
http = require("http")
path = require("path")
ReversiServer = require("./controllers/reversi-server")

app = express()
server = module.exports = http.createServer(app)
sioServer = socketIO.listen(server)

# all environments
app.set "port", process.env.PORT or 3000
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
  res.render "index"

server.listen app.get("port"), ->
  console.log "Express server listening on port " + app.get("port")

revServer = module.exports.revServer = new ReversiServer()
revServer.start(sioServer.sockets)

