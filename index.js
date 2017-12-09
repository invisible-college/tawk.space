var bus = require('statebus').serve({file_store: false})
var serve = (x,y) => bus.http.get(x, (r, res) => res.sendFile(__dirname+y))

serve('/janus.js', '/janus.js')
serve('/hark.js',  '/node_modules/hark/hark.bundle.js')
serve('/',         '/index.html')
serve('/:id',      '/index.html')
