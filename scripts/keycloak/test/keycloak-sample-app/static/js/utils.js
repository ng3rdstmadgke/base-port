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
    document.cookie = `${encodeURIComponent(key)}=${encodeURIComponent(value)}`;
  }

  static delete(key) {
    document.cookie = `${encodeURIComponent(key)}=; max-age=0`;
  }
}

class AuthUtil {
  static isAuthenticated() {
    return localStorage.getItem('token_response') !== null;
  }

  // CookieからJWTを削除
  static logout() {
    localStorage.removeItem('token_response');
  }
}
