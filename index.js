var express = require('express')
var bus = require('statebus/server')({
    full_node: true,
    file_store: false,
    client: function(cbus) {
    },
});

bus.http.use(express.static(__dirname + '/'))
bus.http.use(express.static(__dirname + '/../janus-gateway/html/'))

function sendIndexHtml(req, res) {
  res.sendFile('index.html', {root: __dirname});
}

bus.http.get('/:id', sendIndexHtml);

