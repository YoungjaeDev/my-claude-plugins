# Workflow diagram example (Step 9.5 Step A)

The 10-20 node workflow Step A presents to the user and stores in the state file.

Example workflow (ASCII, shown to user in terminal):
```
[Bot Loop] --> [scanChatList] --> <new request?>
                                    |yes --> [Pipeline]
                                    |         +--[parse]--[calculate]--[send]
                                    |no  --> <customer reply?>
                                               |yes --> [AI Consultation]
                                               |         +--[FAQ match]--<resolved?>
                                               |                           |no --> [LLM escalation]
                                               |no  --> [Push System]
                                                          +--[targets]--[filter]--[send push]
```

Stored as Mermaid in state file (`architecture.mermaidSource`):
```mermaid
flowchart TD
    A[Bot Loop] --> B[scanChatList]
    B --> C{new request?}
    C -->|yes| D[Pipeline]
    D --> D1[parse] --> D2[calculate] --> D3[send]
    C -->|no| E{customer reply?}
    E -->|yes| F[AI Consultation]
    F --> F1[FAQ match] --> F2{resolved?}
    F2 -->|no| F3[LLM escalation]
    E -->|no| G[Push System]
    G --> G1[targets] --> G2[filter] --> G3[send push]
```
