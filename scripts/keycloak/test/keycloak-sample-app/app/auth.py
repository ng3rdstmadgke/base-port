import traceback
import base64

import requests
import jwt
from jwt.algorithms import RSAAlgorithm
from fastapi import HTTPException

from app.env import get_env, Environment
from app.schema import IdTokenPayload, TokenEndpointResponse, UserinfoResponse

#############################################
# 利用可能なAPI一覧
# https://keycloak.dev.baseport.net/realms/demo/.well-known/openid-configuration
# 
#############################################


def get_token(code: str, env: Environment = get_env()) -> TokenEndpointResponse:
    """
    トークンエンドポイントに認可コードを送信して、トークンを取得
    """
    # https://www.keycloak.org/docs/latest/securing_apps/#token-endpoint
    token_endpoint = f"{env.authorization_server}/realms/{env.realm}/protocol/openid-connect/token"
    data={
        "code": code,
        "client_id": env.client_id,
        "client_secret": env.client_secret,
        "redirect_uri": "http://localhost:8000/code",
        "grant_type": "authorization_code",
    }
    response = requests.post(
        url=token_endpoint,
        headers={ "Content-Type": "application/x-www-form-urlencoded" },
        data=data,
    )
    if response.status_code != 200:
        print(f"url: POST {token_endpoint}")
        print(f"data: {data}")
        print(f"status_code: {response.status_code}, text: {response.text}")
        raise HTTPException(status_code=response.status_code, detail=response.text)

    return TokenEndpointResponse.model_validate(response.json())


def refresh_token(refresh_token: str, env: Environment = get_env()) -> TokenEndpointResponse:
    token_endpoint = f"{env.authorization_server}/realms/{env.realm}/protocol/openid-connect/token"
    data = {
        "client_id": env.client_id,
        "client_secret": env.client_secret,
        "refresh_token": refresh_token,
        "grant_type": "refresh_token",
    }
    response = requests.post(
        url=token_endpoint,
        headers = { "Content-Type": "application/x-www-form-urlencoded"},
        data = data,
    )
    if response.status_code != 200:
        print(f"url: POST {token_endpoint}")
        print(f"data: {data}")
        print(f"status_code: {response.status_code}, text: {response.text}")
        raise HTTPException(status_code=response.status_code, detail=response.text)
    return TokenEndpointResponse.model_validate(response.json())


def revoke_token(token: str, token_type_hint: str = "access_token", env: Environment = get_env()):
    # https://www.keycloak.org/docs/latest/securing_apps/#_token_revocation_endpoint
    revoke_endpoint = f"{env.authorization_server}/realms/{env.realm}/protocol/openid-connect/revoke"
    data = {
        "client_id": env.client_id,
        "client_secret": env.client_secret,
        "token": token,
        "token_type_hint": token_type_hint,
    }
    response = requests.post(
        url=revoke_endpoint,
        headers = { "Content-Type": "application/x-www-form-urlencoded"},
        data = data,
    )
    if response.status_code != 200:
        print(f"url: POST {revoke_endpoint}")
        print(f"data: {data}")
        print(f"status_code: {response.status_code}, text: {response.text}")
        raise HTTPException(status_code=response.status_code, detail=response.text)


def verify_id_token(id_token: str, env: Environment = get_env()) -> IdTokenPayload:
    """
    IDトークンの検証
    """
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
    return IdTokenPayload.model_validate(payload)


def verify_access_token(access_token: str, env: Environment = get_env()) -> dict:
    """ アクセストークンの検証
    """
    # Access TokenのヘッダーからKey IDと署名アルゴリズムを取得
    jwt_header = jwt.get_unverified_header(access_token)
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
        access_token,
        public_key,  # 公開鍵
        algorithms=[jwt_algorithm],  # 署名アルゴリズム
        options={
            "verify_exp": True,
            "verify_nbf": True,
            "verify_iat": True,
            "verify_iss": True,
            "verify_aud": False,
            "require": ["exp", "iat", "iss"],  # 必須のクレーム。このクレームがない場合は例外を発生させる
        },
        issuer=f"{env.authorization_server}/realms/{env.realm}",
    )

    # typ クレームを検証（今回はアクセストークンであることを確認）
    if "typ" not in payload or payload["typ"] != "Bearer":
        raise HTTPException(status_code=400, detail="Not Access token.")
    return payload

def introspect_token(token, env: Environment = get_env()):
    # https://www.keycloak.org/docs/latest/securing_apps/#_token_introspection_endpoint
    introspection_endpoint = f"{env.authorization_server}/realms/{env.realm}/protocol/openid-connect/token/introspect"
    secret = base64.b64encode(f"{env.client_id}:{env.client_secret}".encode()).decode()
    response = requests.post(
        url=introspection_endpoint,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "Authorization": f"Basic {secret}",
        },
        data={
            "token": token,
        }
    )
    if response.status_code != 200:
        print(f"status_code: {response.status_code}, text: {response.text}")
        raise HTTPException(status_code=response.status_code, detail=response.text)
    return response.json()

def userinfo(token: str, env: Environment = get_env()) -> UserinfoResponse:
    # https://www.keycloak.org/docs/latest/securing_apps/#userinfo-endpoint
    userinfo_endpoint = f"{env.authorization_server}/realms/{env.realm}/protocol/openid-connect/userinfo"
    response = requests.get(
        url=userinfo_endpoint,
        headers={
            "Authorization": f"Bearer {token}",
        }
    )
    if response.status_code != 200:
        print(f"url: GET {userinfo_endpoint}")
        print(f"status_code: {response.status_code}, text: {response.text}")
        raise HTTPException(status_code=response.status_code, detail=response.text)
    return UserinfoResponse.model_validate(response.json())
