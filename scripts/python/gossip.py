import asyncio
import websockets
import json

async def handle_client(websocket, path):
    print("[*] New VORTEX connection established.")
    try:
        async for message in websocket:
            payload = json.loads(message)
            print(fRECEIVED: {payload}")
            
            # Example of sending a command BACK to Godot
            if payload.get("event") == "player_action":
                response = {
                    "command": "spawn_particles",
                    "data": {"color": "purple", "intensity": 0.8}
                }
                aawait websocket.send(json.dumps(response))
    except websockets.exceptions.ConnectionCloseOK:
        print("[+] VORTEX connection closed gracefully.")
    except Exception as e:
        print(f"[ERROR] Disconnected: {e}")

async def main():
    server = await websockets.serve(handle_client, "127.0.0.1", 7331)
    print("[*WS] VORTEX Daemon listening on ws://127.0.0.1:7331")
    await server.wait_closed()

if __name__ == "__main__":
    asyncio.run(main())