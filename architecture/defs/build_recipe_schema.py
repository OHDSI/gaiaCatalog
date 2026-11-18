"""Generate schema/generated/gaia_recipe_v0_1.schema.json from schema/gaia_recipe_v0_1.yaml.

LinkML's JSON Schema generator writes the JSON key of a slot (its alias, for example
"gaia:representation") for properties, but the slot NAME ("representation") inside the
if/then blocks of class rules. With prefixed keys the rules would never fire. This script
generates the schema and rewrites the rule properties to the aliases, so the YAML stays
the one source. It also writes class-level exactly_one_of and any_of, which the generator
leaves out.

Usage: python architecture/defs/build_recipe_schema.py [--check]
(needs linkml, see schema/requirements.txt). --check fails if the generated file is stale.
"""
import json
import sys
from pathlib import Path

SCHEMA_DIR = Path(__file__).resolve().parents[2] / 'schema'
SOURCE = SCHEMA_DIR / 'gaia_recipe_v0_1.yaml'
TARGET = SCHEMA_DIR / 'generated' / 'gaia_recipe_v0_1.schema.json'


def rename(node, names) -> None:
    """Rewrite slot names to JSON keys inside the conditional blocks of a class."""
    if isinstance(node, dict):
        for key in ('allOf', 'anyOf', 'oneOf'):
            for rule in node.get(key, []) if isinstance(node.get(key), list) else []:
                fix(rule, names)
    return None


def fix(node, names) -> None:
    """Recursively spell properties and required lists with JSON keys."""
    if isinstance(node, dict):
        if isinstance(node.get('properties'), dict):
            node['properties'] = {names.get(k, k): v for k, v in node['properties'].items()}
        if isinstance(node.get('required'), list):
            node['required'] = [names.get(k, k) for k in node['required']]
        for value in node.values():
            fix(value, names)
    elif isinstance(node, list):
        for item in node:
            fix(item, names)


def build() -> str:
    """Return the JSON Schema text with rule properties spelled as JSON keys."""
    from linkml.generators.jsonschemagen import JsonSchemaGenerator
    from linkml_runtime.utils.schemaview import SchemaView

    schema = json.loads(JsonSchemaGenerator(str(SOURCE)).serialize())
    view = SchemaView(str(SOURCE))
    # the generator inlines the tree_root class at the top of the document, open to extra keys
    root = next(n for n, c in view.all_classes().items() if c.tree_root)
    schema['additionalProperties'] = False
    nodes = list(schema.get('$defs', {}).items()) + [(root, schema)]
    for cls_name, cls in nodes:
        names = {s.name: (s.alias or s.name) for s in view.class_induced_slots(cls_name)} \
            if cls_name in view.all_classes() else {}
        rename(cls, names)
        cls_def = view.get_class(cls_name) if cls_name in view.all_classes() else None
        # class-level exactly_one_of / any_of of required slots (not written by the generator)
        for field, keyword in (('exactly_one_of', 'oneOf'), ('any_of', 'anyOf')):
            alts = getattr(cls_def, field, None) or []
            required = [[names.get(n, n) for n, c in (a.slot_conditions or {}).items() if c.required]
                        for a in alts]
            if required and all(required):
                cls[keyword] = [{'required': r} for r in required]
    return json.dumps(schema, indent=2) + '\n'


if __name__ == '__main__':
    text = build()
    if '--check' in sys.argv:
        if not TARGET.exists() or TARGET.read_text() != text:
            sys.exit(f'{TARGET} is stale: run architecture/defs/build_recipe_schema.py')
    else:
        TARGET.write_text(text)
        print(f'wrote {TARGET}')
