import argparse
from typing import Sequence
from osm_to_sandbox import osm_to_sandbox
from oauthcli.providers import OpenStreetMapAuth
from requests_oauthlib import OAuth2Session

# Monkey patch variables and required methods with URLs and client ID
osm_to_sandbox.SANDBOX_API = "https://sandbox.hotosm.dev/api/0.6/"
OSM_CLIENT_ID="GmZNCPz5j7HgTOMzmw94lrsCpnzbtuorgqsYxzxRa2w"
OSM_CLIENT_SECRET="c2c18c031e6d647e1e02dee103f9bbca5befdf369001439fc2c7f2a820c89e56"
OSM_ACCESS_TOKEN="_uEeRxVawGHSOtIhvb_wS1dAwCL0YALQ0zlMAmVG7-Y"

# Override the OAuth2Session with the token pre-generated
class OpenStreetMapSandboxAuth(OpenStreetMapAuth):
    def __init__(
        self,
        client_id: str,
        client_secret: str,
        scopes: Sequence[str],
        access_token: str,
    ):
        super().__init__(
            client_id, client_secret, scopes,
            'openstreetmap_sandbox',
            'https://sandbox.hotosm.dev'
        )
        self.session = OAuth2Session(
            OSM_CLIENT_ID,
            scope=['read_prefs', 'write_api'],
            token={"access_token": access_token}
        )

def main(bbox: Sequence[float]):
    auth_object = OpenStreetMapSandboxAuth(
        OSM_CLIENT_ID,
        OSM_CLIENT_SECRET,
        scopes=['read_prefs', 'write_api'],
        access_token=OSM_ACCESS_TOKEN,
    )
    print(f"Using BBOX: {bbox}")
    osm_to_sandbox.main(bbox, auth_object)


if __name__ == '__main__':
    """
    Parse args and run.

    Usage: pdm run importer.py "32.189941,15.159625,32.961731,15.950766".
    The example above is for central Khartoum.
    """
    parser = argparse.ArgumentParser(description='Insert OSM production data into HOTOSM Sandbox.')
    parser.add_argument('bbox', type=str, help='Bounding box in the format min_lon,min_lat,max_lon,max_lat')
    args = parser.parse_args()

    bbox_str_to_float_list = [float(value) for value in args.bbox.split(",")]

    main(bbox_str_to_float_list)
