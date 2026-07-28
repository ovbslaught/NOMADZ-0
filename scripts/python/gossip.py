import json
from http.server import BaseHTTPRequestHandler, HTTPServer

class GossipHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/gossip':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                payload = json.loads(post_data.decode('utf-8'))
                print(f"
[GOSSIP-VCN8] RECEIVED: {payload}")
                
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(b'{"status":"acknowledged"}')
            except Exception as e:
                self.send_response(400)
                self.end_headers()
                print(f"[ERROR] {e}")
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        # Suppress standard HTTP request logging to keep output clean
        pass

def run_server(port=7331):
    server_address = ('127.0.0.1', port)
    httpd = HTTPServer(server_address, GossipHandler)
    print(f"[*] VultureDrone Gossip Daemon alive and listening on {server_address[0]}:{port}...")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()

if __name__ == '__main__':
    run_server()
