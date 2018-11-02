DROP MATERIALIZED VIEW IF EXISTS tag_windows;
DROP TABLE IF EXISTS events;

-- a table for our events, they just get set in here
CREATE TABLE events(
        app             varchar(22)                NOT NULL,
        channel         varchar(36),
        resume_offset   bigint                     NOT NULL,
        event_type      varchar(100)              NOT NULL,
        event           jsonb                      NOT NULL,
        insert_time     timestamp                 NOT NULL,
        PRIMARY KEY (app, event_type, resume_offset)
);

GRANT ALL ON events TO $APP_USER;

-- we're constantly querying for the resume offset for an app. 
-- Seems reasonable to facilitate event_type and channel queries too.
CREATE INDEX events_index ON events (
    app,
    channel,
    event_type,
    resume_offset
);


-- this is an example of creating a view that has 
-- the tag open -> tag close period for each channel in the database.
-- it'd be expensive to do these operations each time you want to know about a
-- given app's channels, so this materialized view essentially does a very
-- aggressive cache of that information. In order for this to be useful, you'd
-- have to issue a `REFRESH MATERIALIZED VIEW CONCURRENTLY tag_windows` on a
-- regular schedule, or else the results will become very stale.
CREATE MATERIALIZED VIEW tag_windows AS
    WITH tags AS (
        -- we select distinct on event id to avoid duplicate events
        SELECT DISTINCT ON (event->>'id')
            event->>'id' AS event_id,
            (event->>'occurred')::timestamp AS occurred,
            channel,
            adds.key AS add_cls,
            removes.key AS rm_cls,
            jsonb_array_elements_text(adds.value) AS add_val,
            jsonb_array_elements_text(removes.value)  AS rm_val,
            event->'device'->'named_user_id' AS named_user
            FROM events ,
                lateral jsonb_each(event#>'{body,add}') AS adds,
                lateral jsonb_each(event#>'{body,remove}') AS removes
                WHERE event_type ='TAG_CHANGE'
    ), added AS (SELECT
        event_id,
        channel,
        named_user,
        occurred,
        add_cls AS cls,
        add_val AS tag
        FROM tags
    ), removed AS (SELECT
        event_id,
        channel,
        named_user,
        occurred,
        rm_cls AS cls,
        rm_val AS tag
        FROM tags
    )
    SELECT
        coalesce(added.named_user, removed.named_user) AS named_user,
        coalesce(added.channel, removed.channel) AS channel,
        coalesce(added.cls, removed.cls) AS cls,
        coalesce(added.tag, removed.tag) AS tag,
        added.occurred AS added_at,
        removed.occurred AS removed_at,
        added.event_id AS add_event,
        removed.event_id AS remove_event
        FROM added full JOIN removed ON(
            added.channel = removed.channel AND
            added.tag = removed.tag AND
            added.occurred < removed.occurred
        )
        ORDER BY named_user, channel;

CREATE INDEX tag_windows_index ON tag_windows (
    cls, tag
);

