var pg = require("pg");
var winston = require("winston");
var through = require("through2").obj;

module.exports = pgStream;

function pgStream(app, config, ready) {
  var pool = new pg.Pool(config);

  var CURRENT_OFFSET = {
    text:
      "SELECT resume_offset FROM events WHERE app = $1 ORDER BY resume_offset DESC LIMIT 1",
    values: [app],
    name: "get-offsets"
  };

  pool
    .query(CURRENT_OFFSET)
    .then(function(res) {
      winston.log("info", "found offset response", res.rows[0]);

      var query = config.query;
      if (res.rows.length) {
        var resume = res.rows[0].resume_offset;

        if (resume) {
          query.resume_offset = resume;
          delete query.start;
        }
      }

      winston.info("connecting to connect with:", { connectQuery: query });

      ready(null, {
        storage: connectData,
        start: start(query)
      });
    })
    .catch(ready);

  function start(query) {
    return function asStream() {
      var stream = through(function(chunk, encoding, cb) {
        this.push(query);
        cb();
      });
      setImmediate(function() {
        stream.write({});
      });
      return stream;
    };
  }

  function connectData() {
    winston.info("setting up database connection");
    var persist = through(transform);

    return persist;

    function transform(data, encoding, cb) {
      insert(data, cb);
    }
  }

  function insert(data, cb) {
    // we might receive the same offsets multiple times, so we want to ignore
    // conflicts
    var command =
      "INSERT INTO events (app, channel, resume_offset, event_type, event, insert_time) VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT DO NOTHING";
    var dbVal = toDatabaseValues(data);

    var query = {
      text: command,
      name: "insert event",
      values: dbVal
    };

    pool
      .query(query)
      .then(function(res) {
        cb();
      })
      .catch(function(err) {
        winston.error(err);
        cb(err);
      });
  }

  function toDatabaseValues(datum) {
    return [
      app,
      datum.device ? datum.device.channel : null,
      +datum.offset,
      datum.type,
      JSON.stringify(datum),
      new Date().toISOString()
    ];
  }
}
