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
    with tags as (
        select 
            event->>'id' as event_id,
            (event->>'occurred')::timestamp as occurred,
            channel,
            adds.key as add_cls, 
            removes.key as rm_cls, 
            jsonb_array_elements_text(adds.value) as add_val,
            jsonb_array_elements_text(removes.value)  as rm_val,
            event->'device'->'named_user_id' as named_user
            from events ,
                lateral jsonb_each(event#>'{body,add}') as adds,
                lateral jsonb_each(event#>'{body,remove}') as removes
                where event_type ='TAG_CHANGE'
    ), added as (select 
        event_id,
        channel, 
        named_user,
        occurred,
        add_cls as cls,
        add_val as tag 
        from tags
    ), removed as (select 
        event_id,
        channel, 
        named_user,
        occurred,
        rm_cls as cls,
        rm_val as tag 
        from tags 
    )
    select 
        coalesce(added.named_user, removed.named_user) as named_user,
        coalesce(added.channel, removed.channel) as channel,
        coalesce(added.cls, removed.cls) as cls,
        coalesce(added.tag, removed.tag) as tag,
        added.occurred as added_at,
        removed.occurred as removed_at,
        added.event_id as add_event,
        removed.event_id as remove_event
        from added full join removed on(
            added.channel = removed.channel and 
            added.tag = removed.tag and 
            added.occurred < removed.occurred
        );

CREATE INDEX tag_windows_index ON tag_windows (
    cls, tag
);

