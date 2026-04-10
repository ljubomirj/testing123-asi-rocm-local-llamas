from huggingface_hub import hf_hub_download
import json

def show(repo):
    path = hf_hub_download(repo, filename="config.json")
    with open(path) as f:
        cfg = json.load(f)
    print(repo)
    print("quantization_config:", cfg.get("quantization_config", {}))
    print("model_type:", cfg.get("model_type"))
    print()

show("QuantTrio/GLM-4.7-Flash-AWQ")
show("cyankiwi/GLM-4.7-Flash-AWQ-4bit")
