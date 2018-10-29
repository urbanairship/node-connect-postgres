var connect = require('urban-airship-connect')
var postgres = require('./postgres')
var xtend = require('xtend')
var winston = require('winston')

winston.level = process.env.LOG_LEVEL || "debug"
winston.configure({
  transports: [new winston.transports.Console({level: winston.level})]
})


process.on('unhandledRejection', onError)

var app = process.env.UA_APP_KEY
var token = process.env.UA_CONNECT_TOKEN

if (!app) {
  winston.error("No app specified, expected env variable: UA_APP_KEY");
  process.exit(1)
}

if (!token) {
  winston.error("No app specified, expected env variable: UA_CONNECT_TOKEN");
  process.exit(1)
}

var config = {
  user: process.env.APP_USER,
  password: process.env.POSTGRESS_PASSWORD,
  database: process.env.DB_NAME,
  host: process.env.PGHOST,
  port: process.env.PGPORT,
  query: process.env.UA_CONNECT_QUERY || {start: "EARLIEST"}, 
  app: app,
  token: token,
  logLevel: winston.level,
  sampleIntervalMillis: process.env.SAMPLE_INTERVAL_MILLIS || 1000 * 10
}

var connectStream = connect(app, token)

winston.log('info', 'config', xtend(config, {password: 'redacted', token: 'redacted'}))

var postgresStream = postgres(app, config, function (err, streams) { 
  if (err) {
    winston.error(err)
    throw err
  }

  streams.start()
    .pipe(connectStream)
      .once('data', (data) => { winston.info('successfully connected to stream; consuming')})
      .once('data', logAndDelayAddLogger)

    .pipe(streams.storage())

  function logAndDelayAddLogger(data) {
    winston.debug({"sample event from stream": data})
    setTimeout(() => {
      connectStream.once('data', logAndDelayAddLogger)
    }, config.sampleIntervalMillis)
  }
})




function onError(e) {
    winston.error(e.message, e.stack, e)
    process.exit(1)
}
