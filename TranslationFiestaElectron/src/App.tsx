import React, { useCallback, useEffect, useRef, useState } from "react";
import { translateUnofficialGoogle } from "./providers/googleUnofficial";
import { translateOfficialGoogle } from "./providers/googleOfficial";
import { translateLocal } from "./providers/local";
import * as tm from "./translationMemory";

type ProviderId = "local" | "google_unofficial" | "google_official";

const providerOptions: { id: ProviderId; label: string }[] = [
  { id: "local", label: "Local (Offline)" },
  { id: "google_unofficial", label: "Google Translate (Unofficial / Free)" },
  { id: "google_official", label: "Google Cloud Translate (Official)" }
];

const translateWithProvider = async (
  providerId: ProviderId,
  text: string,
  source: string,
  target: string,
  apiKey: string,
  signal?: AbortSignal
) => {
  switch (providerId) {
    case "local":
      return translateLocal(text, source, target, { signal });
    case "google_official":
      return translateOfficialGoogle(text, source, target, apiKey, { signal });
    default:
      return translateUnofficialGoogle(text, source, target, { signal });
  }
};

const App: React.FC = () => {
  const [providerId, setProviderId] = useState<ProviderId>("google_unofficial");
  const [apiKey, setApiKey] = useState("");
  const [savedApiKey, setSavedApiKey] = useState("");
  const [inputText, setInputText] = useState("");
  const [intermediateText, setIntermediateText] = useState("");
  const [outputText, setOutputText] = useState("");
  const [status, setStatus] = useState("Ready");
  const [isBusy, setIsBusy] = useState(false);
  const [localModelsStatus, setLocalModelsStatus] = useState<any>(null);
  const [batchFiles, setBatchFiles] = useState<Array<{ path: string; content: string }>>([]);
  const [batchResults, setBatchResults] = useState<
    Array<{ path: string; intermediate: string; output: string }>
  >([]);
  const [batchProgress, setBatchProgress] = useState<{ done: number; total: number } | null>(null);
  const [batchStatus, setBatchStatus] = useState("");
  const abortRef = useRef<AbortController | null>(null);
  const batchAbortRef = useRef<AbortController | null>(null);
  const runIdRef = useRef(0);

  useEffect(() => {
    const load = async () => {
      const bridge = window.translationFiesta?.settings;
      if (bridge) {
        const settings = await bridge.load();
        if (providerOptions.some((option) => option.id === settings.providerId)) {
          setProviderId(settings.providerId as ProviderId);
        }
        if (settings.apiKey) {
          setApiKey(settings.apiKey);
          setSavedApiKey(settings.apiKey);
        }
        return;
      }
      const savedProvider = localStorage.getItem("tf_provider") as ProviderId | null;
      if (savedProvider && providerOptions.some((option) => option.id === savedProvider)) {
        setProviderId(savedProvider);
      }
    };
    void load();
  }, []);

  useEffect(() => {
    const bridge = window.translationFiesta?.settings;
    if (bridge) {
      void bridge.setProvider(providerId);
    } else {
      localStorage.setItem("tf_provider", providerId);
    }
  }, [providerId]);

  const refreshLocalModels = useCallback(async () => {
    if (!window.translationFiesta?.localService?.modelsStatus) return;
    const data = await window.translationFiesta.localService.modelsStatus();
    setLocalModelsStatus(data);
  }, []);

  useEffect(() => {
    if (providerId !== "local") return;
    void refreshLocalModels();
  }, [providerId, refreshLocalModels]);

  const handleSaveApiKey = useCallback(async () => {
    if (!window.translationFiesta?.settings) {
      setSavedApiKey(apiKey);
      return;
    }
    const result = await window.translationFiesta.settings.setApiKey(apiKey);
    if (!result.ok) {
      setStatus(result.error ?? "Failed to save API key");
      return;
    }
    setSavedApiKey(apiKey);
    setStatus("API key saved");
  }, [apiKey]);

  const handleClearApiKey = useCallback(async () => {
    setApiKey("");
    setSavedApiKey("");
    if (!window.translationFiesta?.settings) return;
    const result = await window.translationFiesta.settings.clearApiKey();
    if (!result.ok) {
      setStatus(result.error ?? "Failed to clear API key");
    } else {
      setStatus("API key cleared");
    }
  }, []);

  const handleCancel = useCallback(() => {
    abortRef.current?.abort();
    abortRef.current = null;
    setIsBusy(false);
    setStatus("Cancelled");
  }, []);

  const handleImportFile = useCallback(async () => {
    if (!window.translationFiesta?.files) return;
    const response = await window.translationFiesta.files.openFiles({ multiple: false });
    const file = response.files[0];
    if (!file) return;
    setInputText(file.content);
    setStatus(`Loaded ${file.path}`);
  }, []);

  const handleExportOutput = useCallback(async () => {
    if (!window.translationFiesta?.files) return;
    const content = outputText || intermediateText || "";
    if (!content.trim()) {
      setStatus("Nothing to export");
      return;
    }
    const result = await window.translationFiesta.files.saveFile({ content, defaultPath: "translation.txt" });
    if (!result.ok) {
      setStatus(result.error ?? "Failed to export");
    } else {
      setStatus(`Saved to ${result.path}`);
    }
  }, [intermediateText, outputText]);

  const handleBatchSelect = useCallback(async () => {
    if (!window.translationFiesta?.files) return;
    const response = await window.translationFiesta.files.openFiles({ multiple: true });
    setBatchFiles(response.files ?? []);
    setBatchResults([]);
    setBatchProgress(null);
    if (response.files.length > 0) {
      setBatchStatus(`${response.files.length} files selected`);
    }
  }, []);

  const handleBatchCancel = useCallback(() => {
    batchAbortRef.current?.abort();
    batchAbortRef.current = null;
    setBatchStatus("Batch cancelled");
  }, []);

  const handleBatchRun = useCallback(async () => {
    if (!batchFiles.length) {
      setBatchStatus("Select files first");
      return;
    }
    batchAbortRef.current?.abort();
    batchAbortRef.current = new AbortController();
    setBatchResults([]);
    setBatchProgress({ done: 0, total: batchFiles.length });
    setBatchStatus("Processing batch...");

    const results: Array<{ path: string; intermediate: string; output: string }> = [];
    for (const file of batchFiles) {
      if (batchAbortRef.current?.signal.aborted) break;
      try {
        const forward = await translateWithProvider(
          providerId,
          file.content,
          "en",
          "ja",
          apiKey,
          batchAbortRef.current?.signal
        );
        const back = await translateWithProvider(
          providerId,
          forward,
          "ja",
          "en",
          apiKey,
          batchAbortRef.current?.signal
        );
        results.push({ path: file.path, intermediate: forward, output: back });
      } catch (error) {
        const message = error instanceof Error ? error.message : "Translation failed";
        results.push({ path: file.path, intermediate: "", output: message });
      }
      setBatchProgress((prev) =>
        prev ? { done: Math.min(prev.done + 1, prev.total), total: prev.total } : prev
      );
    }

    setBatchResults(results);
    setBatchStatus(batchAbortRef.current?.signal.aborted ? "Batch cancelled" : "Batch completed");
  }, [apiKey, batchFiles, providerId]);

  const handleBatchExport = useCallback(async () => {
    if (!window.translationFiesta?.files) return;
    if (!batchResults.length) {
      setBatchStatus("No batch results to export");
      return;
    }
    const content = batchResults
      .map(
        (item) =>
          `File: ${item.path}\nIntermediate:\n${item.intermediate}\nResult:\n${item.output}\n---\n`
      )
      .join("\n");
    const result = await window.translationFiesta.files.saveFile({
      content,
      defaultPath: "batch_results.txt"
    });
    if (!result.ok) {
      setBatchStatus(result.error ?? "Failed to export batch");
    } else {
      setBatchStatus(`Batch saved to ${result.path}`);
    }
  }, [batchResults]);

  const handleVerifyModels = useCallback(async () => {
    if (!window.translationFiesta?.localService?.modelsVerify) return;
    const data = await window.translationFiesta.localService.modelsVerify();
    setLocalModelsStatus(data);
  }, []);

  const handleRemoveModels = useCallback(async () => {
    if (!window.translationFiesta?.localService?.modelsRemove) return;
    const data = await window.translationFiesta.localService.modelsRemove();
    setLocalModelsStatus(data);
  }, []);

  const handleInstallModels = useCallback(async () => {
    if (!window.translationFiesta?.localService?.modelsInstall) return;
    const data = await window.translationFiesta.localService.modelsInstall({ preset: "elanmt-tiny-int8" });
    setLocalModelsStatus(data);
  }, []);

  const handleBacktranslate = useCallback(async () => {
    if (!inputText.trim()) {
      setStatus("Enter text to translate");
      return;
    }

    runIdRef.current += 1;
    const runId = runIdRef.current;

    setIsBusy(true);
    abortRef.current?.abort();
    abortRef.current = new AbortController();
    setStatus("Translating to Japanese...");
    try {
      const cachedForward = tm.lookup(providerId, "en", "ja", inputText);
      const forward =
        cachedForward ?? (await translateWithProvider(providerId, inputText, "en", "ja", apiKey, abortRef.current.signal));
      if (!cachedForward) tm.store(providerId, "en", "ja", inputText, forward);
      if (runId !== runIdRef.current) return;
      setIntermediateText(forward);
      setStatus("Translating back to English...");
      const cachedBack = tm.lookup(providerId, "ja", "en", forward);
      const back =
        cachedBack ?? (await translateWithProvider(providerId, forward, "ja", "en", apiKey, abortRef.current.signal));
      if (!cachedBack) tm.store(providerId, "ja", "en", forward, back);
      if (runId !== runIdRef.current) return;
      setOutputText(back);
      setStatus("Done");
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        setStatus("Cancelled");
      } else {
        const message = error instanceof Error ? error.message : "Translation failed";
        setStatus(message);
      }
    } finally {
      setIsBusy(false);
    }
  }, [apiKey, inputText, providerId]);

  return (
    <div className="app">
      <header className="header">
        <div>
          <h1>TranslationFiestaElectron</h1>
          <p>Backtranslation EN -&gt; JA -&gt; EN</p>
        </div>
        <div className="provider">
          <label htmlFor="provider">Provider</label>
          <select
            id="provider"
            value={providerId}
            onChange={(event) => setProviderId(event.target.value as ProviderId)}
          >
            {providerOptions.map((option) => (
              <option key={option.id} value={option.id}>
                {option.label}
              </option>
            ))}
          </select>
        </div>
      </header>

      <section className="panel">
        <label htmlFor="apiKey">API key (official only)</label>
        <div className="actions">
          <input
            id="apiKey"
            type="password"
            value={apiKey}
            onChange={(event) => setApiKey(event.target.value)}
            disabled={providerId !== "google_official"}
            placeholder={providerId === "google_official" ? "Enter API key" : "Not required"}
          />
          <button onClick={handleSaveApiKey} disabled={providerId !== "google_official" || apiKey === savedApiKey}>
            Save
          </button>
          <button onClick={handleClearApiKey} disabled={providerId !== "google_official" || (!apiKey && !savedApiKey)}>
            Clear
          </button>
        </div>
      </section>

      {providerId === "local" && (
        <section className="panel">
          <h2>Local Model Status</h2>
          <pre>{localModelsStatus ? JSON.stringify(localModelsStatus, null, 2) : "Loading..."}</pre>
          <div className="actions">
            <button onClick={handleInstallModels} disabled={isBusy}>
              Install Default
            </button>
            <button onClick={refreshLocalModels} disabled={isBusy}>
              Refresh
            </button>
            <button onClick={handleVerifyModels} disabled={isBusy}>
              Verify
            </button>
            <button onClick={handleRemoveModels} disabled={isBusy}>
              Remove
            </button>
          </div>
        </section>
      )}

      <section className="panel">
        <label htmlFor="input">Input</label>
        <textarea
          id="input"
          value={inputText}
          onChange={(event) => setInputText(event.target.value)}
          placeholder="Enter text to backtranslate..."
        />
        <div className="actions">
          <button onClick={handleBacktranslate} disabled={isBusy}>
            {isBusy ? "Working..." : "Backtranslate"}
          </button>
          <button onClick={handleImportFile} disabled={isBusy}>
            Import
          </button>
          <button onClick={handleExportOutput} disabled={isBusy}>
            Export
          </button>
          <button onClick={handleCancel} disabled={!isBusy}>
            Cancel
          </button>
          <span className="status">{status}</span>
        </div>
      </section>

      <section className="panel">
        <h2>Batch Processing</h2>
        <div className="actions">
          <button onClick={handleBatchSelect} disabled={isBusy}>
            Select Files
          </button>
          <button onClick={handleBatchRun} disabled={isBusy || batchFiles.length === 0}>
            Run Batch
          </button>
          <button onClick={handleBatchCancel} disabled={!batchProgress}>
            Cancel
          </button>
          <button onClick={handleBatchExport} disabled={!batchResults.length}>
            Export Batch
          </button>
        </div>
        {batchProgress && (
          <p className="status">
            {batchProgress.done}/{batchProgress.total} processed
          </p>
        )}
        {batchStatus && <p className="status">{batchStatus}</p>}
        {batchResults.length > 0 && (
          <div className="batch-results">
            {batchResults.map((item) => (
              <div key={item.path} className="batch-item">
                <strong>{item.path}</strong>
                <pre>{item.output}</pre>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="grid">
        <div className="panel">
          <h2>Intermediate (JA)</h2>
          <pre>{intermediateText}</pre>
        </div>
        <div className="panel">
          <h2>Result (EN)</h2>
          <pre>{outputText}</pre>
        </div>
      </section>
    </div>
  );
};

export default App;
