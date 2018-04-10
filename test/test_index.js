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
    it('should initially return 1000', () => {
      expect(bus.state.chats_served).to.be.equal(1000);
    });
 
    it('should not change when a connection is added', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        expect(bus.state.chats_served).to.be.equal(1000);
        done();
      });
    });

    it('should not change when a connection changes groups', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        conns['some-id'] = {space: 'space1', group: 'group2'};
        saveAndWait(bus, conns, () => {
          expect(bus.state.chats_served).to.be.equal(1000);
          done();
        });
      });
    });

    it('should not change when a connection leaves but space is not empty', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        conns['id-2'] = {space: 'space1', group: 'group1'};
        saveAndWait(bus, conns, () => {
          delete conns['id-2'];
          saveAndWait(bus, conns, () => {
            expect(bus.state.chats_served).to.be.equal(1000);
            done();
          });
        });
      });
    });

    it('should increment when connection leaves space', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        delete conns['some-id']
        saveAndWait(bus, conns, () => {
          expect(bus.state.chats_served).to.be.equal(1001);
          done();
        });
      });
    });

    it('should increment if connection changes spaces', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        conns['some-id'] = {space: 'space2', group: 'group1'};
        saveAndWait(bus, conns, () => {
          expect(bus.state.chats_served).to.be.equal(1001);
          done();
        });
      });
    });

    it('should increment even if connections are in other spaces', (done) => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      saveAndWait(bus, conns, () => {
        conns['id-2'] = {space: 'space2', group: 'group1'};
        saveAndWait(bus, conns, () => {
          delete conns['id-2'];
          saveAndWait(bus, conns, () => {
            expect(bus.state.chats_served).to.be.equal(1001);
            done();
          });
        });
      });
    });
  });
});
