import { contextBridge, ipcRenderer } from "electron";

contextBridge.exposeInMainWorld("translationFiesta", {
  settings: {
    load: () => ipcRenderer.invoke("settings-load"),
    setProvider: (providerId: string) => ipcRenderer.invoke("settings-set-provider", { providerId })
  },
  files: {
    openFiles: (options?: { multiple?: boolean }) => ipcRenderer.invoke("files-open", options),
    saveFile: (payload: { content: string; defaultPath?: string }) => ipcRenderer.invoke("files-save", payload)
  }
});
