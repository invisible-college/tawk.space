const {expect} = require('chai');

describe('server', () => {
  let bus;
  beforeEach(() => {
    bus = require('statebus')();
    require('../index.js')(bus);
  });

  function saveAndWait(bus, obj, callback, ...callbackArgs) {
    bus.save(obj);
    // 5ms is reasonable for reactive functions to run
    setTimeout(callback, 5, callbackArgs);
  }

  describe('chats_served', () => {
    it('should initially return 0', () => {
      expect(bus.state.chats_served).to.be.equal(0);
    });
 
    it('should not change when a connection is added', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        expect(bus.state.chats_served).to.be.equal(0);
        done();
      });
    });

    it('should not change when only one connection joins and leaves a space', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        delete conns['some-id'];
        saveAndWait(bus, conns, () => {
          expect(bus.state.chats_served).to.be.equal(0);
          done();
        });
      });
    });

    it('should not change when multiple connections are added', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      conns['some-id-2'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        expect(bus.state.chats_served).to.be.equal(0);
        done();
      });
    });

    it('should not change when multiple connections change groups', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      conns['some-id-2'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        conns['some-id'] = {space: 'space1', group: 'group2'};
        conns['some-id-2'] = {space: 'space1', group: 'group3'};
        saveAndWait(bus, conns, () => {
          expect(bus.state.chats_served).to.be.equal(0);
          done();
        });
      });
    });

    it('should not change when a connection leaves but space is not empty', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        conns['some-id-2'] = {space: 'space1', group: 'group1'};
        saveAndWait(bus, conns, () => {
          delete conns['id-2'];
          saveAndWait(bus, conns, () => {
            expect(bus.state.chats_served).to.be.equal(0);
            done();
          });
        });
      });
    });

    it('should increment when multiple connections join and leave space', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        conns['some-id-2'] = {space: 'space1', group: 'group1'};
        saveAndWait(bus, conns, () => {
          delete conns['some-id']
          saveAndWait(bus, conns, () => {
            delete conns['some-id-2']
            saveAndWait(bus, conns, () => {
              expect(bus.state.chats_served).to.be.equal(1);
              done();
            });
          });
        });
      });
    });

    it('should increment when multiple connections change spaces', (done) => {
      // Also tests that reactive funk can handle multiple updates in one call
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      conns['some-id-2'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        conns['some-id'] = {space: 'space2', group: 'group1'};
        conns['some-id-2'] = {space: 'space3', group: 'group1'};
        saveAndWait(bus, conns, () => {
          expect(bus.state.chats_served).to.be.equal(1);
          done();
        });
      });
    });

    it('should increment even if connections are in other spaces', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      conns['some-id-2'] = {space: 'space1', group: 'group1'};
      conns['another-space-id'] = {space: 'space2', group: 'group1'};
      saveAndWait(bus, conns, () => {
        delete conns['some-id'];
        delete conns['some-id-2'];
        saveAndWait(bus, conns, () => {
          expect(bus.state.chats_served).to.be.equal(1);
          done();
        });
      });
    });

    it('should increment twice', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      conns['some-id-2'] = {space: 'space1', group: 'group1'};
      conns['another-space-id'] = {space: 'space2', group: 'group1'};
      conns['another-space-id-2'] = {space: 'space2', group: 'group1'};
      saveAndWait(bus, conns, () => {
        delete conns['some-id'];
        delete conns['some-id-2'];
        delete conns['another-space-id'];
        delete conns['another-space-id-2'];
        saveAndWait(bus, conns, () => {
          expect(bus.state.chats_served).to.be.equal(2);
          done();
        });
      });
    });

    it('should be unsavable', () => {
      bus.state.chats_served = 10;
      setTimeout(() => {
        // Saving is a noop
        expect(bus.state.chats_served).to.be.equal(0);
      }, 5);
    });
  });
});
