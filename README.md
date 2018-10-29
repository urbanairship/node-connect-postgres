# A connect/postgres integration

This is a node v8.12.0, streaming style postgres 9.6/urban airship connect 1.0.0
integration demonstrating how a person might warehouse connect data for
their app. This is emphatically NOT how Urban Airship does analytics as
part of its Insight analytics service.

It's meant to be illustrative of concerns such as offset tracking,
duplicate safe inserts (via postgres' ON CONFLICT DO NOTHING), and one
example of the analytics a person might do with the resulting data.

## Configuration, installation and running

It's a node project, so from this directory, run `npm i` to install its
dependencies. Once these are installed, and assuming you have the PostgreSQL
client installed, you're ready to configure and analyze your connect data.

It is configured with environment variables. 

Postgres configuration

```bash
PGHOST=localhost
PGPORT=5432
DB_NAME="connect"
```

The user under which this lil app will run:
```bash
APP_USER="connect"
```

The user you will use to create tables and such
```bash
POWER_USER="your.name"
```

The pw for the app user
```bash
POSTGRESS_PASSWORD="hunter2"
```

Log level, See npm.im/winston for other options

```bash
LOG_LEVEL="info"
```

The app key for your urban airship project
```bash
UA_APP_KEY=
```

The authentication credential for UA connect
```bash
UA_CONNECT_TOKEN=
UA_CONNECT_QUERY=
```


Calls the createuser and createdb convenience scripts
```bash
npm run create 
```

Formats the supplied schema.sql with your configured app user, and loads the 
schema in the database
```bash
npm run schema
```

Start consuming from connect and inserting stuff into the db. Stop it with
ctrl+c

```bash
npm start > connect-postgres-integration.logs &
```

Now you wait a bit for data to percolate into postgres.


Convenience for populating a materialized view shipped in the schema, 
and for getting a psql prompt.
```bash
npm run refresh
npm run connect
```

> Note that node-postgres ships with a materialized view for viewing the time 
> spans during which a device has been associated with its tags. There's no
> `refresh` script shipped with this project, but you can just run REFRESH
> MATERIALIZED VIEW tag_windows to use it.

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

> I like to keep a `.env` file in root project directory and add it to my git
> ignore (your pws will be in there)
