async = require 'async'

TEAM_ENLIGHTENED = 1
TEAM_RESISTANCE = 2

StrTeamMapping = 
    ENLIGHTENED: TEAM_ENLIGHTENED
    RESISTANCE:  TEAM_RESISTANCE

Agent = GLOBAL.Agent = 
    
    data: {}

    initFromDatabase: (callback) ->

        Database.db.collection('Agent').find().toArray (err, agents) ->

            # ignore error
            
            Agent.data[agent._id] = agent for agent in agents if agents
            callback && callback()

    strToTeam: (val) ->

        StrTeamMapping[val]

    resolveFromPortalDetail: (portal, callback) ->

        return callback() if not portal.team?

        agentTeam = Agent.strToTeam portal.team

	return callback() if typeof portal.resonators is 'undefined'

        async.each portal.resonators, (resonator, callback) ->

            if resonator isnt null
                
                Agent.resolved resonator.owner,
                    level: resonator.level
                    team:  agentTeam
                , callback

            else
                callback()
        
        , callback

    resolved: (agentId, data, callback) ->

        # name has been resolved as agentId
        # data: team, level

        need_update = false

        if not Agent.data[agentId]?
            need_update = true
            Agent.data[agentId] = 
                team:             null
                level:            0
                inUpdateProgress: false

        if data.team? and Agent.data[agentId].team isnt data.team
            need_update = true
            Agent.data[agentId].team = data.team

        if data.level? and Agent.data[agentId].level < data.level
            need_update = true
            Agent.data[agentId].level = data.level

        if need_update and not Agent.data[agentId].inUpdateProgress
            
            Agent.data[agentId].inUpdateProgress = true

            Database.db.collection('Agent').update
                _id: agentId
            ,
                $set:
                    team:   Agent.data[agentId].team
                    level:  Agent.data[agentId].level
            ,
                upsert: true
            , (err) ->

                Agent.data[agentId].inUpdateProgress = false
                callback && callback()

        else

            callback()
        
    _resolveDatabase: (callback) ->

        Database.db.collection('Portals').find(
            team:
                $ne: 'NEUTRAL'
            resonators:
                $exists: true
        ,
            resonators: true
            team: true
        ).toArray (err, portals) ->

            if err
                logger.error '[AgentResolver] Failed to fetch portal list: %s', err.message
                return callback()

            # TODO: reduce memory usage
            if portals?
                async.eachSeries portals, Agent.resolveFromPortalDetail, callback
            else
                callback()
