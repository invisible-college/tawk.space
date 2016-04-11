var fs = require('fs')
var bodyParser = require('body-parser');
var express = require('express');
var app = express();
app.use(bodyParser.json());
var creds = {
    key: fs.readFileSync('./certs/private-key'),
    cert: fs.readFileSync('./certs/certificate')
};
var http = require('http');
var httpsServer = require('https').createServer(creds, app);
var bus = require('statebus/server')();

bus.serve({port: 3003, client_definition: function(cbus) {cbus.route_defaults_to(bus)}})

app.use(express.static(__dirname + '/'));
app.use(express.static(__dirname + '/../janus-gateway/html/')); // for janus js api

app.get('/:id', function(req, res) {
  res.sendFile('index.html', {root: __dirname});
});

http.createServer(function (req, res) {
  // Forward to https
  res.writeHead(301, { "Location": "https://" + req.headers['host'] + req.url });
  res.end();
}).listen(80);

server = httpsServer.listen(443);

process.on('SIGTERM', closeAllTheThings);
process.on('SIGINT', closeAllTheThings);

function closeAllTheThings() {
  // Statebus data does not need to survive reboots (for now)
  fs.unlink('db');
  var deleteFolderRecursive = function(path) {
    if( fs.existsSync(path) ) {
      fs.readdirSync(path).forEach(function(file,index){
        var curPath = path + "/" + file;
        if(fs.lstatSync(curPath).isDirectory()) { // recurse
          deleteFolderRecursive(curPath);
        } else { // delete file
          fs.unlinkSync(curPath);
        }
      });
      fs.rmdirSync(path);
    }
  };
  deleteFolderRecursive('backups/')

  console.log("Bye!");
  process.exit();
}

