#!/usr/bin/env python3
"""OpenAI-compatible local inference server backed by MNN-LLM.

Speaks exactly the dialect Dendrite's OpenAI client expects (see
lib/core/agent/agent_engine.dart):

    POST {baseUrl}/chat/completions
    body: {"model","messages":[...],"stream":true}
    -> SSE lines: data: {"choices":[{"delta":{"content":"..."}}]}  ... data: [DONE]

Backends:
  * MNN    — when --model points at an MNN llm config.json (real inference).
  * stand-in — deterministic echo when no model is given, so the full
               WSA -> host -> app -> integration_test pipeline is runnable
               before a model is in place. Swap in --model for real output.

Usage:
    python tool/mnn/server.py --host 0.0.0.0 --port 8080 \
        --model D:/mnn-models/Qwen2.5-0.5B-Instruct-MNN/config.json
"""
import argparse
import json
import os
import sys
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# MNN's Llm instance is not thread-safe; serialize generation across the
# ThreadingHTTPServer's request threads. The app sends branches sequentially,
# but this guards against any overlap.
_GEN_LOCK = threading.Lock()


# --------------------------------------------------------------------------- #
# Backends
# --------------------------------------------------------------------------- #
class StandInBackend:
    """No model required — deterministic, OpenAI-shaped output for pipeline E2E."""

    name = "stand-in"
    model_id = "mnn-standin"

    def generate(self, messages):
        last_user = next(
            (m["content"] for m in reversed(messages) if m.get("role") == "user"),
            "",
        )
        snippet = last_user.strip().replace("\n", " ")[:80]
        think = (
            "<think>\nStand-in MNN backend: no model loaded, echoing the prompt so "
            "the end-to-end path (WSA -> host server -> app -> test) can be verified."
            "\n</think>\n"
        )
        body = (
            f"⟦MNN stand-in⟧ Received your message: \"{snippet}\". "
            "Provide --model <config.json> to get real MNN inference."
        )
        return think + body


class MnnBackend:
    """Real MNN-LLM inference via the MNN python runtime."""

    name = "mnn"

    def __init__(self, config_path, max_tokens=300, no_think=None):
        import MNN.llm as mnnllm  # noqa: imported lazily so stand-in needs no MNN

        self.model_id = os.path.basename(os.path.dirname(os.path.abspath(config_path))) or "mnn-llm"
        # Qwen3's "thinking" mode is accurate but very verbose/slow; suppress it
        # by default for Qwen3 models (huge latency win for multi-branch analysis).
        self.no_think = ("qwen3" in self.model_id.lower()) if no_think is None else no_think
        sys.stderr.write(f"[mnn] loading model from {config_path} (no_think={self.no_think}) ...\n")
        self._llm = mnnllm.create(config_path)
        self._llm.load()
        try:
            self._llm.set_config(json.dumps({"max_new_tokens": max_tokens}))
        except Exception as e:
            sys.stderr.write(f"[mnn] set_config warning: {e}\n")
        sys.stderr.write("[mnn] model loaded.\n")

    # Concise system prompt for no-think mode — overrides the app's
    # "you MUST think in <think>" instruction, which otherwise makes Qwen3 reason
    # at length despite the pre-filled empty think block.
    _NO_THINK_SYSTEM = (
        "You are a knowledgeable assistant. Answer directly, accurately and "
        "concisely in well-structured Markdown. Do not show your reasoning."
    )

    @classmethod
    def _qwen_nothink(cls, messages):
        # Qwen ChatML with a pre-filled empty think block => model skips reasoning.
        had_system = False
        parts = []
        for m in messages:
            role = m.get("role", "user")
            content = m.get("content", "")
            if role == "system":
                content = cls._NO_THINK_SYSTEM
                had_system = True
            parts.append(f"<|im_start|>{role}\n{content}<|im_end|>\n")
        if not had_system:
            parts.insert(
                0, f"<|im_start|>system\n{cls._NO_THINK_SYSTEM}<|im_end|>\n")
        parts.append("<|im_start|>assistant\n<think>\n\n</think>\n\n")
        return "".join(parts)

    def generate(self, messages):
        with _GEN_LOCK:
            if self.no_think:
                prompt = self._qwen_nothink(messages)
            else:
                # Prefer the model's own chat template; fall back to a transcript.
                try:
                    prompt = self._llm.apply_chat_template(messages)
                except Exception:
                    prompt = self._format(messages)
            out = self._llm.response(prompt, stream=False)
            # response() may return str or a generator depending on build.
            if not isinstance(out, str):
                out = "".join(list(out))
            try:
                self._llm.reset()
            except Exception:
                pass
            return out

    @staticmethod
    def _format(messages):
        parts = []
        for m in messages:
            parts.append(f"{m.get('role', 'user')}: {m.get('content', '')}")
        parts.append("assistant:")
        return "\n".join(parts)


