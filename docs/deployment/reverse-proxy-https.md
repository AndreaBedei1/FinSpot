# Deploy HTTPS senza esporre la porta 3000

Obiettivo:
- Esterno: esposte solo `80` e `443`
- Backend: resta interno su `127.0.0.1:3000`
- App Flutter: chiama solo URL HTTPS pubblici

## Contratto API usato dall'app

L'app usa endpoint relativi (`/auth`, `/users`, `/sightings`, ...), costruiti a partire da:
- `API_BASE` (dart-define, con compatibilita anche `API_BASE_URL`)
- default nel codice: `https://isi-seawatch.csr.unibo.it/api`
- base file statici/immagini: `FILES_BASE` (compatibilita anche `FILES_BASE_URL`, default `https://isi-seawatch.csr.unibo.it`)

Se vuoi un prefisso dedicato backend, usa:
- `API_BASE=https://tuo-dominio.tld/api`

## Config Nginx esempio

```nginx
server {
    listen 80;
    server_name tuo-dominio.tld;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name tuo-dominio.tld;

    ssl_certificate     /etc/letsencrypt/live/tuo-dominio.tld/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/tuo-dominio.tld/privkey.pem;

    # Flutter web static build
    root /var/www/seawatch-web;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # API -> backend interno (porta NON esposta esternamente)
    location /api/ {
        rewrite ^/api/(.*)$ /$1 break;
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

Note:
- Con questa config, il backend continua ad avere route come `/auth/login`.
- Da fuori verranno chiamate come `/api/auth/login`.

## Build Flutter web per questo setup

```powershell
flutter build web --release `
  --dart-define=API_BASE=https://tuo-dominio.tld/api `
  --dart-define=FILES_BASE=https://tuo-dominio.tld
```

Poi pubblica `build/web` nella root Nginx (`/var/www/seawatch-web` nell'esempio).

## Messaggio da dare al team backend

Il backend deve:
- ascoltare solo su `127.0.0.1:3000` (non `0.0.0.0`)
- fidarsi degli header forwardati dal proxy (`X-Forwarded-Proto`)
- accettare richieste con prefisso pubblico `/api/...` che il proxy riscrive su `/...`
- servire upload/static in modo compatibile (es. `/uploads/...` raggiungibile anche tramite `/api/uploads/...` con rewrite)
