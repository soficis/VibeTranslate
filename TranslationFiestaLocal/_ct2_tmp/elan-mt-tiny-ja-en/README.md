---
license: cc-by-sa-4.0
datasets:
- Mitsua/wikidata-parallel-descriptions-en-ja
language:
- ja
- en
metrics:
- bleu
- chrf
library_name: transformers
pipeline_tag: translation
---
# ElanMT
This model is a tiny variant of [**ElanMT-BT-ja-en**](https://huggingface.co/Mitsua/elan-mt-bt-ja-en) and is trained from scratch exclusively on openly licensed data and Wikipedia back translated data using [**ElanMT-base-en-ja**](https://huggingface.co/Mitsua/elan-mt-base-en-ja).

## Model Details
This is a translation model based on [Marian MT](https://marian-nmt.github.io/) 4-layer encoder-decoder transformer architecture with sentencepiece tokenizer.
- **Developed by**: [ELAN MITSUA Project](https://elanmitsua.com/en/) / Abstract Engine
- **Model type**: Translation
- **Source Language**: Japanese
- **Target Language**: English
- **License**: [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)

## Usage
[See here.](https://huggingface.co/Mitsua/elan-mt-bt-ja-en#usage)

## Training Data
[See here.](https://huggingface.co/Mitsua/elan-mt-bt-ja-en#training-data)

## Training Procedure
[See here.](https://huggingface.co/Mitsua/elan-mt-bt-ja-en#training-procedure)

## Evaluation
[See here.](https://huggingface.co/Mitsua/elan-mt-bt-ja-en#evaluation)

## Disclaimer
The translated result may be very incorrect, harmful or biased. The model was developed to investigate achievable performance with only a relatively small, licensed corpus, and is not suitable for use cases requiring high translation accuracy. Under Section 5 of the CC BY-SA 4.0 License, ELAN MITSUA Project / Abstract Engine is not responsible for any direct or indirect loss caused by the use of the model.
