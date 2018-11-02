# A connect/postgres integration

This is a node v8.12.0, streaming style postgres 9.6/urban airship connect 1.0.0
integration demonstrating how a person might warehouse connect data for
their app. This is emphatically NOT how Urban Airship does analytics as
part of its Insight analytics service.

It's meant to be illustrative of concerns such as offset tracking,
duplicate safe inserts (via postgres' ON CONFLICT DO NOTHING), and some simple
analytics.

## Configuration, installation and running

It's a node project, so from this directory, run `npm i` to install its
dependencies. Once these are installed, and assuming you have the PostgreSQL
client installed, you are ready to configure the app!


The app is configured with environment variables: 


```bash
# Postgres configuration
PGHOST=localhost
PGPORT=5432
DB_NAME="connect"
# The user you will use to create tables and such
POWER_USER="your.name"
# The user under which this lil app will run:
APP_USER="connect"
# The pw for the app user
POSTGRESS_PASSWORD="hunter2"

# Log level, See npm.im/winston for other options
LOG_LEVEL="info"

# The app key for your urban airship project
UA_APP_KEY=
# The authentication credential for UA connect
UA_CONNECT_TOKEN=
# If you have a specific connect query you'd like to execute (rather than just
# `{}`, you would specify it here. See the connect docs for 
# details: https://docs.urbanairship.com/api/connect/#operation/api/events/post/requestbody
UA_CONNECT_QUERY=
```

That's it for configuration. Now comes some database administration:

```bash
# Calls the createuser and createdb convenience scripts
npm run create 
# Formats the supplied schema.sql with your configured app user, and loads the 
# schema in the database
npm run schema
```

> Note that the project ships with a [materialized view] for viewing the time 
> spans during which a device has been associated with its tags. There's no
> `refresh` script shipped with this project, but you can just run `REFRESH
> MATERIALIZED VIEW tag_windows` to use it.

And now start the app. It consumes from connect and inserts the resulting data  
into the your configured postgres instance. Stop it with ctrl+c.

```bash
npm start > connect-postgres-integration.logs &
```

Now you wait a bit for data to percolate into postgres.

Once you have some data in there, you can do the following
```bash
# a convenience for REFRESH  MATERIALIZED VIEW tag_windows
npm run refresh
# A convenience for connecting to postgres using the configured database.
npm run connect
```

Now you can see what you've got:

```sql
-- just look at some events
SELECT * FROM events LIMIT 10; 
-- look at some of the tag windows in the materialized view
SELECT * FROM tag_windows LIMIT 10;
-- view the 100 most recently inserted events, their event type, offset, and
-- when they occurred
SELECT resume_offset, event_type, insert_time, (event->>'occurred')::timestamp as occurred FROM events ORDER BY insert_time DESC LIMIT 100;
```

To drop the database, the tables, and the app user.
```bash
npm run rm
```

> I like to keep a `.env` file in root project directory and add it to my
> gitignore with all the environment variables needed to run the project. 
