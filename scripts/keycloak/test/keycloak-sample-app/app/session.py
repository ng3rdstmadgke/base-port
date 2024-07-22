# fastapi-session: https://jordanisaacs.github.io/fastapi-sessions/guide/getting_started/

#############################################
# セッションデータ
#############################################
from typing import Optional
from pydantic import BaseModel
from app.schema import IdTokenPayload, TokenEndpointResponse

class SessionData(BaseModel):
    token_response: TokenEndpointResponse
    id_token_payload: IdTokenPayload

#############################################
# セッションフロントエンド
#############################################
from fastapi_sessions.frontends.implementations import SessionCookie, CookieParameters
from fastapi_sessions.frontends.implementations.cookie import SameSiteEnum

# Uses UUID
session_cookie = SessionCookie(
    cookie_name="app_session",  # Cookie名
    identifier="general_verifier",  # セッションを一意に識別するためのキー
    auto_error=True,  # セッションが見つからない場合に自動的にエラーを返す
    secret_key="xxxxxxxxxxxxxxxx",  # セッションデータの暗号化および復号化に使用される秘密鍵
    cookie_params=CookieParameters(
        #secure=False,  # TrueならHTTPSのみでCookieが送信される
        httponly=True,  # JavaScriptからCookieにアクセスできないようにする
        samesite=SameSiteEnum.strict,  # 外部サイトからの遷移時にCookieが送信されないようにする
    ),
)

#############################################
# セッションバックエンド
#############################################
from uuid import UUID
from fastapi_sessions.backends.implementations import InMemoryBackend

session_backend = InMemoryBackend[UUID, SessionData]()


#############################################
# セッションの検証
#############################################
from fastapi_sessions.session_verifier import SessionVerifier
from fastapi import HTTPException

class BasicVerifier(SessionVerifier[UUID, SessionData]):
    def __init__(
        self,
        *,
        identifier: str,
        auto_error: bool,
        backend: InMemoryBackend[UUID, SessionData],
        auth_http_exception: HTTPException,
    ):
        self._identifier = identifier
        self._auto_error = auto_error
        self._backend = backend
        self._auth_http_exception = auth_http_exception

    @property
    def identifier(self):
        return self._identifier

    @property
    def backend(self):
        return self._backend

    @property
    def auto_error(self):
        return self._auto_error

    @property
    def auth_http_exception(self):
        return self._auth_http_exception

    def verify_session(self, model: SessionData) -> bool:
        """If the session exists, it is valid"""
        return True


session_verifier = BasicVerifier(
    identifier="general_verifier",
    auto_error=True,
    backend=session_backend,
    auth_http_exception=HTTPException(status_code=403, detail="invalid session"),
)