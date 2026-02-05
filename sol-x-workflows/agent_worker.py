import os, sys, logging, json, traceback
from mesh_handler import MeshHandler

class AgentWorker:
    def __init__(self, agent_conf, global_conf, env):
        self.agent_conf = agent_conf
        self.global_conf = global_conf
        self.logger = self.setup_logger(agent_conf['name'])
        self.mesh = MeshHandler(agent_conf)
        self.memory = {}
        self.main()

    def setup_logger(self, name):
        logger = logging.getLogger(name)
        logger.setLevel(logging.DEBUG)
        fh = logging.FileHandler(f'{name}.log')
        fh.setFormatter(logging.Formatter('[%(asctime)s] %(levelname)s: %(message)s'))
        logger.addHandler(fh)
        return logger

    def handle_task(self, task):
        # Place detailed implementation and error handling per task
        try:
            # Example: handle LLM, camera, radio, p2p calls per agent_conf
            if task['type'] == 'llm_infer':
                response = self.do_llm(task['input'])
            elif task['type'] == 'mesh_echo':
                response = self.mesh.broadcast(task['input'])
            else:
                response = {"status": "unknown task"}
            self.logger.info(json.dumps({'input':task, 'output':response}))
            return response
        except Exception as e:
            self.logger.error(f"Task failed: {e} {traceback.format_exc()}")
            return {"status": "error", "reason": str(e)}

    def do_llm(self, prompt):
        # Example: call local Llama.cpp/Ollama/other
        # This is a safe placeholder for your LLM integration
        return {"result": f"LLM-Response: {prompt}"}

    def main(self):
        self.logger.info("Agent worker started")
        try:
            while True:
                task = self.mesh.listen_for_task()
                if task:
                    self.handle_task(task)
        except Exception as e:
            self.logger.error(f"Agent fatal error: {e} {traceback.format_exc()}")
            sys.exit(1)
