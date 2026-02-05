import logging, json, time
from mesh_handler import MeshHandler

class BlogLiteratureAgent:
    def __init__(self, conf):
        self.conf = conf
        self.logger = self.setup_logger('blog_agent')
        self.mesh = MeshHandler(conf)
        self.store = 'blog_lit.json'
        self.works = self.load_works()

    def setup_logger(self, name):
        logger = logging.getLogger(name)
        logger.setLevel(logging.INFO)
        fh = logging.FileHandler(f'{name}.log')
        fh.setFormatter(logging.Formatter('[%(asctime)s] %(levelname)s: %(message)s'))
        logger.addHandler(fh)
        return logger

    def load_works(self):
        try:
            with open(self.store, 'r', encoding='utf-8') as f:
                s = json.load(f)
                self.logger.info("Works loaded")
                return s
        except Exception:
            self.logger.warning("No existing works, starting new")
            return {"entries":[],"branches":[]}

    def save(self):
        with open(self.store, 'w', encoding='utf-8') as f:
            json.dump(self.works, f, indent=2)

    def create_entry(self, title, typ, content, branch=None):
        entry = {"id": len(self.works['entries']), "title":title, "type":typ, "content":content, "branch":branch}
        self.works['entries'].append(entry)
        self.logger.info(f"New {typ} entry: {title}")
        self.save()
        return entry

    def create_branch(self, from_id, note):
        branch = {"from_id": from_id, "note": note}
        self.works['branches'].append(branch)
        self.logger.info(f"Created branch from {from_id}")
        self.save()
        return branch

    def loop(self):
        self.logger.info("BlogLiterature agent running")
        while True:
            task = self.mesh.listen_for_task()
            if task:
                if task.get('type') == 'new_entry':
                    self.create_entry(task['title'], task['subtype'], task['content'], task.get('branch'))
                elif task.get('type') == 'new_branch':
                    self.create_branch(task['from_id'], task['note'])
            time.sleep(2)

if __name__ == "__main__":
    conf = {"name":"blog_agent"}
    BlogLiteratureAgent(conf).loop()
