#!/usr/bin/env python3
"""Prosty test modelu TranslateGemma 4B (tekst -> tekst)."""

import argparse
import os
import sys

import torch
from transformers import AutoModelForImageTextToText, AutoProcessor


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Simple TranslateGemma 4B translation test")
    parser.add_argument("--text", default="To jest prosty test tłumaczenia.", help="Tekst do przetłumaczenia")
    parser.add_argument("--source", default="pl", help="Kod języka źródłowego, np. pl")
    parser.add_argument("--target", default="en", help="Kod języka docelowego, np. en lub de-DE")
    parser.add_argument("--model", default="google/translategemma-4b-it", help="Model Hugging Face")
    parser.add_argument("--max-new-tokens", type=int, default=128, help="Maksymalna liczba nowych tokenów")
    return parser.parse_args()


def _move_inputs_to_device(inputs, device: torch.device, float_dtype: torch.dtype):
    moved = {}
    for key, value in inputs.items():
        if torch.is_floating_point(value):
            moved[key] = value.to(device=device, dtype=float_dtype)
        else:
            moved[key] = value.to(device=device)
    return moved


def main() -> int:
    args = _parse_args()
    hf_token = os.getenv("HF_TOKEN")

    if not torch.cuda.is_available():
        print("Uwaga: brak CUDA. Model 4B może działać bardzo wolno albo nie zmieścić się w RAM.", file=sys.stderr)

    model_kwargs = {"device_map": "auto"}
    if torch.cuda.is_available():
        model_kwargs["torch_dtype"] = torch.bfloat16

    try:
        processor = AutoProcessor.from_pretrained(args.model, token=hf_token)
        model = AutoModelForImageTextToText.from_pretrained(args.model, token=hf_token, **model_kwargs)
    except Exception as exc:
        print("Nie udało się załadować modelu.", file=sys.stderr)
        print(
            "Sprawdź, czy zaakceptowano licencję modelu na Hugging Face i czy masz poprawny HF_TOKEN.",
            file=sys.stderr,
        )
        print(f"Szczegóły: {exc}", file=sys.stderr)
        return 1

    messages = [
        {
            "role": "user",
            "content": [
                {
                    "type": "text",
                    "source_lang_code": args.source,
                    "target_lang_code": args.target,
                    "text": args.text,
                }
            ],
        }
    ]

    try:
        inputs = processor.apply_chat_template(
            messages,
            tokenize=True,
            add_generation_prompt=True,
            return_dict=True,
            return_tensors="pt",
        )
    except Exception as exc:
        print(f"Błąd podczas budowania promptu: {exc}", file=sys.stderr)
        return 1

    model_device = model.device
    float_dtype = torch.bfloat16 if model_device.type == "cuda" else torch.float32
    inputs = _move_inputs_to_device(inputs, model_device, float_dtype)

    input_len = inputs["input_ids"].shape[-1]
    with torch.inference_mode():
        output = model.generate(
            **inputs,
            do_sample=False,
            max_new_tokens=args.max_new_tokens,
        )

    translated = processor.decode(output[0][input_len:], skip_special_tokens=True).strip()
    print(translated)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
