<script>
  import { onMount } from 'svelte';
  import { BackTranslate } from '../wailsjs/go/main/App.js';

  let inputText = '';
  let resultText = '';
  let intermediateText = '';
  function translate() {
    BackTranslate(inputText).then(result => {
      resultText = result.result;
      intermediateText = result.intermediate;
    });
  }
</script>

<main>
  <h1>TranslationFiestaGo</h1>
  <div class="input-box">
    <textarea bind:value={inputText} placeholder="Enter English text to translate..."></textarea>
    <button class="btn" on:click={translate}>Backtranslate</button>
  </div>
  <div class="result-box">
    <h2>Intermediate (Japanese)</h2>
    <p>{intermediateText}</p>
  </div>
  <div class="result-box">
    <h2>Result (English)</h2>
    <p>{resultText}</p>
  </div>
</main>

<style>
  main {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 2rem;
  }

  .input-box {
    display: flex;
    flex-direction: column;
    width: 100%;
    max-width: 600px;
    margin-bottom: 2rem;
  }

  textarea {
    width: 100%;
    height: 150px;
    padding: 0.5rem;
    border: 1px solid #ccc;
    border-radius: 4px;
    margin-bottom: 1rem;
  }

  .btn {
    padding: 0.5rem 1rem;
    border: none;
    border-radius: 4px;
    background-color: #007bff;
    color: white;
    cursor: pointer;
  }

  .result-box {
    width: 100%;
    max-width: 600px;
    margin-bottom: 2rem;
  }

</style>
