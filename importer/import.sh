#!/bin/bash

# NOTE that while osmosis is a deprecated tool, it is the only one available to
# import OSM data into the apidb format (for replication of the OSM API).
#
# Tools like osmium are much better, but are for importing into a different
# database format (as PostGIS geometries) for data analysis purposes.

# TODO
# TODO make this an env var
# TODO
BBOX="32.189941,15.159625,32.961731,15.950766"

# Get centroid from BBOX
IFS=',' read -r xmin ymin xmax ymax <<< "$BBOX"
cx=$(awk "BEGIN {print ($xmin + $xmax) / 2}")
cy=$(awk "BEGIN {print ($ymin + $ymax) / 2}")
echo "Centroid: ($cx, $cy)"

# Reverse geocode centroid to get country

# Download country data from GeoFabrik

# Filter .osm.pbf using osmium --bbox
# NOTE also possible to filter by polygon (future upgrade)

# Import filtered data using osmosis into apidb


# Next create a separate container / service for the updater
# When user trigger update, download daily .osc diffs from OSM since last update
# Process using osmium, then import into db?
# Alternatively just use osmosis again



### TODO edit me - copied from osm-seed below

#!/usr/bin/env bash
set -e
export VOLUME_DIR=/mnt/data
export PGPASSWORD=$POSTGRES_PASSWORD

# OSMOSIS tuning: https://wiki.openstreetmap.org/wiki/Osmosis/Tuning,https://lists.openstreetmap.org/pipermail/talk/2012-October/064771.html
if [ -z "$MEMORY_JAVACMD_OPTIONS" ]; then
    echo JAVACMD_OPTIONS=\"-server\" > ~/.osmosis
else
    memory="${MEMORY_JAVACMD_OPTIONS//i}"
    echo JAVACMD_OPTIONS=\"-server -Xmx$memory\" > ~/.osmosis
fi

# Get the data
file=$(basename $URL_FILE_TO_IMPORT)
osmFile=$VOLUME_DIR/$file
[ ! -f $osmFile ] && wget $URL_FILE_TO_IMPORT

function importData () {
    # This is using a osmosis 0.47. TODO: test with osmosis 0.48, and remove the following line
    psql -U $POSTGRES_USER -h $POSTGRES_HOST -d $POSTGRES_DB -c "ALTER TABLE users ADD COLUMN nearby VARCHAR;"
    # In case the import file is a PBF
    if [ ${osmFile: -4} == ".pbf" ]; then
        pbfFile=$osmFile
        echo "Importing $pbfFile ..."
        osmosis --read-pbf \
        file=$pbfFile\
        --write-apidb \
        host=$POSTGRES_HOST \
        database=$POSTGRES_DB \
        user=$POSTGRES_USER \
        password=$POSTGRES_PASSWORD \
        allowIncorrectSchemaVersion=yes \
        validateSchemaVersion=no
    else
        # In case the file is .osm
        # Extract the osm file
        bzip2 -d $osmFile
        osmFile=${osmFile%.*}
        echo "Importing $osmFile ..."
        osmosis --read-xml \
        file=$osmFile  \
        --write-apidb \
        host=$POSTGRES_HOST \
        database=$POSTGRES_DB \
        user=$POSTGRES_USER \
        password=$POSTGRES_PASSWORD \
        validateSchemaVersion=no
    fi
    # Run required fixes in DB
    psql -U $POSTGRES_USER -h $POSTGRES_HOST -d $POSTGRES_DB -c "select setval('current_nodes_id_seq', (select max(node_id) from nodes));"
    psql -U $POSTGRES_USER -h $POSTGRES_HOST -d $POSTGRES_DB -c "select setval('current_ways_id_seq', (select max(way_id) from ways));"
    psql -U $POSTGRES_USER -h $POSTGRES_HOST -d $POSTGRES_DB -c "select setval('current_relations_id_seq', (select max(relation_id) from relations));"
    # psql -U $POSTGRES_USER -h $POSTGRES_HOST -d $POSTGRES_DB -c "select setval('users_id_seq', (select max(id) from users));"
    # psql -U $POSTGRES_USER -h $POSTGRES_HOST -d $POSTGRES_DB -c "select setval('changesets_id_seq', (select max(id) from changesets));"

}

flag=true
while "$flag" = true; do
    pg_isready -h $POSTGRES_HOST -p 5432 -U $POSTGRES_USER >/dev/null 2>&2 || continue
    # Change flag to false to stop ping the DB
    flag=false
    importData
done
