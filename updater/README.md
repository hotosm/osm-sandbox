# OSM Updater Service

Update the data in an existing OSM Sandbox instance with latest OSM data.

- After initial load, the user may want to update the data in sandbox.
- To sync with the current OSM database, we need to use replication data.
- This is made available on OSM at intervals: minute, hour, day.
    - https://wiki.openstreetmap.org/wiki/Planet.osm/diffs
    - E.g. https://planet.osm.org/replication/day/000/004/
- We download the daily `.osc` diff files provided by OSM.
    - We must download each file since the date of first data import.
    - The diffs can be filtered by BBOX using `osmium`.
- Then the actual data import / applying of data in the db
  will likely be done by `osmosis`.
