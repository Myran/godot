#!/usr/bin/env python3
"""
Firebase Remote Config Admin Tool

Automates Firebase Remote Config template operations using Firebase Admin SDK.

Requirements:
    pip install firebase-admin

Usage:
    python tools/remote_config_admin.py get_template [--output FILE]
    python tools/remote_config_admin.py validate_template FILE
    python tools/remote_config_admin.py publish_template FILE
    python tools/remote_config_admin.py list_conditions
    python tools/remote_config_admin.py remove_condition CONDITION_NAME

Service Account Setup:
    1. Go to Firebase Console > Project Settings > Service Accounts
    2. Generate Private Key for a new service account
    3. Save as firebase-service-account.json in project root (add to .gitignore)
"""

import argparse
import json
import sys
from pathlib import Path

# Try to import firebase-admin, provide helpful error if missing
try:
    import firebase_admin
    from firebase_admin import credentials, remote_config
    firebase_admin.initialize_app()
except ImportError:
    print("Error: firebase-admin not installed.")
    print("Run: pip install firebase-admin")
    sys.exit(1)


def get_template(output_file: str = None) -> dict:
    """Get the current Remote Config template from Firebase."""
    try:
        template = remote_config.get_template()
        result = {
            "etag": template.etag,
            "parameters": template.parameters or {},
            "conditions": template.conditions or [],
            "parameterGroups": template.parameter_groups or [],
            "version": template.version.__dict__ if template.version else None,
        }

        if output_file:
            with open(output_file, 'w') as f:
                json.dump(result, f, indent=2)
            print(f"Template saved to {output_file}")
        else:
            print(json.dumps(result, indent=2))

        return result
    except Exception as e:
        print(f"Error getting template: {e}")
        sys.exit(1)


def validate_template(template_file: str) -> bool:
    """Validate a Remote Config template without publishing."""
    try:
        with open(template_file, 'r') as f:
            template_data = json.load(f)

        # Create template object from JSON
        template = remote_config.RemoteConfigTemplate.from_dict(template_data)

        # Validate using Firebase API
        validated = remote_config.validate_template(template)
        print(f"Template validation: {'VALID' if validated else 'INVALID'}")

        if validated:
            print("Template is valid and ready to publish")
        else:
            print("Template validation failed")

        return validated
    except Exception as e:
        print(f"Error validating template: {e}")
        sys.exit(1)


def publish_template(template_file: str, force: bool = False) -> dict:
    """Publish a Remote Config template to Firebase."""
    try:
        with open(template_file, 'r') as f:
            template_data = json.load(f)

        # Create template object from JSON
        template = remote_config.RemoteConfigTemplate.from_dict(template_data)

        # Publish the template
        published_template = remote_config.publish_template(template, force=force)

        result = {
            "etag": published_template.etag,
            "version": published_template.version.__dict__ if published_template.version else None,
        }

        print(f"Template published successfully!")
        print(f"ETag: {result['etag']}")
        print(f"Version: {result['version']}")

        return result
    except Exception as e:
        print(f"Error publishing template: {e}")
        sys.exit(1)


def list_conditions() -> list:
    """List all conditions in the current Remote Config template."""
    try:
        template = remote_config.get_template()

        if not template.conditions:
            print("No conditions found in template")
            return []

        print(f"\nFound {len(template.conditions)} condition(s):\n")

        for i, condition in enumerate(template.conditions):
            print(f"{i + 1}. {condition.name}")
            print(f"   Expression: {condition.expression}")
            print(f"   Tag Color: {condition.tag_color}")

            # Find parameters using this condition
            affected_params = []
            if template.parameters:
                for param_name, param in template.parameters.items():
                    if param.condition_value and condition.name in param.condition_value.condition_name:
                        affected_params.append(param_name)

            if affected_params:
                print(f"   Affects: {', '.join(affected_params)}")
            print()

        return template.conditions
    except Exception as e:
        print(f"Error listing conditions: {e}")
        sys.exit(1)


def remove_condition(condition_name: str, dry_run: bool = False) -> bool:
    """
    Remove a condition from the Remote Config template.

    This requires: 1) Getting current template
    2) Removing the condition from conditions list
    3) Removing references from parameters (reverting to default)
    4) Publishing the updated template

    Note: This is a destructive operation - use dry_run first!
    """
    try:
        template = remote_config.get_template()

        # Check if condition exists
        condition_names = [c.name for c in template.conditions or []]
        if condition_name not in condition_names:
            print(f"Condition '{condition_name}' not found")
            print(f"Available conditions: {', '.join(condition_names) if condition_names else 'None'}")
            return False

        if dry_run:
            print(f"[DRY RUN] Would remove condition: {condition_name}")
            print(f"[DRY RUN] Found in conditions list")

            # Find parameters that use this condition
            affected_params = []
            if template.parameters:
                for param_name, param in template.parameters.items():
                    if param.condition_value and condition_name == param.condition_value.condition_name:
                        affected_params.append(param_name)

            if affected_params:
                print(f"[DRY RUN] Would update {len(affected_params)} parameter(s): {', '.join(affected_params)}")
            return True

        # Actually remove the condition
        print(f"Removing condition: {condition_name}")

        # Remove from conditions list
        if template.conditions:
            template.conditions = [c for c in template.conditions if c.name != condition_name]

        # Remove references from parameters (set to default/unconditional)
        if template.parameters:
            for param_name, param in template.parameters.items():
                if param.condition_value and condition_name == param.condition_value.condition_name:
                    # Set explicit value as unconditional (removing the condition dependency)
                    param.condition_value = None

        # Publish the updated template
        published = remote_config.publish_template(template)
        print(f"Condition removed successfully!")
        print(f"New ETag: {published.etag}")

        return True
    except Exception as e:
        print(f"Error removing condition: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Firebase Remote Config Admin Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )

    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # get_template command
    get_parser = subparsers.add_parser('get_template', help='Get current Remote Config template')
    get_parser.add_argument('--output', '-o', help='Output file (JSON)')

    # validate_template command
    validate_parser = subparsers.add_parser('validate_template', help='Validate a template file')
    validate_parser.add_argument('file', help='Template JSON file')

    # publish_template command
    publish_parser = subparsers.add_parser('publish_template', help='Publish a template to Firebase')
    publish_parser.add_argument('file', help='Template JSON file')
    publish_parser.add_argument('--force', '-f', action='store_true', help='Force publish without ETag check')

    # list_conditions command
    subparsers.add_parser('list_conditions', help='List all conditions in the template')

    # remove_condition command
    remove_parser = subparsers.add_parser('remove_condition', help='Remove a condition from the template')
    remove_parser.add_argument('condition_name', help='Name of condition to remove')
    remove_parser.add_argument('--dry-run', '-d', action='store_true', help='Show what would be done without making changes')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    # Execute command
    if args.command == 'get_template':
        get_template(args.output)
    elif args.command == 'validate_template':
        validate_template(args.file)
    elif args.command == 'publish_template':
        publish_template(args.file, args.force)
    elif args.command == 'list_conditions':
        list_conditions()
    elif args.command == 'remove_condition':
        remove_condition(args.condition_name, args.dry_run)


if __name__ == '__main__':
    main()
