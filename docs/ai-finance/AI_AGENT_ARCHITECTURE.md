# AI agent architecture

One LangGraph in `apps/api/src/finance/advisor.graph.ts`. State carries `userId` from `AuthGuard`. Tool functions close over that id. `toolArguments` is a strict Zod object of `days`, `amount`, `kind`, and `months`. A `userId` field fails validation.

Nodes: classify, retrieve, explain, validate, format.

- Classify is keyword based, including English, Malayalam, and Hinglish cues.
- A greeting skips retrieval.
- Retrieve calls at most four tools.
- Explain calls `LlmClient.chat`, which uses Groq `openai/gpt-oss-20b`. If that fails, the draft is the deterministic sentence.
- Validate rejects a rupee amount that is not in the tool payload. One retry, then the deterministic sentence.
- Format returns the reply.

Tools: `get_financial_summary`, `get_spending_breakdown`, `get_budget_status`, `get_upcoming_obligations`, `get_cash_flow_forecast`, `calculate_safe_to_spend`, `simulate_purchase`, `calculate_savings_plan`, `detect_spending_anomalies`, `get_financial_health_score`.

The model does not query Supabase. Calculation nodes call `engine.ts`. A run and its tool names are stored in `agent_runs` and `agent_tool_calls` when those tables exist.

The parser path in `llm.client.ts` is unchanged and still tries Google before Groq.
