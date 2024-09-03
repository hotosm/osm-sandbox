# OSM Importer Service

Import data into a fresh OSM Sandbox instance.

Method:
    1. User provides BBOX to download data for.
        - First we do a simple calculation to get centroid from BBOX.
        - https://nominatim.org/release-docs/latest/api/Reverse
    2. (Optional) reverse geocode the country name from BBOX area.
    3. Download latest country data using GeoFabrik.
    4. Filter data using `osmium` BBOX functionality.
    5. Import the BBOX data into the sandbox db using `osmosis`.

> [!NOTE]
> While `osmium` is the most performant and best maintained tool
> for dealing with OSM data, it does not support importing into
> an OSM-type database (dbapi).
>
> It's primary purpose is for importing into an alternative
> PostGIS database for data analysis, using PostGIS representations
> of each geometry (the OSM db does not use PostGIS).
>
> As a result, the only available tool for importing into dbapi
> format is `osmosis`, a now deprecated Java tool.

## Work Modes

### Option 1: Startup

- Each osm-sandbox instance is throwaway.
- The user starts sandbox with a bbox, the data is populated.
- The mapping concludes, data is extracted, and the sandbox deleted.

### Option 2: Triggered

- We run one osm-sandbox instance.
- The user triggers import for an AOI.
- The data is imported using the workflow above.

## Updating Data

See the `updater` section of this repo.

## Future

- This is a test service to demo different approaches.
- The end goal is to contribute to developmentseed/osm-seed.
