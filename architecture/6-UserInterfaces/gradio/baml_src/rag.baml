
class ResponseWithCitations {
  question string
  answer string
  citations Citation[]
}

class Citation {
    id string
    citationText string
}


//   detailed summary of the relevant text in complete sentences within the citations section.
 // "CustomGPT4o"

function RAGWithCitations(question: string, context: string) -> ResponseWithCitations {
  client "XAI4"
  prompt #"
   Provide a comprehensive and cohesive answer to the question in full sentences, synthesizing information from all relevant context chunks provided.

   Ensure the response is clear, detailed, and avoids redundancy by combining related information from multiple chunks into a unified narrative.

   If the context contains conflicting information, acknowledge and clarify the differences.

   If the answer includes specific details from the context, cite each source by including its urn ID and a
   the full text of the provided citation.

   Reference all citations used in the response by their ID.

    If the information to fully answer the question is  not provided in the context, clearly state what is missing and
    provide a partial answer based on available information. Do not make up or assume information beyond what is provided.

QUESTION: {{ question }}
RELEVANT CONTEXT: {{ context }}

{{ ctx.output_format }}

  "#
}
