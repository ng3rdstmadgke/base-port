import traceback
from uuid import uuid4, UUID

import jwt
from pydantic import BaseModel
from fastapi import FastAPI, Request, Response, HTTPException, Depends, status, Cookie
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, JSONResponse, FileResponse
from fastapi.templating import Jinja2Templates

from app.env import get_env, Environment
from app.session import SessionData, session_backend, session_cookie, session_verifier
from app.schema import IdTokenPayload, TokenEndpointResponse
from app.auth import (
    get_token,
    refresh_token,
    verify_id_token,
    verify_access_token,
    introspect_token,
)

env = get_env()

app = FastAPI(
    redoc_url="/api/redoc",
    docs_url="/api/docs",
    openapi_url="/api/docs/openapi.json"
)


@app.exception_handler(Exception)
async def generic_exception_handler(request: Request, e: Exception):
    print("{}\n{}".format(str(e), traceback.format_exc()))
    return JSONResponse(
        status_code=500,
        content={"message": f"Internal Server Error."},
    )


####################################
# 画面表示
####################################

templates = Jinja2Templates(directory="templates")

@app.get("/", response_class=HTMLResponse, tags=["template"])
async def index(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={}
    )

@app.get("/login", response_class=HTMLResponse, tags=["template"])
async def oidc_mode(request: Request):
    """ログイン画面を表示する"""
    return templates.TemplateResponse(
        request=request,
        name="login.html",
        context={
            "client_id": env.client_id,
            "authorization_endpoint_url": f"{env.authorization_server}/realms/{env.realm}/protocol/openid-connect/auth",
        }
    )

@app.get("/code", response_class=HTMLResponse, tags=["template"])
async def code(request: Request):
    """認可レスポンスのリダイレクションエンドポイント"""
    return templates.TemplateResponse(
        request=request,
        name="code.html",
        context={}
    )

@app.get("/content", response_class=HTMLResponse, tags=["template"])
async def content(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="content.html",
        context={}
    )

#############################################
# 認証
#############################################

async def authorize(
    response: Response,
    access_token: str | None = Cookie(default=None),  # Cookieからアクセストークンを取得
    session_data: SessionData = Depends(session_verifier),  # セッションの検証・取得
    session_id: UUID = Depends(session_cookie),  # セッションID
):
    """
    アクセストークンの検証・リフレッシュを行う
    """
    if access_token is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token is required", headers={"WWW-Authenticate": "Bearer"})
    try:
        # アクセストークンの検証
        verify_access_token(access_token)
        print(f"access_token: {access_token}")
        print(session_data.model_dump_json(indent=2))
        return session_data.id_token_payload
    except jwt.ExpiredSignatureError as e:  # exceptions: https://pyjwt.readthedocs.io/en/stable/api.html#exceptions
        print("{}\n{}".format(str(e), traceback.format_exc()))
        if session_data.refresh_token is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired and no refresh token available", headers={"WWW-Authenticate": "Bearer"})
        
        # リフレッシュトークンでアクセストークンを更新
        token_response = refresh_token(session_data.refresh_token)

        # セッションの更新
        new_session_data = SessionData(
            token_response=token_response,
            refresh_token=token_response.refresh_token,
            id_token_payload=session_data.id_token_payload,
        )
        await session_backend.update(session_id, new_session_data)

        # Cookieのアクセストークンを更新
        response.set_cookie(
            key="access_token",
            value=token_response.access_token,
            secure=False,  # TrueならHTTPSのみでCookieが送信される
            httponly=True,  # JavaScriptからCookieにアクセスできないようにする
            samesite="strict",  # 外部サイトからの遷移時にCookieが送信されないようにする
        )
        print(f"access_token: {token_response.access_token}")
        print(new_session_data.model_dump_json(indent=2))
        return session_data.id_token_payload
    except jwt.PyJWKError as e:  # exceptions: https://pyjwt.readthedocs.io/en/stable/api.html#exceptions
        print("{}\n{}".format(str(e), traceback.format_exc()))
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token", headers={"WWW-Authenticate": "Bearer"})
    except Exception as e:
        print("{}\n{}".format(str(e), traceback.format_exc()))
        raise e


#############################################
# API
#############################################
class TokenRequest(BaseModel):
    code: str
    nonce: str

@app.post("/api/token")
async def token(data: TokenRequest, response: Response):
    """認可コードをアクセストークンに交換する"""
    # IDトークン、アクセストークン、リフレッシュトークンを取得
    token_response = get_token(data.code)

    # IDトークンの検証
    id_token_payload = verify_id_token(token_response.id_token)
    print(id_token_payload)

    if id_token_payload.nonce != data.nonce:
        raise HTTPException(status_code=400, detail="nonce not match.")

    # リフレッシュトークンやIDトークンなどをセッションに保存
    # https://jordanisaacs.github.io/fastapi-sessions/guide/getting_started/#create-session-route
    session = uuid4()
    session_data = SessionData(
        token_response=token_response,  # デバッグ用の情報
        refresh_token=token_response.refresh_token,
        id_token_payload=id_token_payload,
    )
    await session_backend.create(session, session_data)
    session_cookie.attach_to_response(response, session)

    # Cookieにアクセストークンを保存
    response.set_cookie(
        key="access_token",
        value=token_response.access_token,
        secure=False,  # TrueならHTTPSのみでCookieが送信される
        httponly=True,  # JavaScriptからCookieにアクセスできないようにする
        samesite="strict",  # 外部サイトからの遷移時にCookieが送信されないようにする
    )

    return {
        "access_token": token_response.access_token,
        "token_type": token_response.token_type,
    }

@app.get("/api/content", dependencies=[Depends(session_cookie)])
def api_content(
   id_token_payload: str = Depends(authorize)
):
    return id_token_payload

#############################################
# Debug API
#############################################
class IntrospectRequest(BaseModel):
    token: str  # id_token, access_token, refresh_token どれでもOK

@app.post("/api/debug/introspect", tags=["debug"])
def debug_introspect(data: IntrospectRequest):
    res = introspect_token(data.token)
    # active が False の場合はトークンが無効
    return res




####################################
# 静的ファイル
####################################
# html=True : パスの末尾が "/" の時に自動的に index.html をロードする
# name="static" : FastAPIが内部的に利用する名前を付けます
app.mount("/static", StaticFiles(directory=f"static", html=True), name="static")
