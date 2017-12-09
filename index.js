var express = require('express')
var bus = require('statebus').serve({
    file_store: false
});

bus.http.get('/janus.js', (r,res) => {res.sendFile(__dirname+'/janus.js')})
bus.http.get('/hark.js', (r,res) => {res.sendFile(__dirname+'/node_modules/hark/hark.bundle.js')})

var homepage = (req, res) => res.sendFile(__dirname+'/index.html')
bus.http.get('/',    homepage)
bus.http.get('/:id', homepage)


