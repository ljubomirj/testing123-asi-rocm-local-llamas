
""""Interleaved Thinking + Tool Calling Example"""

import json
from openai import OpenAI

client = OpenAI(
    api_key="YOUR_API_KEY",
    base_url="https://api.z.ai/api/paas/v4/",
)

tools = [{"type": "function", "function": {
    "name": "get_weather",
    "description": "Get weather information",
    "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]},
}}]

messages = [
    {"role": "system", "content": "You are an assistant"},
    {"role": "user", "content": "What's the weather like in Beijing?"},
]

# Round 1: the model reasons and then calls a tool
response = client.chat.completions.create(model="glm-4.7", messages=messages, tools=tools, stream=True, extra_body={
        "thinking":{
        "type":"enabled",
        "clear_thinking": False  # False for Preserved Thinking
    }})
reasoning, content, tool_calls = "", "", []
for chunk in response:
    delta = chunk.choices[0].delta
    if hasattr(delta, "reasoning_content") and delta.reasoning_content:
        reasoning += delta.reasoning_content
    if hasattr(delta, "content") and delta.content:
        content += delta.content
    if hasattr(delta, "tool_calls") and delta.tool_calls:
        for tc in delta.tool_calls:
            if tc.index >= len(tool_calls):
                tool_calls.append({"id": tc.id, "function": {"name": "", "arguments": ""}})
            if tc.function.name:
                tool_calls[tc.index]["function"]["name"] = tc.function.name
            if tc.function.arguments:
                tool_calls[tc.index]["function"]["arguments"] += tc.function.arguments

print(f"Reasoning: {reasoning}\nTool calls: {tool_calls}")

# Key: return reasoning_content to keep the reasoning coherent
messages.append({"role": "assistant", "content": content, "reasoning_content": reasoning,
                 "tool_calls": [{"id": tc["id"], "type": "function", "function": tc["function"]} for tc in tool_calls]})
messages.append({"role": "tool", "tool_call_id": tool_calls[0]["id"],
                 "content": json.dumps({"weather": "Sunny", "temp": "25°C"})})

# Round 2: the model continues reasoning based on the tool result and responds
response = client.chat.completions.create(model="glm-4.7", messages=messages, tools=tools, stream=True, extra_body={
        "thinking":{
        "type":"enabled",
        "clear_thinking": False # False for Preserved Thinking
    }})
reasoning, content = "", ""
for chunk in response:
    delta = chunk.choices[0].delta
    if hasattr(delta, "reasoning_content") and delta.reasoning_content:
        reasoning += delta.reasoning_content
    if hasattr(delta, "content") and delta.content:
        content += delta.content

print(f"Reasoning: {reasoning}\nReply: {content}")

