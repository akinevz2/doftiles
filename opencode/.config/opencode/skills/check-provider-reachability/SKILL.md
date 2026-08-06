---
name: check-provider-reachability
description: Checks if the configured Ollama provider baseURL is reachable and running. Use when debugging connection issues or before starting opencode sessions.
---

# Check Provider Reachability

## Purpose

Verifies that the Ollama server at the configured baseURL is accessible and responding to requests. This helps diagnose connectivity problems before they cause model access failures.

## Usage

Run a simple reachability test:

    curl -s http://localhost:11434/api/tags -o /dev/null && echo "Ollama is reachable" || echo "Cannot reach Ollama server"

For more verbose output:

    curl -v http://ws-rarebox:11434/api/tags 2>&1 | head -20
