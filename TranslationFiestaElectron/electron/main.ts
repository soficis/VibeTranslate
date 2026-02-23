import { app, BrowserWindow, ipcMain, safeStorage, dialog } from "electron";
import { spawn } from "child_process";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const defaultBaseUrl = "http://127.0.0.1:5055";
const defaultScriptPath = "TranslationFiestaLocal/local_service.py";
let localServiceStarted = false;

type ProviderId = "local" | "google_unofficial" | "google_official";
type SettingsData = { providerId: ProviderId; apiKeyEncrypted?: string };

const defaultSettings: SettingsData = { providerId: "google_unofficial" };

const getSettingsPath = () => path.join(app.getPath("userData"), "settings.json");

const readSettings = (): SettingsData => {
  try {
    const raw = fs.readFileSync(getSettingsPath(), "utf-8");
    const parsed = JSON.parse(raw) as Partial<SettingsData>;
    const providerId = (parsed.providerId ?? defaultSettings.providerId) as ProviderId;
    return {
      providerId,
      apiKeyEncrypted: parsed.apiKeyEncrypted
    };
  } catch {
    return { ...defaultSettings };
  }
};

const writeSettings = (settings: SettingsData) => {
  fs.mkdirSync(app.getPath("userData"), { recursive: true });
  fs.writeFileSync(getSettingsPath(), JSON.stringify(settings, null, 2), "utf-8");
};

const decryptApiKey = (settings: SettingsData) => {
  if (!settings.apiKeyEncrypted) return "";
  try {
    const buffer = Buffer.from(settings.apiKeyEncrypted, "base64");
    if (!safeStorage.isEncryptionAvailable()) return "";
    return safeStorage.decryptString(buffer);
  } catch {
    return "";
  }
};

const encryptApiKey = (apiKey: string) => {
  if (!apiKey) return undefined;
  if (!safeStorage.isEncryptionAvailable()) return undefined;
  const encrypted = safeStorage.encryptString(apiKey);
  return encrypted.toString("base64");
};

const getBaseUrl = () => {
  const raw = process.env.TF_LOCAL_URL?.trim();
  return (raw && raw.length > 0 ? raw : defaultBaseUrl).replace(/\/+$/, "");
};

const isAutoStartEnabled = () => {
  const raw = process.env.TF_LOCAL_AUTOSTART?.trim().toLowerCase();
  if (!raw) return true;
  return raw !== "0" && raw !== "false" && raw !== "no";
};

const startLocalService = () => {
  if (localServiceStarted) {
    return;
  }
  const scriptPath = process.env.TF_LOCAL_SCRIPT?.trim() || defaultScriptPath;
  const python = process.env.PYTHON?.trim() || "python";
  const child = spawn(python, [scriptPath, "serve"], {
    cwd: path.dirname(scriptPath),
    detached: true,
    stdio: "ignore"
  });
  child.unref();
  localServiceStarted = true;
};

const checkLocalHealth = async () => {
  const baseUrl = getBaseUrl();
  const response = await fetch(`${baseUrl}/health`);
  if (!response.ok) {
    throw new Error(`Local service HTTP ${response.status}`);
  }
  const body = (await response.json()) as { status?: string };
  if (body.status?.toLowerCase() !== "ok") {
    throw new Error("Local service not ready");
  }
  return true;
};

