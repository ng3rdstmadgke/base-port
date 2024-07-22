class CommonUtil {
  static randomString(n = 16) {
    const S = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return Array.from(Array(n)).map(()=>S[Math.floor(Math.random()*S.length)]).join('')
  }

  static parseQuery(location_search) {
    // NOTE: ... はスプレッド構文。[... iter] でiterの要素を展開して配列にする。
    let query = [
        ... (new URLSearchParams(location_search).entries())
      ].reduce((acc, [k, v]) => {
        acc[k] = v;
        return acc;
      }, {})
    return query
  }
}

class CookieUtil {
  static get(key) {
    let obj = Object.fromEntries(
      document.cookie
        .split(";")
        .map((e) => {
          return e.trim()
            .split("=")
            .map((k) => {
              return decodeURIComponent(k);
            });
        })
    );
    return obj[key];
  }
  
  static set(key, value) {
    // Samesite=Strict: ブラウザは Cookie の元サイトからのリクエストに対してのみ Cookie を送ります
    // Secure: HTTPS でのみ Cookie を送信します
    // HttpOnly: JavaScript の Document.cookie API でアクセスできなくなります。
    document.cookie = `${encodeURIComponent(key)}=${encodeURIComponent(value)}; SameSite=Strict;`;
  }

  static delete(key) {
    document.cookie = `${encodeURIComponent(key)}=; max-age=0`;
  }
}


class AuthUtil {
  static isAuthenticated() {
    return false;
  }

  // CookieからJWTを削除
  static logout() {
    localStorage.removeItem('token_response');
  }
}