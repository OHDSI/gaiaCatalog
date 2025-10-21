from docling.document_converter import DocumentConverter
import os
from pathlib import Path
import argparse


def extract_document_to_markdown(source_path, output_file=None):
    """
    Extract document content and save as markdown file

    Args:
        source_path: Local file path or URL to document
        output_file: Output markdown file path (optional)
    """

    # Initialize converter
    converter = DocumentConverter()

    try:
        print(f"Processing document: {source_path}")

        # Convert document
        result = converter.convert(source_path)

        # Get markdown content
        markdown_content = result.document.export_to_markdown()

        # Determine output filename if not provided
        if output_file is None:
            if source_path.startswith("http"):
                # Extract filename from URL or use default
                output_file = "extracted_document.md"
            else:
                # Use input filename with .md extension
                input_path = Path(source_path)
                output_file = f"{input_path.stem}_extracted.md"

        # Save to file
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(markdown_content)

        print(f"Document successfully converted to: {output_file}")
        print(f"Content preview (first 500 chars):")
        print("-" * 50)
        print(
            markdown_content[:500] + "..."
            if len(markdown_content) > 500
            else markdown_content
        )
        print("-" * 50)

        return output_file, markdown_content

    except Exception as e:
        print(f"Error processing document: {str(e)}")
        return None, None

def extract_tables_only(source_path, output_file=None):
    """
    Extract only tables from document and save as markdown
    """
    converter = DocumentConverter()

    try:
        print(f"Extracting tables from: {source_path}")

        result = converter.convert(source_path)

        # Filter for table content (this is a simplified approach)
        # You might need to adjust based on docling's specific table extraction methods
        full_markdown = result.document.export_to_markdown()

        # Extract table sections (lines that look like Markdown tables)
        lines = full_markdown.split("\n")
        table_lines = []
        in_table = False

        for line in lines:
            # Detect markdown table rows
            if "|" in line and (line.count("|") >= 2):
                table_lines.append(line)
                in_table = True
            elif in_table and line.strip() == "":
                table_lines.append(line)  # Keep empty lines within tables
            elif in_table and "|" not in line:
                in_table = False
                table_lines.append("\n")  # Add a separator between tables

        tables_content = "\n".join(table_lines)

        # Determine output filename
        if output_file is None:
            if source_path.startswith("http"):
                output_file = "extracted_tables.md"
            else:
                input_path = Path(source_path)
                output_file = f"{input_path.stem}_tables.md"

        # Save tables to file
        with open(output_file, "w", encoding="utf-8") as f:
            f.write(f"# Extracted Tables\n\n")
            f.write(tables_content)

        print(f"Tables extracted to: {output_file}")
        print(f"Tables preview:")
        print("-" * 50)
        print(
            tables_content[:800] + "..."
            if len(tables_content) > 800
            else tables_content
        )
        print("-" * 50)

        return output_file, tables_content

    except Exception as e:
        print(f"Error extracting tables: {str(e)}")
        return None, None

# Example usage
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Extract text and tables from PDF documents using Docling.")
    parser.add_argument('--source', required=True, help='Source URL or local path to the PDF document')
    parser.add_argument('--text-output', required=True, help='Output file for the full text markdown')
    parser.add_argument('--tables-output', required=True, help='Output file for the extracted tables markdown')

    args = parser.parse_args()

    source_url = args.source
    text_output_file = args.text_output
    tables_output_file = args.tables_output

    # Extract full document to markdown
    extract_document_to_markdown(source_url, text_output_file)

    # Extract only tables
    extract_tables_only(source_url, tables_output_file)

    print("\n Processing complete! Check the generated markdown files.")
