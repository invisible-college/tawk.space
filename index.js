var bus = require('statebus').serve({file_store: false})
var serve = (route, file) => bus.http.get(route, (r, res) => res.sendFile(__dirname + file))

serve('/janus.js', '/janus.js')
serve('/hark.js',  '/node_modules/hark/hark.bundle.js')
serve('/',         '/index.html')
serve('/:id',      '/index.html')
