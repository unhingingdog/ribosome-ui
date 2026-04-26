# Telomere

Telomere is a partial JSON parser, and balancer. It's designed to make JSON syntactically valid, by providing the suffix string required to close it off (the "telomere"). It's main purpose is to close off streaming structured data from an LLM, so that a UI can be streamed out like a plain text chat.

This is a port from a Rust project I previously created: telomere-json on crates.io. It's almost a 1 to 1 port, given the similarity of the languages. For that reason (high accidential complexity, low intrinsic) it's mostly AI generated, and relatively lightly tested, relying on substantial logical coverage in the Rust repo.
