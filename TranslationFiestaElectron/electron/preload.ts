import { contextBridge, ipcRenderer } from "electron";

contextBridge.exposeInMainWorld("translationFiesta", {
  settings: {
    load: () => ipcRenderer.invoke("settings-load"),
    setProvider: (providerId: string) => ipcRenderer.invoke("settings-set-provider", { providerId }),
    setApiKey: (apiKey: string) => ipcRenderer.invoke("settings-set-api-key", { apiKey }),
    clearApiKey: () => ipcRenderer.invoke("settings-clear-api-key")
  },
  localService: {
    health: () => ipcRenderer.invoke("local-health"),
    start: () => ipcRenderer.invoke("local-start"),
    modelsStatus: () => ipcRenderer.invoke("local-models-status"),
    modelsVerify: () => ipcRenderer.invoke("local-models-verify"),
    modelsRemove: () => ipcRenderer.invoke("local-models-remove"),
    modelsInstall: (payload?: { preset?: string }) => ipcRenderer.invoke("local-models-install", payload),
    translate: (payload: { text: string; source_lang: string; target_lang: string }) =>
      ipcRenderer.invoke("local-translate", payload)
  },
  files: {
    openFiles: (options?: { multiple?: boolean }) => ipcRenderer.invoke("files-open", options),
    saveFile: (payload: { content: string; defaultPath?: string }) => ipcRenderer.invoke("files-save", payload)
  }
});
