#!/usr/bin/env python3
import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)  ## remove pandas future warning
warnings.filterwarnings("ignore", category=UserWarning)

import argparse
from typing import List

from defs import jsonldFile2Lance
from defs import lance_utils
from defs import pdf2markdown
from defs import gliner2lance
from defs import jsonld2ntfile

def main(args: List[str]) -> int:
    """Main entry point for the program."""
    parser = argparse.ArgumentParser(description="A simple program with sub-commands.", prog="main.py")

    # Create subparsers
    subparsers = parser.add_subparsers(dest="command", required=True, help="Available sub-commands")

    # Subparser for PDF to table
    parser_p2mt = subparsers.add_parser("pdf2table", help="Convert PDF to Markdown tables")
    parser_p2mt.add_argument('--source', required=True, help='Source URL or local path to the PDF document')
    parser_p2mt.add_argument('--tables-output', required=True, help='Output file for the extracted tables markdown')

    # Subparser for PDF to markdown
    parser_p2m = subparsers.add_parser("pdf2markdown", help="Convert PDF to Markdown")
    parser_p2m.add_argument('--source', required=True, help='Source URL or local path to the PDF document')
    parser_p2m.add_argument('--text-output', required=True, help='Output file for the full text markdown')

    # Subparser for lance_list
    parser_ll = subparsers.add_parser("lance_list", help="List tables in a lance database")
    parser_ll.add_argument("--db_path", type=str, required=True, help="Path to lance database")
    parser_ll.add_argument("--table_name", type=str, required=False, help="Optional table name")

    # Subparser for lance_head
    parser_lh = subparsers.add_parser("lance_head", help="Print the first n rows of a lance database table")
    parser_lh.add_argument("--db_path", type=str, required=True, help="Path to lance database")
    parser_lh.add_argument("--table_name", type=str, required=True, help="Table name")
    parser_lh.add_argument("--n", type=int, required=True, help="rows to print")

    # Subparser for jsonld2lance
    parser_jf2l = subparsers.add_parser("jsonld2lance", help="Load JSON-LD into LanceDB via DuckDB")
    parser_jf2l.add_argument('--json_dir', required=True, help='Local path to the JSON directory')
    parser_jf2l.add_argument("--db_path", type=str, required=True, help="Path to lance database")
    parser_jf2l.add_argument("--table_name", type=str, required=True, help="Table name")

    # Subparser for gliner2lance
    parser_gl2l = subparsers.add_parser("gliner2lance", help="Extract entities with Gliner")
    parser_gl2l.add_argument("--db_path", type=str, required=True, help="Path to lance database")
    parser_gl2l.add_argument("--source_table", type=str, required=True, help="Source table name")
    parser_gl2l.add_argument("--output_table", type=str, required=True, help="Output table name")

    # Subparser for jsonld2ntfile
    parser_jld2nt = subparsers.add_parser("jsonld2ntfile", help="Convert JSON-LD to N-Triples")
    parser_jld2nt.add_argument("--input_dir", type=str, required=True, help="Path to jsonld director")
    parser_jld2nt.add_argument("--output_file", type=str, required=True, help="Output file path")

    # Parse arguments
    parsed_args = parser.parse_args(args)

    # Dispatch based on command
    if parsed_args.command == "pdf2table":
        pdf2markdown.extract_tables_only(parsed_args.source, parsed_args.text_output)
    elif parsed_args.command == "pdf2markdown":
        pdf2markdown.extract_document_to_markdown(parsed_args.source, parsed_args.text_output)
    elif parsed_args.command == "lance_list":
        lance_utils.lance_list(parsed_args.db_path, parsed_args.table_name)
    elif parsed_args.command == "lance_head":
        lance_utils.lance_head(parsed_args.db_path, parsed_args.table_name, parsed_args.n)
    elif parsed_args.command == "jsonld2lance":
        jsonldFile2Lance.processor(parsed_args.json_dir, parsed_args.db_path, parsed_args.table_name)
    elif parsed_args.command == "gliner2lance":
        gliner2lance.processor(parsed_args.db_path, parsed_args.source_table, parsed_args.output_table)
    elif parsed_args.command == "jsonld2ntfile":
        jsonld2ntfile.jsonld2ntfile(parsed_args.input_dir, parsed_args.output_file)


    return 0


if __name__ == "__main__":
    import sys

    sys.exit(main(sys.argv[1:]))
