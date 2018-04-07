const {expect} = require('chai');

describe('server', () => {
  let bus;
  beforeEach(() => {
    bus = require('statebus')();
    require('../index.js')(bus);
  });

  describe('chats_served', () => {
    it('should initially return 1000', () => {
      expect(bus.state.chats_served).to.be.equal(1000);
    });
 
    it('should not change when a connection is added', () => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      bus.save(conns);
      expect(bus.state.chats_served).to.be.equal(1000);
    });

    it('should not change when a connection changes groups', () => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      bus.save(conns);
      conns['some-id'] = {space: 'space1', group: 'group2'};
      bus.save(conns);
      expect(bus.state.chats_served).to.be.equal(1000);
    });

    it('should not change when a connection leaves but space is not empty', () => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      bus.save(conns);
      conns['id-2'] = {space: 'space1', group: 'group1'};
      bus.save(conns);
      delete conns['id-2'];
      bus.save(conns);
      expect(bus.state.chats_served).to.be.equal(1000);
    });

    it('should increment when connection leaves space', () => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      bus.save(conns);
      delete conns['some-id']
      bus.save(conns);
      expect(bus.state.chats_served).to.be.equal(1001);
    });

    it('should increment if connection changes spaces', () => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      bus.save(conns);
      conns['some-id'] = {space: 'space2', group: 'group1'};
      bus.save(conns);
      expect(bus.state.chats_served).to.be.equal(1001);
    });

    it('should increment even if connections are in other spaces', () => {
      conns = bus.fetch('connections');
      conns['some-id'] = {space: 'space1', group: 'group1'};
      bus.save(conns);
      conns['id-2'] = {space: 'space2', group: 'group1'};
      bus.save(conns);
      delete conns['id-2'];
      bus.save(conns);
      expect(bus.state.chats_served).to.be.equal(1001);
    });

    it('should not allow clients to save it', () => {
      // TODO figure out
      expect(true).to.be.equal(false);
    });
  });
});
