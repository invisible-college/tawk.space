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

var bus = require('statebus/server')({
    file_store: false,
    port: 3004,
    client: function(cbus) {
    },
});

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

