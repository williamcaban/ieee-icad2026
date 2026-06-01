#!/usr/bin/env python3
"""
run_garak.py — Run garak adversarial probes against an OpenRouter model.

Uses the garak Python API directly (more reliable than the CLI for remote endpoints).

Usage:
    python3 run_garak.py
    python3 run_garak.py --probes lmrc.Bullying,promptinject.HijackHateHumans
    python3 run_garak.py --generations 2 --output results/
"""

import argparse
import json
import os
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description="Run garak probes against OpenRouter.")
    parser.add_argument(
        "--probes",
        default="lmrc.Bullying,promptinject.HijackHateHumans",
        help="Comma-separated probe list (default: lmrc.Bullying,promptinject.HijackHateHumans)",
    )
    parser.add_argument(
        "--generations", type=int, default=3,
        help="Attempts per prompt (default: 3, keep low for free-tier rate limits)",
    )
    parser.add_argument(
        "--output", default="results/",
        help="Output directory for reports (default: results/)",
    )
    args = parser.parse_args()

    # Validate environment
    api_key = os.environ.get("OPENROUTER_API_KEY") or os.environ.get("REST_API_KEY")
    model   = os.environ.get("MODEL_NAME", "liquid/lfm-2.5-1.2b-instruct:free")
    endpoint = os.environ.get("MODEL_ENDPOINT", "https://openrouter.ai/api/v1")

    if not api_key or "REPLACE" in api_key:
        print("ERROR: OPENROUTER_API_KEY is not set.", file=sys.stderr)
        print("       source .workshop-env first.", file=sys.stderr)
        sys.exit(1)

    uri = f"{endpoint}/chat/completions"
    Path(args.output).mkdir(parents=True, exist_ok=True)
    report_prefix = str(Path(args.output) / "garak-report")

    print(f"Model:    {model}")
    print(f"Endpoint: {uri}")
    print(f"Probes:   {args.probes}")
    print(f"Attempts: {args.generations} per prompt")
    print()

    # Configure garak
    os.environ["REST_API_KEY"] = api_key

    try:
        from garak import _config
        import garak.generators.rest as rest_gen
        import garak._plugins as plugins
    except ImportError as e:
        print(f"ERROR: garak not installed — {e}", file=sys.stderr)
        print("       source .venv/bin/activate first.", file=sys.stderr)
        sys.exit(1)

    # Set config — include all attributes probes and harness expect
    _config.plugins.target_type = "rest"
    _config.plugins.target_name = uri
    _config.plugins.probe_spec = args.probes
    _config.run.generations = args.generations
    _config.run.deprefix = True
    _config.run.parallel_attempts = False
    _config.run.parallel_requests = False
    _config.system.parallel_attempts = False
    _config.system.parallel_requests = False
    _config.reporting.report_prefix = report_prefix

    # Build generator with full REST config for OpenRouter chat completions
    generator = rest_gen.RestGenerator(
        uri=uri,
        config_root=_config,
    )
    generator.headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "https://github.com/williamcaban/ieee-icad2026",
    }
    generator.req_template_json_object = {
        "model": model,
        "messages": [{"role": "user", "content": "$INPUT"}],
        "max_tokens": 150,
        "temperature": 0,
    }
    generator.req_template = json.dumps(generator.req_template_json_object)
    generator.response_json = True
    generator.response_json_field = "$.choices[0].message.content"  # JSONPath: $ prefix required
    generator.method = "post"

    # Set up the report file that garak probes write to
    report_jsonl = Path(report_prefix + ".report.jsonl")
    report_jsonl.parent.mkdir(parents=True, exist_ok=True)
    _config.transient.reportfile = open(report_jsonl, "w", encoding="utf-8")
    _config.transient.report_prefix = report_prefix

    print(f"Loading probes: {args.probes}")

    # Load and run probes
    probe_specs = [p.strip() for p in args.probes.split(",")]
    all_results = []
    triggered_count = 0
    total_count = 0

    for probe_spec in probe_specs:
        try:
            probe = plugins.load_plugin(f"probes.{probe_spec}", config_root=_config)
            print(f"\nRunning probe: {probe_spec}")
            results = probe.probe(generator)
            if results:
                all_results.extend(results)
                # Count detector hits: result is a list of dicts with 'passed' key
                for r in results:
                    if isinstance(r, dict):
                        total_count += 1
                        if not r.get("passed", True):
                            triggered_count += 1
        except Exception as e:
            print(f"  Warning: probe {probe_spec} failed — {e}")

    # Close report file
    try:
        _config.transient.reportfile.close()
    except Exception:
        pass

    # Summary
    print("\n" + "=" * 60)
    print("GARAK SCAN COMPLETE")
    print(f"Report: {report_prefix}.report.jsonl")
    print("=" * 60)

    # Parse and summarise the report
    print(f"\nReport: {report_jsonl}")
    attempts = []
    try:
        with open(report_jsonl) as f:
            for line in f:
                line = line.strip()
                if line:
                    attempts.append(json.loads(line))
    except Exception:
        pass

    per_probe: dict = {}
    for r in attempts:
        probe = r.get("probe_classname", "unknown")
        outputs = [o["text"] for o in r.get("outputs", []) if o.get("text")]
        per_probe.setdefault(probe, []).extend(outputs)

    print("\n" + "=" * 60)
    print("GARAK SCAN SUMMARY")
    print("=" * 60)
    print(f"Total attempts captured: {len(attempts)}")
    print()

    for probe, responses in per_probe.items():
        print(f"Probe: {probe}")
        print(f"  Prompts sent:   {len([a for a in attempts if a.get('probe_classname')==probe])}")
        print(f"  Responses got:  {len(responses)}")
        # Show first response as example
        if responses:
            sample = responses[0][:120].replace('\n', ' ')
            print(f"  Sample output:  \"{sample}...\"")
        print()

    print("Note: Automated detector scoring runs via EvalHub in Section 04.")
    print("      Review outputs above to manually spot safety issues.")
    print("=" * 60)

    return 0


if __name__ == "__main__":
    sys.exit(main())
