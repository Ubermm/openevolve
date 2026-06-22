"""Thin LLM client wrapper — Anthropic (via Bedrock) and OpenAI behind a unified interface.

Usage:
    client = LLMClient.from_model(model, anthropic_key=..., openai_key=...)
    resp = client.messages.create(model=model, max_tokens=4000,
                                  system="...", messages=[...])
    text = resp.content[0].text
    print(resp.usage)  # _Usage(input_tokens=..., output_tokens=...)
    print(client.total_input_tokens, client.total_output_tokens)
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass, field
from typing import Dict, List, Optional

logger = logging.getLogger(__name__)

_OPENAI_PREFIXES = (
    "gpt-", "o1", "o1-", "o3", "o3-", "o4-", "gpt-5",
    "gpt-oss-", "text-davinci",
)

# Maps short model names to Bedrock model IDs (cross-region inference profile)
_BEDROCK_MODEL_MAP = {
    "claude-opus-4-6": "us.anthropic.claude-opus-4-6-v1",
    "claude-sonnet-4-6": "us.anthropic.claude-sonnet-4-6",
    "claude-haiku-4-5-20251001": "us.anthropic.claude-haiku-4-5-20251001-v1:0",
}


def _is_openai_model(model: str) -> bool:
    m = model.lower()
    return any(m == p.rstrip("-") or m.startswith(p) for p in _OPENAI_PREFIXES)


def _bedrock_model_id(model: str) -> str:
    """Resolve a short model name to a Bedrock model ID."""
    if model in _BEDROCK_MODEL_MAP:
        return _BEDROCK_MODEL_MAP[model]
    if model.startswith("us.anthropic.") or model.startswith("anthropic."):
        return model
    for short, full in _BEDROCK_MODEL_MAP.items():
        if short in model:
            return full
    return f"us.anthropic.{model}-v1:0"


@dataclass
class _Content:
    text: str


@dataclass
class _Usage:
    input_tokens: int = 0
    output_tokens: int = 0


@dataclass
class _Response:
    content: List[_Content]
    usage: _Usage = field(default_factory=_Usage)


class _MessagesNamespace:
    def __init__(self, backend):
        self._backend = backend

    def create(
        self,
        *,
        model: str,
        max_tokens: int,
        system: str,
        messages: List[Dict],
        **kwargs,
    ) -> _Response:
        return self._backend(
            model=model,
            max_tokens=max_tokens,
            system=system,
            messages=messages,
            **kwargs,
        )


class LLMClient:
    """Unified LLM client — routes to Bedrock (Anthropic) or OpenAI."""

    def __init__(
        self,
        *,
        anthropic_key: Optional[str] = None,
        openai_key: Optional[str] = None,
        use_bedrock: bool = True,
        bedrock_region: str = "us-east-1",
    ):
        self._anthropic_key = anthropic_key
        self._openai_key = openai_key
        self._use_bedrock = use_bedrock
        self._bedrock_region = bedrock_region
        self._anthropic_client = None
        self._openai_client = None
        self.total_input_tokens = 0
        self.total_output_tokens = 0
        self.messages = _MessagesNamespace(self._call)

    def _get_anthropic(self):
        if self._anthropic_client is None:
            import anthropic as _anthropic
            if self._use_bedrock:
                self._anthropic_client = _anthropic.AnthropicBedrock(
                    aws_region=self._bedrock_region,
                )
                logger.info("Using Anthropic via Bedrock (%s)", self._bedrock_region)
            else:
                self._anthropic_client = _anthropic.Anthropic(api_key=self._anthropic_key)
                logger.info("Using Anthropic direct API")
        return self._anthropic_client

    def _get_openai(self):
        if self._openai_client is None:
            import openai as _openai
            self._openai_client = _openai.OpenAI(api_key=self._openai_key, timeout=600.0)
        return self._openai_client

    def _call(self, *, model: str, max_tokens: int, system: str, messages: List[Dict], **kwargs) -> _Response:
        if _is_openai_model(model):
            formatted = [{"role": "system", "content": system}] + list(messages)
            m = model.lower()
            is_reasoning = m.startswith(("o1", "o3", "o4", "gpt-5"))
            params = {"model": model, "messages": formatted}
            if is_reasoning:
                params["max_completion_tokens"] = max_tokens
            else:
                params["max_tokens"] = max_tokens
            resp = self._get_openai().chat.completions.create(**params)
            text = resp.choices[0].message.content or ""
            usage = _Usage(
                input_tokens=getattr(resp.usage, "prompt_tokens", 0) or 0,
                output_tokens=getattr(resp.usage, "completion_tokens", 0) or 0,
            )
        else:
            bedrock_model = _bedrock_model_id(model) if self._use_bedrock else model
            resp = self._get_anthropic().messages.create(
                model=bedrock_model, max_tokens=max_tokens, system=system,
                messages=messages, **kwargs,
            )
            text = resp.content[0].text
            usage = _Usage(
                input_tokens=getattr(resp.usage, "input_tokens", 0) or 0,
                output_tokens=getattr(resp.usage, "output_tokens", 0) or 0,
            )

        self.total_input_tokens += usage.input_tokens
        self.total_output_tokens += usage.output_tokens

        return _Response(content=[_Content(text=text)], usage=usage)

    @classmethod
    def from_model(
        cls,
        model: str,
        anthropic_key: Optional[str] = None,
        openai_key: Optional[str] = None,
    ) -> "LLMClient":
        use_bedrock = False
        bedrock_region = os.environ.get("BEDROCK_REGION", "us-east-1")
        return cls(
            anthropic_key=anthropic_key,
            openai_key=openai_key,
            use_bedrock=use_bedrock,
            bedrock_region=bedrock_region,
        )
