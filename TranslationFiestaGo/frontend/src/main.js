import './style.css'

window.__tfFrontendStarted = true

const providers = [
  { id: 'google_unofficial', label: 'Google Translate (Unofficial / Free)' }
]

const bootFallback = document.getElementById('boot-fallback')
const appRoot = document.getElementById('app')

function showBootError(message) {
  if (bootFallback) {
    bootFallback.textContent = `Startup error: ${message}`
  }
}

function getBackend() {
  if (!window || !window.go || !window.go.main || !window.go.main.App) {
    return null
  }
  return window.go.main.App
}

window.addEventListener('error', (event) => {
  showBootError(event.message || 'Unknown startup error')
})

window.addEventListener('unhandledrejection', (event) => {
  const reason = event.reason
  if (reason instanceof Error) {
    showBootError(reason.message)
    return
  }
  showBootError(String(reason))
})

function renderApp() {
  if (!appRoot) {
    throw new Error('Missing #app element')
  }

  appRoot.innerHTML = `
    <main>
      <header class="header">
        <h1>TranslationFiesta Go</h1>
        <div class="controls">
          <select id="provider"></select>
        </div>
      </header>

      <section class="panel">
        <p class="section-label">INPUT</p>
        <textarea id="input-text" placeholder="Enter text to backtranslate…"></textarea>
      </section>

      <div class="actions">
        <button id="translate-button" class="btn primary">\u29BF Backtranslate</button>
        <button id="import-button" class="btn">Import</button>
        <button id="export-button" class="btn">Save</button>
        <span id="status" class="status"></span>
      </div>

      <section class="grid">
        <div class="panel">
          <h2>INTERMEDIATE (JA)</h2>
          <p id="intermediate-output" class="output"></p>
        </div>
        <div class="panel">
          <h2>RESULT (EN)</h2>
          <p id="result-output" class="output"></p>
        </div>
      </section>
    </main>
  `
}

async function startApp() {
  renderApp()

  const providerSelect = document.getElementById('provider')
  const inputText = document.getElementById('input-text')
  const translateButton = document.getElementById('translate-button')
  const statusLabel = document.getElementById('status')
  const intermediateOutput = document.getElementById('intermediate-output')
  const resultOutput = document.getElementById('result-output')

  if (
    !(providerSelect instanceof HTMLSelectElement) ||
    !(inputText instanceof HTMLTextAreaElement) ||
    !(translateButton instanceof HTMLButtonElement) ||
    !(statusLabel instanceof HTMLSpanElement) ||
    !(intermediateOutput instanceof HTMLParagraphElement) ||
    !(resultOutput instanceof HTMLParagraphElement)
  ) {
    throw new Error('Failed to initialize UI elements')
  }

  providerSelect.innerHTML = providers
    .map((provider) => `<option value="${provider.id}">${provider.label}</option>`)
    .join('')

  const backend = getBackend()
  if (!backend) {
    statusLabel.textContent = 'Backend bridge unavailable'
  } else {
    try {
      if (typeof backend.GetProviderID === 'function') {
        const providerId = await backend.GetProviderID()
        providerSelect.value = providerId || providers[0].id
      }
    } catch (error) {
      statusLabel.textContent = error instanceof Error ? error.message : String(error)
    }
  }

  providerSelect.addEventListener('change', async () => {
    statusLabel.textContent = ''
    const selectedProviderId = providerSelect.value
    const activeBackend = getBackend()
    const providerSetter = activeBackend ? activeBackend.SetProviderID : null
    if (typeof providerSetter !== 'function') {
      return
    }
    try {
      await providerSetter(selectedProviderId)
    } catch (error) {
      statusLabel.textContent = error instanceof Error ? error.message : String(error)
    }
  })

  translateButton.addEventListener('click', async () => {
    statusLabel.textContent = ''
    const activeBackend = getBackend()
    const translator = activeBackend ? activeBackend.BackTranslate : null
    if (typeof translator !== 'function') {
      statusLabel.textContent = 'Backend bridge unavailable'
      return
    }

    try {
      const result = await translator(inputText.value)
      resultOutput.textContent = result && typeof result.result === 'string' ? result.result : ''
      intermediateOutput.textContent = result && typeof result.intermediate === 'string' ? result.intermediate : ''
    } catch (error) {
      statusLabel.textContent = error instanceof Error ? error.message : String(error)
    }
  })

  if (bootFallback) {
    bootFallback.remove()
  }
}

startApp().catch((error) => {
  const message = error instanceof Error ? error.message : String(error)
  showBootError(message)
})
