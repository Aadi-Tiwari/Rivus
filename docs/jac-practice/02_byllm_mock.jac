"""Practice 2: byLLM plumbing with the keyless mock model."""

import from byllm.lib { Model }

glob llm = Model(model_name="mockllm", config={"outputs": ["suspicious: escalating gift card purchases"]});

def classify(description: str) -> str by llm();

with entry {
    verdict = classify("Three $100 gift card purchases at different stores in one afternoon");
    print("verdict:", verdict);
}
