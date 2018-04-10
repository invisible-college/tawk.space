'use strict';

function get_spaces(conns) {
  // connections state on the server is different than the client.
  // It looks like {key: 'connections', '<random-hash>': {...}, '<another-hash>': {...}}
  const spaces = new Set();
  for (let connid in conns) {
    if (connid != 'key' && conns[connid].space !== undefined) {
      spaces.add(conns[connid].space);
    }
  }
  return spaces;
}

function set_difference(a, b) {
  return new Set([...a].filter(x => !b.has(x)));
}

function add_server_state(bus) {
  let previous_spaces = new Set();
  // If the db gets lost, restart this counter at 1000
  bus.state.chats_served = bus.state.chats_served || 1000;

  // TODO(karth295): This should be more efficient than
  // computing all spaces every time. Ideally when every
  // connection is added or removed we just update the data structures
  // to reflect the change from that one connection.
  bus.reactive(()=> {
    const new_spaces = get_spaces(bus.fetch('connections'));

    const diff = set_difference(previous_spaces, new_spaces);
    bus.state.chats_served += diff.size;

    previous_spaces = new_spaces;
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

