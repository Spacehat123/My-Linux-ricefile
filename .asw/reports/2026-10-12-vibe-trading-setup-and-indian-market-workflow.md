# Vibe-Trading Setup & Indian Market Operational Guide

**Date**: 2026-10-12  
**Status**: Completed & Verified  
**Installation Directory**: `$HOME/Desktop/vibe-trading`  

---

## 1. Setup Overview

The **HKUDS/Vibe-Trading** quantitative AI research and backtesting platform has been successfully deployed and verified in `$HOME/Desktop/vibe-trading`.

### Key Environment Components
* **Repository**: Cloned from `https://github.com/HKUDS/Vibe-Trading.git`
* **Python Runtime**: Python 3.13 isolated virtual environment (`.venv`) powered by `uv`
* **Dependencies**: 188 quant finance & agent packages installed (including `langchain`, `langgraph`, `quantlib`, `yfinance`, `ccxt`, `duckdb`, `scikit-learn`, `fastapi`, `uvicorn`)
* **Web UI Dashboard**: Built production React 19 bundle in `frontend/dist/` (KaTeX, Lightweight Charts, Tailwind CSS)
* **Configuration**: Initialized `.env` template in both `$HOME/Desktop/vibe-trading/.env` and `~/.vibe-trading/.env`
* **Convenience Launcher**: Created executable [`$HOME/Desktop/vibe-trading/start.sh`](file://$HOME/Desktop/vibe-trading/start.sh)

---

## 2. How to Use Vibe-Trading

### Launch Options

1. **Web Dashboard (Recommended)**:
   ```bash
   cd ~/Desktop/vibe-trading
   ./start.sh
   ```
   Open `http://localhost:8000` in your browser. This gives you:
   * Interactive chat to prompt quant trading research
   * Strategy Tearsheets & Monte Carlo equity curves
   * Alpha Zoo factor explorer & correlation matrices
   * Options Lab & Portfolio Multi-Broker snapshot pages

2. **Interactive Terminal Chat**:
   ```bash
   cd ~/Desktop/vibe-trading
   ./start.sh chat
   ```

3. **Direct One-Off Strategy Run**:
   ```bash
   cd ~/Desktop/vibe-trading
   ./start.sh run -p "Backtest a 20/50 SMA breakout on RELIANCE.NS for 2024 with 0.05% slippage"
   ```

---

## 3. Configuring Your AI Provider

Edit [`$HOME/Desktop/vibe-trading/.env`](file://$HOME/Desktop/vibe-trading/.env) to configure your preferred LLM:

* **DeepSeek (Recommended for Cost & Math Accuracy)**:
  ```env
  LANGCHAIN_PROVIDER=deepseek
  LANGCHAIN_MODEL_NAME=deepseek-v4-pro
  DEEPSEEK_API_KEY=your_key_here
  ```
* **OpenRouter / Claude / OpenAI**:
  ```env
  LANGCHAIN_PROVIDER=openrouter
  LANGCHAIN_MODEL_NAME=anthropic/claude-3.5-sonnet
  OPENROUTER_API_KEY=your_key_here
  ```
* **Local Offline Models (LM Studio / Ollama)**:
  ```env
  LANGCHAIN_PROVIDER=ollama
  LANGCHAIN_MODEL_NAME=qwen2.5:32b
  OLLAMA_BASE_URL=http://localhost:11434
  ```

---

## 4. Indian Market (NSE / BSE) Workflow

* **Tickers**: Use standard `.NS` (NSE) and `.BO` (BSE) suffixes:
  * Nifty 50: `^NSEI`
  * Sensex: `^BSESN`
  * Equities: `RELIANCE.NS`, `TCS.NS`, `HDFCBANK.NS`, `INFY.NS`, `TATAMOTORS.NS`
* **Indian Broker Connectors**:
  * **Dhan (DhanHQ)**: Configure in settings or `.env` for paper trading and simulated order execution.
  * **Shoonya (Finvasia)**: Supported for execution and data.
  * **Zerodha**: Supported for read-only portfolio tracking.
