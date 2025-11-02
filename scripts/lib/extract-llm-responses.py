#!/usr/bin/env python3
"""
Simple LLM Response Extractor for n8n Execution Data

Extracts LLM responses from n8n execution data based on the known structure
from workflow 191 investigation. Handles the compressed JSON reference format.

Usage:
    cat execution_data.json | ./extract-llm-responses.py [--validate]
"""

import sys
import json
import argparse


def resolve_ref(data, ref):
    """Resolve a numeric string reference to actual data."""
    if isinstance(ref, str) and ref.isdigit():
        idx = int(ref)
        if idx < len(data):
            return data[idx]
    return ref


def extract_llm_responses(data, validate=False):
    """
    Extract LLM responses from execution data.

    Based on the structure discovered in workflow 191:
    - Element 16 contains references to LLM node executions
    - Each execution has data -> main -> items -> json -> response
    """
    results = []

    # Get the node mapping (element 4 in the data array)
    if len(data) < 5:
        return results

    # Element 4 maps node names to their execution data references
    node_map = resolve_ref(data, data[0].get('resultData'))
    if not node_map:
        return results

    run_data_ref = node_map.get('runData')
    run_data = resolve_ref(data, run_data_ref)

    if not run_data:
        return results

    # Look for LLM-related nodes
    llm_keywords = ['llm', 'ollama', 'openai', 'agent', 'summarise', 'summarize', 'chat']

    for node_name, node_ref in run_data.items():
        if not any(kw in node_name.lower() for kw in llm_keywords):
            continue

        # Get executions for this node
        executions_arr_ref = resolve_ref(data, node_ref)
        if not isinstance(executions_arr_ref, list):
            continue

        for exec_idx, exec_ref in enumerate(executions_arr_ref):
            exec_data = resolve_ref(data, exec_ref)
            if not isinstance(exec_data, dict):
                continue

            # Extract response and metadata
            extraction = extract_response_from_execution(data, exec_data)

            if extraction:
                response = extraction['response']
                model = extraction.get('model')

                response_data = {
                    'node': node_name,
                    'executionIndex': exec_data.get('executionIndex', exec_idx),
                    'executionTime': exec_data.get('executionTime'),
                    'response': response,
                    'responseLength': len(str(response)),
                    'model': model
                }

                # Validate JSON if requested
                if validate and isinstance(response, str):
                    validation = validate_json(response)
                    response_data['validation'] = validation

                results.append(response_data)

    return results


def extract_response_from_execution(data, exec_data):
    """Extract response and metadata from a single execution."""
    try:
        # Navigate: exec_data -> data -> main -> [items] -> json -> response
        data_ref = exec_data.get('data')
        data_obj = resolve_ref(data, data_ref)

        if not data_obj:
            return None

        main_ref = data_obj.get('main')
        main_arr = resolve_ref(data, main_ref)

        if not isinstance(main_arr, list) or len(main_arr) == 0:
            return None

        # Get first item reference
        items_ref = main_arr[0]
        items = resolve_ref(data, items_ref)

        if not items:
            return None

        # Handle array of items or single item
        if isinstance(items, list):
            if len(items) == 0:
                return None
            first_item_ref = items[0]
            item = resolve_ref(data, first_item_ref)
        else:
            item = items

        if not isinstance(item, dict):
            return None

        # Get json field
        json_ref = item.get('json')
        json_obj = resolve_ref(data, json_ref)

        if not isinstance(json_obj, dict):
            return None

        # Extract response
        response = None
        for field in ['response', 'output', 'text', 'content']:
            response_ref = json_obj.get(field)
            if response_ref:
                response = resolve_ref(data, response_ref)
                if response:
                    break

        if not response:
            return None

        # Extract model information (if available)
        model = None
        model_ref = json_obj.get('model')
        if model_ref:
            model = resolve_ref(data, model_ref)

        # Return dict with response and metadata
        return {
            'response': response,
            'model': model
        }

    except Exception as e:
        print(f"Error extracting response: {e}", file=sys.stderr)
        return None


def validate_json(response_str):
    """Validate if a string is valid JSON."""
    result = {
        'valid': False,
        'error': None,
        'length': len(response_str) if response_str else 0
    }

    if not response_str or not isinstance(response_str, str):
        result['error'] = 'Empty or non-string response'
        return result

    try:
        json.loads(response_str)
        result['valid'] = True
    except json.JSONDecodeError as e:
        result['error'] = str(e)

    return result


def main():
    parser = argparse.ArgumentParser(description='Extract LLM responses from n8n execution data')
    parser.add_argument('--validate', action='store_true', help='Validate responses as JSON')
    parser.add_argument('--pretty', action='store_true', help='Pretty print JSON output')

    args = parser.parse_args()

    # Read from stdin
    raw_data = sys.stdin.read()

    if not raw_data.strip():
        print("Error: No input data", file=sys.stderr)
        sys.exit(1)

    try:
        data = json.loads(raw_data)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON: {e}", file=sys.stderr)
        sys.exit(1)

    # Extract LLM responses
    responses = extract_llm_responses(data, validate=args.validate)

    # Output as JSON
    indent = 2 if args.pretty else None
    print(json.dumps(responses, indent=indent, ensure_ascii=False))


if __name__ == '__main__':
    main()
