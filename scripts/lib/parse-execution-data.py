#!/usr/bin/env python3
"""
N8N Execution Data Parser

Parses n8n execution data from PostgreSQL, handling the compressed JSON reference format.
Extracts node outputs, LLM responses, and other execution details.

Usage:
    ./parse-execution-data.py <execution_id> [options]

Options:
    --node <node_name>      Extract data for specific node only
    --format <json|text>    Output format (default: json)
    --llm-only              Extract only LLM responses
    --validate-json         Validate LLM responses as JSON
    --output <file>         Write output to file instead of stdout

Examples:
    # Get full execution data
    ./parse-execution-data.py 191

    # Get data for specific node
    ./parse-execution-data.py 191 --node "Summarise Email with LLM"

    # Extract and validate LLM responses
    ./parse-execution-data.py 191 --llm-only --validate-json

    # Save to file
    ./parse-execution-data.py 191 --output execution-191.json
"""

import sys
import json
import argparse
from pathlib import Path
from typing import Any, Dict, List, Optional


class ExecutionDataParser:
    """Parser for n8n execution data with compressed JSON references."""

    def __init__(self, data: List[Any]):
        """
        Initialize parser with execution data array.

        Args:
            data: The decompressed JSON array from execution_data.data
        """
        self.data = data
        self.cache = {}  # Cache resolved references for performance
        self.max_depth = 10  # Maximum recursion depth to prevent infinite loops
        self._resolving = set()  # Track currently resolving refs to detect cycles

    def resolve_ref(self, ref: Any) -> Any:
        """
        Recursively resolve a reference to actual data.

        Args:
            ref: String reference (e.g., "445") or actual value

        Returns:
            Resolved data value
        """
        if ref is None:
            return None

        # Return non-reference values as-is
        if not isinstance(ref, str) or not ref.isdigit():
            return ref

        # Check cache
        ref_int = int(ref)
        if ref_int in self.cache:
            return self.cache[ref_int]

        # Resolve and cache
        if ref_int < len(self.data):
            resolved = self.data[ref_int]
            self.cache[ref_int] = resolved
            return resolved

        return None

    def get_run_data(self) -> Optional[Dict[str, Any]]:
        """
        Extract run data structure from execution data.

        Returns:
            Dictionary mapping node names to execution data
        """
        if len(self.data) < 5:
            return None

        # Structure: data[0] = {startData, resultData, executionData}
        # data[2] = {runData, lastNodeExecuted}
        # data[4] = {nodeName: ref, ...}
        result_data_ref = self.data[0].get('resultData')
        result_data = self.resolve_ref(result_data_ref)

        if not result_data:
            return None

        run_data_ref = result_data.get('runData')
        run_data_map = self.resolve_ref(run_data_ref)

        if not run_data_map:
            return None

        # run_data_map is a dict like {"Node Name": "ref", ...}
        node_data = {}
        for node_name, node_ref in run_data_map.items():
            node_executions = self.resolve_ref(node_ref)
            if node_executions:
                node_data[node_name] = self._parse_node_executions(node_executions)

        return node_data

    def _parse_node_executions(self, executions_ref: Any) -> List[Dict[str, Any]]:
        """
        Parse all execution runs for a node.

        Args:
            executions_ref: Reference to array of execution runs

        Returns:
            List of execution run details
        """
        executions_arr = self.resolve_ref(executions_ref)
        if not isinstance(executions_arr, list):
            return []

        results = []
        for exec_ref in executions_arr:
            exec_data = self.resolve_ref(exec_ref)
            if exec_data and isinstance(exec_data, dict):
                parsed = self._parse_execution_run(exec_data)
                if parsed:
                    results.append(parsed)

        return results

    def _parse_execution_run(self, exec_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Parse a single execution run for a node.

        Args:
            exec_data: Execution run data with references

        Returns:
            Parsed execution details with resolved data
        """
        data_ref = exec_data.get('data')
        data_obj = self.resolve_ref(data_ref)

        if not data_obj:
            return None

        main_ref = data_obj.get('main')
        main_data = self.resolve_ref(main_ref)

        # Resolve output items
        output_items = self._resolve_output_items(main_data)

        return {
            'startTime': exec_data.get('startTime'),
            'executionTime': exec_data.get('executionTime'),
            'executionStatus': self.resolve_ref(exec_data.get('executionStatus')),
            'executionIndex': exec_data.get('executionIndex'),
            'data': {
                'main': output_items
            }
        }

    def _resolve_output_items(self, main_ref: Any) -> List[Dict[str, Any]]:
        """
        Resolve output items from main data reference.

        Args:
            main_ref: Reference to main output data

        Returns:
            List of resolved output items
        """
        if not main_ref:
            return []

        main_arr = self.resolve_ref(main_ref)
        if not isinstance(main_arr, list) or len(main_arr) == 0:
            return []

        items_ref = main_arr[0]
        items = self.resolve_ref(items_ref)

        if not items:
            return []

        # Handle array of items
        if isinstance(items, list):
            return [self._resolve_item(item_ref) for item_ref in items]
        else:
            return [self._resolve_item(items)]

    def _resolve_item(self, item_ref: Any) -> Dict[str, Any]:
        """
        Recursively resolve a single item, expanding all references.

        Args:
            item_ref: Reference to item data

        Returns:
            Fully resolved item dictionary
        """
        item = self.resolve_ref(item_ref)

        if not isinstance(item, dict):
            return {'value': item}

        resolved = {}
        for key, value in item.items():
            # Recursively resolve nested structures
            if isinstance(value, str) and value.isdigit():
                resolved[key] = self._deep_resolve(self.resolve_ref(value))
            elif isinstance(value, dict):
                resolved[key] = {k: self._deep_resolve(self.resolve_ref(v)) for k, v in value.items()}
            elif isinstance(value, list):
                resolved[key] = [self._deep_resolve(self.resolve_ref(v)) for v in value]
            else:
                resolved[key] = value

        return resolved

    def _deep_resolve(self, value: Any, depth: int = 0) -> Any:
        """
        Deeply resolve a value, following all references with depth limiting.

        Args:
            value: Value to resolve
            depth: Current recursion depth

        Returns:
            Fully resolved value or placeholder if depth exceeded
        """
        # Stop if we've exceeded max depth
        if depth > self.max_depth:
            return f"<max_depth_exceeded:{depth}>"

        # Handle reference strings
        if isinstance(value, str) and value.isdigit():
            ref_id = int(value)

            # Detect circular references
            if ref_id in self._resolving:
                return f"<circular_ref:{value}>"

            self._resolving.add(ref_id)
            try:
                resolved = self.resolve_ref(value)
                result = self._deep_resolve(resolved, depth + 1)
            finally:
                self._resolving.discard(ref_id)

            return result

        elif isinstance(value, dict):
            return {k: self._deep_resolve(v, depth + 1) for k, v in value.items()}
        elif isinstance(value, list):
            return [self._deep_resolve(v, depth + 1) for v in value]
        else:
            return value


def validate_json_response(response: str) -> Dict[str, Any]:
    """
    Validate if a response string is valid JSON.

    Args:
        response: String to validate

    Returns:
        Dictionary with validation results
    """
    result = {
        'valid': False,
        'error': None,
        'parsed': None,
        'length': len(response) if response else 0
    }

    if not response or not isinstance(response, str):
        result['error'] = 'Empty or non-string response'
        return result

    try:
        parsed = json.loads(response)
        result['valid'] = True
        result['parsed'] = parsed
    except json.JSONDecodeError as e:
        result['error'] = str(e)

    return result


def extract_llm_responses(node_data: Dict[str, Any], validate: bool = False) -> List[Dict[str, Any]]:
    """
    Extract LLM responses from node execution data.

    Args:
        node_data: Parsed node execution data
        validate: Whether to validate responses as JSON

    Returns:
        List of LLM responses with metadata
    """
    llm_responses = []

    for node_name, executions in node_data.items():
        # Look for common LLM node patterns
        if any(keyword in node_name.lower() for keyword in ['llm', 'ollama', 'openai', 'agent', 'summarise', 'summarize']):
            for idx, execution in enumerate(executions):
                items = execution.get('data', {}).get('main', [])

                for item in items:
                    # Extract response from common LLM output fields
                    response = item.get('response') or item.get('output') or item.get('text')

                    if response:
                        response_data = {
                            'node': node_name,
                            'executionIndex': execution.get('executionIndex', idx),
                            'executionTime': execution.get('executionTime'),
                            'response': response,
                            'responseLength': len(str(response))
                        }

                        if validate and isinstance(response, str):
                            validation = validate_json_response(response)
                            response_data['validation'] = validation

                        llm_responses.append(response_data)

    return llm_responses


def main():
    """Main entry point for CLI usage."""
    parser = argparse.ArgumentParser(
        description='Parse n8n execution data from PostgreSQL',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    parser.add_argument('execution_id', type=str, help='Execution ID to parse')
    parser.add_argument('--node', type=str, help='Extract data for specific node only')
    parser.add_argument('--format', choices=['json', 'text'], default='json', help='Output format')
    parser.add_argument('--llm-only', action='store_true', help='Extract only LLM responses')
    parser.add_argument('--validate-json', action='store_true', help='Validate LLM responses as JSON')
    parser.add_argument('--output', type=str, help='Write output to file instead of stdout')
    parser.add_argument('--input', type=str, help='Read from file instead of stdin')

    args = parser.parse_args()

    # Read execution data
    if args.input:
        with open(args.input, 'r') as f:
            raw_data = f.read()
    else:
        raw_data = sys.stdin.read()

    if not raw_data.strip():
        print("Error: No input data received", file=sys.stderr)
        sys.exit(1)

    try:
        data = json.loads(raw_data)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    # Parse execution data
    parser_obj = ExecutionDataParser(data)
    node_data = parser_obj.get_run_data()

    if not node_data:
        print("Error: Could not parse execution data", file=sys.stderr)
        sys.exit(1)

    # Filter by node if requested
    if args.node:
        if args.node not in node_data:
            print(f"Error: Node '{args.node}' not found in execution data", file=sys.stderr)
            print(f"Available nodes: {', '.join(node_data.keys())}", file=sys.stderr)
            sys.exit(1)
        node_data = {args.node: node_data[args.node]}

    # Extract LLM responses if requested
    if args.llm_only:
        result = extract_llm_responses(node_data, validate=args.validate_json)
    else:
        result = node_data

    # Format output
    if args.format == 'json':
        output = json.dumps(result, indent=2, ensure_ascii=False)
    else:
        output = str(result)

    # Write output
    if args.output:
        with open(args.output, 'w') as f:
            f.write(output)
        print(f"Output written to {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == '__main__':
    main()
