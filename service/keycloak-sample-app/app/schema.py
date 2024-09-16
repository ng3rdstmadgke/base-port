from typing import Optional
from pydantic import BaseModel

class IdTokenPayload(BaseModel):
    exp: int
    iat: int
    auth_time: int
    jti: str
    iss: str
    aud: str  # client_id
    sub: str
    typ: str
    azp: str
    nonce: str
    sid: str
    email_verified: bool
    name: str
    preferred_username: str
    given_name: str
    family_name: str
    email: str

class TokenEndpointResponse(BaseModel):
    access_token: str
    expires_in: int
    id_token: str
    scope: str
    token_type: str
    refresh_token: Optional[str] = None  # 認証リクエストで access_type パラメータが offline に設定されている場合にのみ


class UserinfoResponse(BaseModel):
    sub: str
    email_verified: bool
    name: str
    preferred_username: str
    given_name: str
    family_name: str
    email: str