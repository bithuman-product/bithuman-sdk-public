"""bitHuman MCP server — expose the bitHuman REST API as Model Context Protocol tools.

Lets any MCP-capable AI agent (Claude Desktop, Claude Code, Cursor, etc.)
discover and drive bitHuman: synthesize speech, generate avatar agents, make
them speak, manage gestures, mint embed tokens, and check credits.
"""

__version__ = "0.1.0"

from .server import main

__all__ = ["main", "__version__"]
