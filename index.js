var express = require('express')
var bus = require('statebus').serve({
    file_store: false,
});

bus.http.use(express.static(__dirname + '/'))
bus.http.use(express.static(__dirname + '/../janus-gateway/html/'))

bus.http.get('/:id', function(req, res) {
  res.sendFile('index.html', {root: __dirname});
});

