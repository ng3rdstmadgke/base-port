from typing import Optional
from pydantic_settings import BaseSettings

class Environment (BaseSettings):
    client_id: str
    client_secret: str
    authorization_server: str
    realm: str
    redirect_uri: str

    pass

def get_env() -> Environment:
    return Environment()