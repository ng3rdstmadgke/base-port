import base64
from typing import Optional

import requests
import jwt
from jwt.algorithms import RSAAlgorithm
from fastapi import HTTPException
from pydantic import BaseModel

from app.env import get_env, Environment


class TokenResponse(BaseModel):
    access_token: str
    expires_in: int
    id_token: str
    scope: str
    token_type: str
    refresh_token: Optional[str] = None  # 認証リクエストで access_type パラメータが offline に設定されている場合にのみ

def get_token(code: str, env: Environment = get_env()) -> TokenResponse:
    # https://www.keycloak.org/docs/latest/securing_apps/#token-endpoint
    token_endpoint = f"{env.authorization_server}/realms/{env.realm}/protocol/openid-connect/token"
    res = requests.post(
        url=token_endpoint,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
        },
        data={
            "code": code,
            "client_id": env.client_id,
            "client_secret": env.client_secret,
            "redirect_uri": "http://localhost:8000/login/code",
            "grant_type": "authorization_code",
        }
    )
    if res.status_code != 200:
        raise HTTPException(status_code=400, detail=res.text)

    return TokenResponse.model_validate(res.json())


def verify_id_token(id_token: str, env: Environment = get_env()) -> dict:
    # ID TokenのヘッダーかKey IDと署名アルゴリズムを取得
    jwt_header = jwt.get_unverified_header(id_token)
    key_id = jwt_header["kid"]
    jwt_algorithm = jwt_header["alg"]

    # ヘッダから取得したKey IDを使い、署名検証用の公開鍵をCognitoから取得
    # 鍵は複数存在するので、ヘッダから取得したKey IDと合致するものを取得
    # https://www.keycloak.org/docs/latest/securing_apps/#_certificate_endpoint
    certificate_endpoint = f"{env.authorization_server}/realms/{env.realm}/protocol/openid-connect/certs"
    jwks_response = requests.get(certificate_endpoint)
    jwk = None
    for key in jwks_response.json()["keys"]:
        if key["kid"] == key_id:
            jwk = key
            break
    if jwk is None:
        raise HTTPException(status_code=400, detail="JWK not found.")

    # 公開鍵を取得
    public_key = RSAAlgorithm.from_jwk(jwk)

    # PyJWTでid_tokenの検証とdecode
    # jwt.decode: https://pyjwt.readthedocs.io/en/stable/api.html#jwt.decode
    # options の verify_signature が Trueの場合、デフォルトで以下のオプションが有効になる
    # - verify_exp=True expクレームが存在する場合に、トークンの有効期限を検証する
    # - verify_nbf=True nbfクレームが存在する場合に、トークンが有効になる日時を検証する
    # - verify_iat=True iatクレームが存在する場合に、トークンの発行時刻を検証する
    # - verify_aud=True audクレームが存在する場合に、audience引数と一致するかを検証する
    # - verify_iss=True issクレームが存在する場合に、issure引数と一致するかを検証する
    payload = jwt.decode(
        id_token,
        public_key,  # 公開鍵
        algorithms=[jwt_algorithm],  # 署名アルゴリズム
        options={
            "verify_signature": True,  # 署名を検証する (デフォルト値)
            "require": ["exp", "iat", "aud", "iss"],  # 必須のクレーム。このクレームがない場合は例外を発生させる
        },
        issuer=f"{env.authorization_server}/realms/{env.realm}",
        audience=env.client_id,
    )

    # typ クレームを検証（今回はIDトークンであることを確認）
    if "typ" not in payload or payload["typ"] != "ID":
        raise HTTPException(status_code=400, detail="Not ID token.")
    return payload

def verify_access_token():
    pass

def revoke_token():
    # /auth/realms/{env.realm}/protocol/openid-connect/revoke
    pass

def introspect_token(env: Environment = get_env()):
    # https://www.keycloak.org/docs/latest/securing_apps/#_token_introspection_endpoint
    introspection_endpoint = f"{env.authorization_server}/realms/{env.realm}/protocol/openid-connect/token/introspect"
    secret = base64.b64encode(f"{env.client_id}:{env.client_secret}".encode()).decode()
    res = requests.post(
        url=introspection_endpoint,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization": f"Basic {secret}",
        },
        data={
            "token": "authorization_code",
        }
    )
    if res.status_code != 200:
        raise HTTPException(status_code=400, detail=res.text)
    return res.json()
    

def refresh_token():
    pass