# OSM Sandbox

Edit a map collaboratively, in an isolated environment.

This repository does the following:

- Builds a custom lightweight container image for OpenStreetMap.
- Automatically configures an admin user, OAuth application, and working ID Editor.
- Starts a sandboxed / isolated instance of OpenStreetMap from the main instance at
  openstreetmap.org.

![empty-osm](./empty-osm.png)

## Usage (Development)

```bash
docker compose up -d
```

Access OpenStreetMap on: http://localhost:4433
Access ID Editor on: http://localhost:4433/edit?editor=id

Credentials:
- User admin@hotosm.org
- Password: Password1234

## Usage (Production)

- Buy a domain and allocated a server.
- ...

## Importing Existing OSM Data

Check out [osm_to_sandbox](https://github.com/Zverik/osm_to_sandbox/tree/main)
