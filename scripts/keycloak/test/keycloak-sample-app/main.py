import requests
import traceback

from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.templating import Jinja2Templates

from pydantic import BaseModel

from app.env import get_env, Environment
from app.lib import verify_id_token, get_token

env = get_env()

app = FastAPI(
    redoc_url="/api/redoc",
    docs_url="/api/docs",
    openapi_url="/api/docs/openapi.json"
)

####################################
# 画面表示
####################################

templates = Jinja2Templates(directory="templates")

@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        context={}
    )

@app.get("/login/", response_class=HTMLResponse)
def oidc_mode(request: Request):
    """ログイン画面を表示する"""
    return templates.TemplateResponse(
        request=request,
        name="login/index.html",
        context={
            "client_id": env.client_id,
            "authorization_endpoint_url": f"{env.authorization_server}/realms/{env.realm}/protocol/openid-connect/auth",
        }
    )

@app.get("/login/code", response_class=HTMLResponse)
def code(request: Request):
    """認可レスポンスのリダイレクションエンドポイント"""
    return templates.TemplateResponse(
        request=request,
        name="login/code.html",
        context={}
    )

#############################################
# API
#############################################
class OidcModeTokenRequest(BaseModel):
    code: str
    nonce: str

@app.post("/api/token")
def token(data: OidcModeTokenRequest):
    """認可コードをアクセストークンに交換する"""
    # IDトークン、アクセストークン、リフレッシュトークンを取得
    token_response = get_token(data.code)

    # IDトークンの検証
    id_token_payload = verify_id_token(token_response.id_token)
    print(id_token_payload)

    if id_token_payload['nonce'] != data.nonce:
        raise HTTPException(status_code=400, detail="nonce not match.")

    return {
        "token_response": token_response,
        "id_token_payload": id_token_payload,
    }


####################################
# 静的ファイル
####################################
# html=True : パスの末尾が "/" の時に自動的に index.html をロードする
# name="static" : FastAPIが内部的に利用する名前を付けます
app.mount("/static", StaticFiles(directory=f"static", html=True), name="static")
