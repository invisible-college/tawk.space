'use strict';

function add_server_state(bus) {
  let previous_num_conns = 0;
  // If the db gets lost, restart this counter at 1000
  bus.state.chats_served = bus.state.chats_served || 1000;

  // This method intentionally does not work yet -- it does not
  // take into account that there are multiple spaces. Ideally
  // unit tests should catch this error!
  bus.reactive(()=> {
    // connections state on the server is different than the client.
    // It looks like {key: 'connections', '<random-hash>': {...}, '<another-hash>': {...}}
    // Object.keys(...) - 1 removes the extra non-connection key called "key"
    const num_conns = Object.keys(bus.fetch('connections')).length - 1;
    if (num_conns == 0 && previous_num_conns > 0) {
      bus.state.chats_served += 1;
    }
    previous_num_conns = num_conns;
  })();
}

function run_server(bus) {
  // Only store certain keys explicitly. Most keys like cursor position should not be saved.
  bus.serve({file_store: {prefix: 'chats_served'}})

  const serve = (route, file) => bus.http.get(route, (r, res) => res.sendFile(__dirname + file))

  serve('/janus.js', '/janus.js')
  serve('/hark.js',  '/node_modules/hark/hark.bundle.js')
  serve('/',         '/index.html')
  serve('/:id',      '/index.html')
}

if (require.main === module) {
  const bus = require('statebus')();
  bus.honk = false;

  add_server_state(bus);
  run_server(bus);
} else {
  // Imported as a library (for testing)
  module.exports = add_server_state;
}

