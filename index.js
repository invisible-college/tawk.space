'use strict';

function get_spaces_with_size(conns) {
  // connections state on the server is different than the client.
  // It looks like {key: 'connections', '<random-hash>': {...}, '<another-hash>': {...}}
  const spaces = new Map();
  for (let connid in conns) {
    if (connid != 'key' && conns[connid].space !== undefined) {
      const space = conns[connid].space;
      spaces.set(space, (spaces.get(space) || 0) + 1);
    }
  }
  return spaces;
}

function add_server_state(bus) {
  const real_spaces = new Set();

  // TODO(karth295): This should be more efficient than
  // computing all spaces every time. Ideally when every
  // connection is added or removed we just update the data structures
  // to reflect the change from that one connection.
  bus('chats_served').to_fetch = (old) => {
    let new_chats_served = old._ || 0;

		const spaces_with_size = get_spaces_with_size(bus.fetch('connections'));
    for (let [space, size] of spaces_with_size) {
      if (size >= 2) {
        // Consider a space a real "chat" if it has multiple people
        real_spaces.add(space);
      }
    }

    // Increment counter if a space that had multiple people at some point
    // is now empty.
    for (let real_space of real_spaces) {
      if (!spaces_with_size.has(real_space)) {
        real_spaces.delete(real_space);
        new_chats_served += 1;
      }
    }

		return {_: new_chats_served};
  };
  bus('chats_served').to_save = function noop(){};

  // Run the fetch function so that it reactively runs every time connections are updated
  const ignore = bus.state.chats_served
}

function run_server(bus) {
  // Only store certain keys explicitly. Most keys like cursor position should not be saved.
  bus.serve({file_store: {prefix: 'chats_served'}})

  const serve = (route, file) => bus.http.get(route, (r, res) => res.sendFile(__dirname + file))

  serve('/favicon.ico', '/favicon.ico')
  serve('/logo.jpg', '/logo.jpg')
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
