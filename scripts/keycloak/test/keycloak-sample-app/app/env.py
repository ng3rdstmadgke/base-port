from typing import Optional
from pydantic_settings import BaseSettings

class Environment (BaseSettings):
    pass

def get_env() -> Environment:
    return Environment()