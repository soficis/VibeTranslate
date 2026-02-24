<script>
  import { onMount } from 'svelte';

  const providers = [
    { id: 'google_unofficial', label: 'Google Translate (Unofficial / Free)' }
  ];

  let inputText = '';
  let resultText = '';
  let intermediateText = '';
  let providerId = 'google_unofficial';
  let status = '';

  onMount(async () => {
    if (window?.go?.main?.App?.GetProviderID) {
      providerId = await window.go.main.App.GetProviderID();
    }
  });

  async function updateProvider(event) {
    providerId = event.target.value;
    status = '';
    if (window?.go?.main?.App?.SetProviderID) {
      await window.go.main.App.SetProviderID(providerId);
    }
  }

  async function translate() {
    status = '';
    try {
      if (!window?.go?.main?.App?.BackTranslate) {
        throw new Error('Backend bridge unavailable');
      }
      const result = await window.go.main.App.BackTranslate(inputText);
      resultText = result.result;
      intermediateText = result.intermediate;
    } catch (err) {
      status = err?.message || 'Translation failed';
    }
  }

</script>

<main>
  <header class="header">
    <div>
      <h1>TranslationFiestaGo</h1>
      <p class="subtitle">Backtranslation EN->JA->EN</p>
    </div>
    <div class="controls">
      <label for="provider">Provider</label>
      <select id="provider" bind:value={providerId} on:change={updateProvider}>
        {#each providers as provider}
          <option value={provider.id}>{provider.label}</option>
        {/each}
      </select>
    </div>
  </header>

  <section class="panel">
    <label for="input-text">Input</label>
    <textarea id="input-text" bind:value={inputText} placeholder="Enter text to backtranslate..."></textarea>
    <div class="actions">
      <button class="btn primary" on:click={translate}>Backtranslate</button>
      {#if status}
        <span class="status">{status}</span>
      {/if}
    </div>
  </section>

  <section class="grid">
    <div class="panel">
      <h2>Intermediate (JA)</h2>
      <p class="output">{intermediateText}</p>
    </div>
    <div class="panel">
      <h2>Result (EN)</h2>
      <p class="output">{resultText}</p>
    </div>
  </section>
</main>

<style>
  main {
    display: flex;
    flex-direction: column;
    gap: 1.5rem;
    max-width: 960px;
    margin: 0 auto;
    padding: 2rem;
  }

  h1 {
    margin: 0;
    font-size: 1.75rem;
    font-weight: 700;
  }

  h2 {
    margin: 0 0 0.5rem 0;
    font-size: 1.1rem;
  }

  .subtitle {
    margin: 0.25rem 0 0;
    opacity: 0.7;
  }

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .controls {
    display: flex;
    align-items: center;
    gap: 0.75rem;
  }

  select,
  input,
  textarea {
    background-color: #111826;
    color: #f8fafc;
    border: 1px solid #2b3546;
    border-radius: 6px;
    padding: 0.6rem 0.75rem;
    font-size: 0.95rem;
  }

  textarea {
    width: 100%;
    min-height: 160px;
    resize: vertical;
  }

  .panel {
    background: rgba(17, 24, 38, 0.7);
    border: 1px solid #2b3546;
    border-radius: 12px;
    padding: 1.25rem;
  }

  .panel-row {
    display: flex;
    justify-content: space-between;
    gap: 1rem;
    flex-wrap: wrap;
  }

  .actions {
    display: flex;
    align-items: center;
    gap: 0.75rem;
    margin-top: 0.75rem;
  }

  .actions.vertical {
    flex-direction: column;
    align-items: flex-start;
  }

  .stack {
    display: flex;
    flex-direction: column;
    gap: 0.6rem;
    min-width: 260px;
  }

  .inline {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    font-size: 0.9rem;
    color: #cbd5f5;
  }

  .status-block {
    margin-top: 0.75rem;
    white-space: pre-wrap;
    background: #0f172a;
    border: 1px solid #1f2a44;
    border-radius: 8px;
    padding: 0.75rem;
  }

  .btn {
    border: none;
    border-radius: 8px;
    padding: 0.6rem 1rem;
    font-weight: 600;
    cursor: pointer;
  }

  .btn.primary {
    background: #3b82f6;
    color: #0b1120;
  }

  .btn.secondary {
    background: #1e293b;
    color: #f8fafc;
  }

  .btn.ghost {
    background: transparent;
    color: #94a3b8;
    border: 1px solid #2b3546;
  }

  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1rem;
  }

  .output {
    min-height: 80px;
    white-space: pre-wrap;
    margin: 0;
  }

  .status {
    color: #fbbf24;
  }

  .hint {
    margin: 0.5rem 0 0;
    font-size: 0.85rem;
    color: #94a3b8;
  }
</style>
