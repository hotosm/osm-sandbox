from typing import Sequence
from osm_to_sandbox import osm_to_sandbox
# from osm_to_sandbox.osm_to_sandbox import AuthPromptAction
# from oauthcli.providers import OpenStreetMapAuth
from osm_login_python.core import Auth

# class OpenStreetMapSandboxAuth(OpenStreetMapAuth):
#     def __init__(
#         self,
#         client_id: str,
#         client_secret: str,
#         scopes: Sequence[str],
#     ):
#         super().__init__(
#             client_id, client_secret, scopes,
#             'openstreetmap_sandbox',
#             'https://sandbox.hotosm.dev'
#         )
#         self.session.redirect_uri = "https://sandbox.hotosm.dev"

# # Monkey patch variables and required methods with URLs and client ID
# osm_to_sandbox.SANDBOX_API = "https://sandbox.hotosm.dev/api/0.6/"
# AuthPromptAction.CLIENT_ID = "GmZNCPz5j7HgTOMzmw94lrsCpnzbtuorgqsYxzxRa2w"
# AuthPromptAction.CLIENT_SECRET = "c2c18c031e6d647e1e02dee103f9bbca5befdf369001439fc2c7f2a820c89e56"

# def custom_call(self, parser, args, values, option_string=None):
#     auth_object = OpenStreetMapSandboxAuth(
#         AuthPromptAction.CLIENT_ID, AuthPromptAction.CLIENT_SECRET,
#         scopes=['read_prefs', 'write_api'],
#     ).auth_server()
#     test = auth_object.get('user/details')
#     if test.status_code == 401:
#         auth_object = OpenStreetMapSandboxAuth(
#             AuthPromptAction.CLIENT_ID, AuthPromptAction.CLIENT_SECRET,
#             scopes=['read_prefs', 'write_api'],
#         ).auth_server(force=True)
#     setattr(args, self.dest, auth_object)
# osm_to_sandbox.AuthPromptAction.__call__ = custom_call

if __name__ == '__main__':
    osm_auth=Auth(
        osm_url="https://sandbox.hotosm.dev",
        client_id="Vxiyi84s1KVvXQDLsJpeawUidZL9gvi2EY7EKjP0e8I",
        client_secret="0e7a04772a003c82b31d9851423da59034b090a0c1ffe0e31bf3f1498074ba33",
        secret_key="xxxx",
        login_redirect_uri="https://sandbox.hotosm.dev",
        scope=['read_prefs', 'write_api'],
    )
    access_token = "FMo_dUKxksnn4ZVTlKn1U9oX5-mrnP3o-p8XV1B7jZY"
    user = osm_auth.deserialize_access_token(access_token)
    print(user)
    # # Khartoum
    # bbox = "32.189941,15.159625,32.961731,15.950766"
    # osm_to_sandbox.main(bbox, )
