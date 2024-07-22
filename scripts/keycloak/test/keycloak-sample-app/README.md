# 起動方法

## KeycloakでClientの作成

- General settings
  - Client ID: `demo-client`
  - Always dicplay in UI: `True`
- Access settings
  - Valid redirect URIs: `http://localhost:8000*`
  - Web origins: `http://localhost:8000*`
- Capability config
  - Client authentication: `True`
  - Authentication flow: `Standard flow`

## レルムの設定

- Tokens
  - Default Signature Algorithm: `RS256`
  - OAuth 2.0 Device Code Lifespan: アクセストークンの有効期限
- Sessions
  - SSO Session Idle: リフレッシュトークンの有効期限
  - SSO Session Max: トークンが更新できなくなる有効期限

## 環境変数の設定

```bash
$ cp sample_env .env

$ vim .env
```

## 起動

```bash
./bin/run.sh

```

http://localhost:8000/



# メモ


- API一覧
  - `https://keycloak.dev.baseport.net/realms/レルム名/.well-known/openid-configuration`
- 公開鍵
  - `https://keycloak.dev.baseport.net/realms/レルム名/protocol/openid-connect/certs`