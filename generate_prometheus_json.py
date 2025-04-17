#!/usr/bin/env python3

import json
import argparse

def generate_targets(hostnames):
    targets = []
    for hostname in hostnames:
        targets.append({
            "labels": {
                "job": "dcgm"
            },
            "targets": [
                f"{hostname}:9400"
            ]
        })
        targets.append({
            "labels": {
                "job": "node"
            },
            "targets": [
                f"{hostname}:9100"
            ]
        })
    return targets

def main():
    parser = argparse.ArgumentParser(description='Generate Prometheus targets.json file.')
    parser.add_argument('hostnames', metavar='N', type=str, nargs='+', help='a list of hostnames')
    parser.add_argument('--output', type=str, default='targets.json', help='output file path')

    args = parser.parse_args()
    hostnames = args.hostnames
    output_file = args.output

    targets = generate_targets(hostnames)

    # Write the targets to the JSON file
    with open(output_file, 'w') as file:
        json.dump(targets, file, indent=2)

    print(f"Targets written to {output_file}")

if __name__ == "__main__":
    main()