const ensureLocalService = async () => {
  try {
    await checkLocalHealth();
    return;
  } catch {
    if (!isAutoStartEnabled()) {
      throw new Error("Local service unavailable and autostart disabled");
    }
    startLocalService();
    for (let attempt = 0; attempt < 10; attempt += 1) {
      try {
        await checkLocalHealth();
        return;
      } catch {
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
    }
    throw new Error("Local service did not become healthy");
  }
};

const createWindow = () => {
  const win = new BrowserWindow({
    width: 1100,
    height: 800,
    backgroundColor: "#0f172a",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  const devUrl = process.env.VITE_DEV_SERVER_URL;
  if (devUrl) {
    win.loadURL(devUrl);
  } else {
    const indexPath = path.join(__dirname, "..", "dist", "index.html");
    win.loadFile(indexPath);
  }
};

app.whenReady().then(() => {
  createWindow();

  ipcMain.handle("settings-load", async () => {
    const settings = readSettings();
    return {
      providerId: settings.providerId,
      apiKey: decryptApiKey(settings) || undefined
    };
  });

  ipcMain.handle("settings-set-provider", async (_event, payload: { providerId: ProviderId }) => {
    try {
      const settings = readSettings();
      settings.providerId = payload.providerId;
      writeSettings(settings);
      return { ok: true };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Failed to save provider";
      return { ok: false, error: message };
    }
  });

  ipcMain.handle("settings-set-api-key", async (_event, payload: { apiKey: string }) => {
    try {
      const settings = readSettings();
      settings.apiKeyEncrypted = encryptApiKey(payload.apiKey);
      writeSettings(settings);
      return { ok: true };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Failed to save API key";
      return { ok: false, error: message };
    }
  });

  ipcMain.handle("settings-clear-api-key", async () => {
    try {
      const settings = readSettings();
      delete settings.apiKeyEncrypted;
      writeSettings(settings);
      return { ok: true };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Failed to clear API key";
      return { ok: false, error: message };
    }
  });

  ipcMain.handle("local-health", async () => {
    try {
      await checkLocalHealth();
      return { ok: true };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Health check failed";
      return { ok: false, error: message };
    }
  });

  ipcMain.handle("local-start", async () => {
    try {
      startLocalService();
      return { started: true };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Failed to start local service";
      return { started: false, error: message };
    }
  });

  ipcMain.handle("local-translate", async (_event, payload: { text: string; source_lang: string; target_lang: string }) => {
    try {
      await ensureLocalService();
      const baseUrl = getBaseUrl();
      const response = await fetch(`${baseUrl}/translate`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload)
      });
      if (!response.ok) {
        return { error: `Local service HTTP ${response.status}` };
      }
      const data = (await response.json()) as { translated_text?: string; error?: { message?: string } };
      if (data.error?.message) {
        return { error: data.error.message };
      }
      return { translatedText: data.translated_text ?? "" };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Local translation failed";
      return { error: message };
    }
  });

  ipcMain.handle("local-models-status", async () => {
    try {
      await ensureLocalService();
      const baseUrl = getBaseUrl();
      const response = await fetch(`${baseUrl}/models`);
      return await response.json();
    } catch (error) {
      const message = error instanceof Error ? error.message : "Failed to read models status";
      return { error: { code: "network_error", message } };
    }
  });

  ipcMain.handle("local-models-verify", async () => {
    try {
      await ensureLocalService();
      const baseUrl = getBaseUrl();
      const response = await fetch(`${baseUrl}/models/verify`, { method: "POST" });
      return await response.json();
    } catch (error) {
      const message = error instanceof Error ? error.message : "Failed to verify models";
      return { error: { code: "network_error", message } };
    }
  });

  ipcMain.handle("local-models-remove", async () => {
    try {
      await ensureLocalService();
      const baseUrl = getBaseUrl();
      const response = await fetch(`${baseUrl}/models/remove`, { method: "POST" });
      return await response.json();
    } catch (error) {
      const message = error instanceof Error ? error.message : "Failed to remove models";
      return { error: { code: "network_error", message } };
    }
  });

  ipcMain.handle("local-models-install", async (_event, payload: { preset?: string } = {}) => {
    try {
      await ensureLocalService();
      const baseUrl = getBaseUrl();
      const response = await fetch(`${baseUrl}/models/install`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload ?? {})
      });
      return await response.json();
    } catch (error) {
      const message = error instanceof Error ? error.message : "Failed to install models";
      return { error: { code: "network_error", message } };
    }
  });

  ipcMain.handle("files-open", async (_event, payload: { multiple?: boolean } = {}) => {
    const result = await dialog.showOpenDialog({
      properties: payload.multiple ? ["openFile", "multiSelections"] : ["openFile"],
      filters: [
        { name: "Text", extensions: ["txt", "md", "html"] },
        { name: "All Files", extensions: ["*"] }
      ]
    });
    if (result.canceled || result.filePaths.length === 0) {
      return { files: [] as Array<{ path: string; content: string }> };
    }
    const files = result.filePaths.map((filePath) => ({
      path: filePath,
      content: fs.readFileSync(filePath, "utf-8")
    }));
    return { files };
  });

  ipcMain.handle("files-save", async (_event, payload: { content: string; defaultPath?: string }) => {
    try {
      const result = await dialog.showSaveDialog({
        defaultPath: payload.defaultPath,
        filters: [
          { name: "Text", extensions: ["txt", "md", "html"] },
          { name: "All Files", extensions: ["*"] }
        ]
      });
      if (result.canceled || !result.filePath) {
        return { ok: false, error: "Save cancelled" };
      }
      fs.writeFileSync(result.filePath, payload.content ?? "", "utf-8");
      return { ok: true, path: result.filePath };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Failed to save file";
      return { ok: false, error: message };
    }
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
