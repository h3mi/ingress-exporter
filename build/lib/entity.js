(function() {
  var Entity, createEntity, createFieldEntity, createLinkEntity, createPortalEntity, requestPortalDetail, request_done, request_max;

  request_max = 0;

  request_done = 0;

  Entity = GLOBAL.Entity = {
    counter: {
      portals: 0,
      fields: 0,
      links: 0
    },
    entityCount: 0,
    add: function(id, timestamp, data, callback) {
      if (Entity.entityCount % 100 === 0) {
        Database.db.collection('Portals').count({}, function(err, count) {
          return Entity.counter.portals = count;
        });
        Database.db.collection('Fields').count({}, function(err, count) {
          return Entity.counter.fields = count;
        });
        Database.db.collection('Links').count({}, function(err, count) {
          return Entity.counter.links = count;
        });
      }
      Entity.entityCount++;
      if (data.type === 'portal') {
        return createPortalEntity.apply(this, arguments);
      } else if (data.type === 'region') {
        return createFieldEntity.apply(this, arguments);
      } else if (data.type === 'edge') {
        return createLinkEntity.apply(this, arguments);
      } else {
        logger.warn("Unknown entity type, id=" + id + ", type=" + data.type);
        return callback && callback();
      }
    }
  };

  createEntity = function(collection, id, timestamp, data, callback) {
    data.time = timestamp;
    TaskManager.begin();
    return Database.db.collection(collection).update({
      _id: id
    }, {
      $set: data
    }, {
      upsert: true
    }, function(err) {
      callback && callback.apply(this, arguments);
      return TaskManager.end();
    });
  };

  createPortalEntity = function(id, timestamp, data, callback) {
    createEntity('Portals', id, timestamp, data, callback);
    if (data.team !== 'NEUTRAL') {
      return requestPortalDetail(id);
    }
    /*
    createEntity 'Portals', id, timestamp, data, ->
    
        # resolve agents
        if data.captured?
    
            Agent.resolve data.captured.capturingPlayerId
    
            for resonator in data.resonatorArray.resonators
    
                if not Utils.isSystemPlayer resonator.ownerGuid
    
                    Agent.resolve resonator.ownerGuid
                    
                    # consider ADA Reflector/Jarvis Virus?
                    Agent.resolved resonator.ownerGuid,
                        level: resonator.level
    
        callback && callback()
    */

  };

  createFieldEntity = function(id, timestamp, data, callback) {
    return createEntity('Fields', id, timestamp, data, callback);
  };

  createLinkEntity = function(id, timestamp, data, callback) {
    return createEntity('Links', id, timestamp, data, callback);
  };

  requestPortalDetail = function(guid) {
    TaskManager.begin();
    request_max++;
    return Request.unshift({
      action: 'getPortalDetails',
      data: {
        guid: guid
      },
      onSuccess: function(response) {
        return Database.db.collection('Portals').update({
          _id: guid
        }, {
          $set: response
        }, noop);
      },
      onError: function(err) {
        return logger.error("[Details] " + err);
      },
      afterResponse: function() {
        request_done++;
        logger.info("[Details] " + Math.round(request_done / request_max * 100).toString() + ("%\t[" + request_done + "/" + request_max + "]"));
        return TaskManager.end('Entity.requestPortalDetail.afterResponseCallback');
      }
    });
  };

}).call(this);
