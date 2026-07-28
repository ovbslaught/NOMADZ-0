import json
from http.server import BaseHTTPRequestHandler, HTTPServer

class GossipHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/gossip':
            length = int(self.headers['Content-Length'])
            data = self.rfile.read(length)
            try:
                payload = json.loads(data.decode('utf-8'))
                print("[GOSSIP-VCN8] RECEIVED: " + str(payload))
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(b'{"status":"ok"}')
            except Exception as e:
                self.send_response(400)
                self.end_headers()
                print("[ERROR] " + str(e))
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass

def run():
    httpd = HTTPServer(('127.0.0.1', 7331), GossipHandler)
    print("[*] VultureDrone Gossip Daemon alive on 127.0.0.1:7331...")
    httpd.serve_forever()

if __name__ == '__main__':
    run()