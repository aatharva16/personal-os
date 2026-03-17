#!/usr/bin/env python3
"""Miniflux MCP server — exposes Miniflux RSS reader as MCP tools.

Reads MINIFLUX_API_KEY and MINIFLUX_URL from process environment at startup.
Runs as an SSE MCP server on MCP_HOST:MCP_PORT (default 127.0.0.1:8765).
The SSE endpoint is at http://<host>:<port>/sse.
Point mcporter at it with: { "url": "http://127.0.0.1:8765/sse" }
"""

import os
import requests
from mcp.server.fastmcp import FastMCP

MINIFLUX_URL = os.environ.get("MINIFLUX_URL", "http://localhost:8080").rstrip("/")
MINIFLUX_API_KEY = os.environ["MINIFLUX_API_KEY"]
HEADERS = {"X-Auth-Token": MINIFLUX_API_KEY}

mcp = FastMCP("Miniflux")


@mcp.tool()
def miniflux_get_unread(limit: int = 50) -> str:
    """Get unread RSS entries from Miniflux.

    Args:
        limit: Maximum number of entries to return (default 50)

    Returns JSON with entries[].title, .url, .published_at, .feed.title
    """
    resp = requests.get(
        f"{MINIFLUX_URL}/v1/entries",
        headers=HEADERS,
        params={"status": "unread", "limit": limit},
        timeout=10,
    )
    resp.raise_for_status()
    return resp.text


@mcp.tool()
def miniflux_search(query: str, limit: int = 20, published_after: str = "") -> str:
    """Search the Miniflux RSS archive by keyword or topic.

    Args:
        query: Search terms — spaces and special characters are handled automatically
        limit: Maximum number of results to return (default 20)
        published_after: Optional ISO8601 date filter, e.g. 2026-01-01T00:00:00Z

    Returns JSON with entries[].title, .url, .published_at, .feed.title
    """
    params: dict = {"search": query, "limit": limit}
    if published_after:
        params["published_after"] = published_after
    resp = requests.get(
        f"{MINIFLUX_URL}/v1/entries",
        headers=HEADERS,
        params=params,
        timeout=10,
    )
    resp.raise_for_status()
    return resp.text


@mcp.tool()
def miniflux_get_feeds() -> str:
    """List all subscribed RSS feeds in Miniflux.

    Returns JSON array of feeds with .title, .site_url, .feed_url, .unread_count
    """
    resp = requests.get(
        f"{MINIFLUX_URL}/v1/feeds",
        headers=HEADERS,
        timeout=10,
    )
    resp.raise_for_status()
    return resp.text


if __name__ == "__main__":
    host = os.environ.get("MCP_HOST", "127.0.0.1")
    port = int(os.environ.get("MCP_PORT", "8765"))
    mcp.settings.host = host
    mcp.settings.port = port
    mcp.run(transport="sse")
