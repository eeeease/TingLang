#!/usr/bin/env python3
"""A local stand-in for a Tinglang server, for development and manual checks.

Answers the /v1 contract with the fixtures in api/examples and runs a minimal
OAuth flow: /oauth/authorize redirects straight back to the app's callback
with a code (no password page), /oauth/token issues tokens, /v1/auth/revoke
forgets them. Binds 127.0.0.1 only; nothing here is a real server.

Usage: python3 tools/mock_cloud_server.py [port]   (default 8787)
Then in Tinglang: Settings → Advanced → Server address http://127.0.0.1:8787
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urlparse
import json
import secrets
import sys

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / 'api/examples'
REDIRECT = 'tinglang://oauth/callback'


def example(path):
    return json.loads((EXAMPLES / path).read_text())


class Handler(BaseHTTPRequestHandler):
    tokens = {}  # access token → refresh token

    def log_message(self, fmt, *args):
        sys.stderr.write('mock: ' + fmt % args + '\n')

    def origin(self):
        return f'http://127.0.0.1:{self.server.server_address[1]}'

    def reply(self, status, body=None, content_type='application/json', headers=None):
        data = b'' if body is None else json.dumps(body).encode()
        self.send_response(status)
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        if body is not None:
            self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def problem(self, status, code):
        self.reply(status, {'status': status, 'code': code}, 'application/problem+json')

    def authorized(self):
        auth = self.headers.get('Authorization', '')
        return auth.startswith('Bearer ') and auth[7:] in self.tokens

    def form(self):
        length = int(self.headers.get('Content-Length') or 0)
        return {k: v[0] for k, v in parse_qs(self.rfile.read(length).decode()).items()}

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == '/v1/meta':
            meta = example('getMeta/response.200.json')
            o = self.origin()
            meta['auth'].update({
                'issuer': o,
                'authorization_endpoint': f'{o}/oauth/authorize',
                'token_endpoint': f'{o}/oauth/token',
                'revocation_endpoint': f'{o}/v1/auth/revoke',
                'redirect_uri': REDIRECT,
            })
            meta['min_client_version'] = {'macos': '0.3.0'}
            return self.reply(200, meta)
        if url.path == '/oauth/authorize':
            query = {k: v[0] for k, v in parse_qs(url.query).items()}
            if query.get('redirect_uri') != REDIRECT or query.get('code_challenge_method') != 'S256':
                return self.problem(400, 'validation_failed')
            target = REDIRECT + '?' + urlencode({'code': 'mock-code', 'state': query.get('state', '')})
            self.send_response(302)
            self.send_header('Location', target)
            self.send_header('Content-Length', '0')
            return self.end_headers()
        if url.path in ('/v1/account', '/v1/entitlements'):
            if not self.authorized():
                return self.problem(401, 'unauthorized')
            name = 'getAccount' if url.path == '/v1/account' else 'getEntitlements'
            return self.reply(200, example(f'{name}/response.200.json'))
        return self.problem(404, 'not_found')

    def do_POST(self):
        url = urlparse(self.path)
        if url.path == '/oauth/token':
            form = self.form()
            if form.get('grant_type') not in ('authorization_code', 'refresh_token'):
                return self.reply(400, {'error': 'unsupported_grant_type'})
            access, refresh = secrets.token_urlsafe(16), secrets.token_urlsafe(16)
            self.tokens[access] = refresh
            return self.reply(200, {'access_token': access, 'token_type': 'bearer',
                                    'expires_in': 3600, 'refresh_token': refresh})
        if url.path == '/v1/auth/revoke':
            token = self.form().get('token')
            for access, refresh in list(self.tokens.items()):
                if token in (access, refresh):
                    del self.tokens[access]
            return self.reply(200)
        return self.problem(404, 'not_found')


if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8787
    server = ThreadingHTTPServer(('127.0.0.1', port), Handler)
    print(f'Mock Tinglang server on http://127.0.0.1:{port} (Ctrl-C to stop)', flush=True)
    server.serve_forever()