# --------------------------------------------------------------------------- #
# HTTP handler
# --------------------------------------------------------------------------- #
def _sse(obj):
    return f"data: {json.dumps(obj, ensure_ascii=False)}\n\n".encode("utf-8")


def _chunk_text(text, size=4):
    """Yield small pieces so the client renders progressively, independent of
    whether the backend streams natively."""
    i = 0
    while i < len(text):
        yield text[i : i + size]
        i += size


class Handler(BaseHTTPRequestHandler):
    backend = None
    verbose = False

    def log_message(self, fmt, *args):
        if Handler.verbose:
            sys.stderr.write("[http] " + (fmt % args) + "\n")

    # CORS preflight (web/dev convenience).
    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        if self.path.rstrip("/") in ("/health", "/v1/health"):
            return self._json(200, {"status": "ok", "backend": self.backend.name})
        if self.path.rstrip("/") == "/v1/models":
            return self._json(
                200,
                {
                    "object": "list",
                    "data": [
                        {"id": self.backend.model_id, "object": "model", "owned_by": "mnn"}
                    ],
                },
            )
        return self._json(404, {"error": "not found"})

    def do_POST(self):
        if self.path.rstrip("/") != "/v1/chat/completions":
            return self._json(404, {"error": "not found"})
        try:
            length = int(self.headers.get("Content-Length", 0))
            payload = json.loads(self.rfile.read(length) or b"{}")
        except Exception as e:
            return self._json(400, {"error": f"bad request: {e}"})

        messages = payload.get("messages", [])
        stream = bool(payload.get("stream", False))
        model = payload.get("model", self.backend.model_id)
        cid = "chatcmpl-" + uuid.uuid4().hex[:24]
        created = int(time.time())

        if stream:
            return self._stream(cid, created, model, messages)

        # Non-streaming path.
        try:
            text = self.backend.generate(messages)
        except Exception as e:
            sys.stderr.write(f"[error] generate failed: {e}\n")
            return self._json(500, {"error": str(e)})
        return self._json(
            200,
            {
                "id": cid,
                "object": "chat.completion",
                "created": created,
                "model": model,
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": text},
                        "finish_reason": "stop",
                    }
                ],
            },
        )

    def _stream(self, cid, created, model, messages):
        # Send headers + a heartbeat immediately so the client gets bytes right
        # away, THEN run (possibly slow) generation, THEN stream the deltas.
        # Close-delimited body: no Content-Length/chunked, so the client must read
        # until EOF. keep-alive here would leave dart:io's HttpClient waiting for a
        # body boundary that never comes (it stalls / yields nothing).
        self.close_connection = True
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "close")
        self._cors()
        self.end_headers()

        def frame(delta, finish=None):
            return _sse(
                {
                    "id": cid,
                    "object": "chat.completion.chunk",
                    "created": created,
                    "model": model,
                    "choices": [
                        {"index": 0, "delta": delta, "finish_reason": finish}
                    ],
                }
            )

        try:
            # Immediate heartbeat (SSE comment line; ignored by the client parser).
            self.wfile.write(b": connected\n\n")
            self.wfile.write(frame({"role": "assistant"}))
            self.wfile.flush()

            t0 = time.time()
            text = self.backend.generate(messages)
            if Handler.verbose:
                sys.stderr.write(
                    f"[gen] {len(text)} chars in {time.time() - t0:.2f}s "
                    f"({self.backend.name})\n"
                )

            for piece in _chunk_text(text):
                self.wfile.write(frame({"content": piece}))
                self.wfile.flush()
                time.sleep(0.01)
            self.wfile.write(frame({}, finish="stop"))
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, ConnectionAbortedError):
            pass  # client (app) cancelled the stream
        except Exception as e:
            sys.stderr.write(f"[error] generate/stream failed: {e}\n")

    def _json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self._cors()
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")


def main():
    ap = argparse.ArgumentParser(description="MNN OpenAI-compatible server")
    ap.add_argument("--host", default="0.0.0.0")
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument("--model", default=None, help="path to MNN llm config.json")
    ap.add_argument("--max-tokens", type=int, default=300)
    ap.add_argument("--no-think", action="store_true", help="force Qwen no-think")
    ap.add_argument("--think", action="store_true", help="force thinking on")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()

    if args.model:
        if not os.path.exists(args.model):
            sys.exit(f"model config not found: {args.model}")
        no_think = True if args.no_think else (False if args.think else None)
        Handler.backend = MnnBackend(
            args.model, max_tokens=args.max_tokens, no_think=no_think)
    else:
        sys.stderr.write("[warn] no --model given; running STAND-IN backend.\n")
        Handler.backend = StandInBackend()
    Handler.verbose = args.verbose

    srv = ThreadingHTTPServer((args.host, args.port), Handler)
    sys.stderr.write(
        f"MNN server ({Handler.backend.name}) on http://{args.host}:{args.port}"
        f"  ->  base URL: http://<host-ip>:{args.port}/v1\n"
    )
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        srv.shutdown()


if __name__ == "__main__":
    main()
