GLOBAL.argv = require('optimist').argv

#######################
# initialize logger
logger = GLOBAL.logger = require 'winston'
logger.exitOnError = false
logger.remove logger.transports.Console
logger.add logger.transports.Console,
    colorize:   if argv.raw then false else true
    timestamp:  if argv.raw then false else true
logger.add logger.transports.File,
    filename:   'ingress-exporter.log'

#######################

noop = GLOBAL.noop = -> null

#######################

async = require('async')

Config = GLOBAL.Config = require './config.json'

require './lib/leaflet.js'
require './lib/utils.js'
require './lib/database.js'
require './lib/agent.js'
require './lib/entity.js'
require './lib/mungedetector.js'
require './lib/accountinfo.js'

require 'color'

plugins = require('require-all')(
    dirname: __dirname + '/plugins'
    filter : /(.+)\.js$/,
)

#######################
# bootstrap

if argv.detect?
    argv.detectmunge = argv.detect
    argv.detectplayer = argv.detect

if not argv.dashboard?
    console.log 'Please specify --dashboard argument'
    return

bootstrap = ->

    async.series [

        (callback) ->

            if argv.detectmunge isnt 'false'
                MungeDetector.detect callback
            else
                MungeDetector.initFromDatabase callback

        (callback) ->

            if argv.detectplayer isnt 'false'
                AccountInfo.fetch callback
            else
                callback()

        Agent.initFromDatabase

    ], (err) ->

        if err

            Database.db.close()
            return

        if not err

            async.eachSeries pluginList, (plugin, callback) ->
                
                if plugin.onBootstrap
                    plugin.onBootstrap callback
                else
                    callback()

            , (err) ->
                
                Database.db.close()

#######################
# main

pluginList = []
pluginList.push plugin for pname, plugin of plugins

# the terminate plugin
pluginList.push
    onBootstrap: (callback) ->
        callback 'end'

async.each pluginList, (plugin, callback) ->
    if plugin.onInitialize
        plugin.onInitialize callback
    else
        callback()
, ->
    bootstrap()
