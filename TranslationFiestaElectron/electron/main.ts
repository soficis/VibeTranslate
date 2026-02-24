import { app, BrowserWindow, dialog, ipcMain } from "electron";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

type ProviderId = "google_unofficial";
type SettingsData = { providerId: ProviderId };

const defaultSettings: SettingsData = { providerId: "google_unofficial" };

const getSettingsPath = () => path.join(app.getPath("userData"), "settings.json");

const readSettings = (): SettingsData => {
  try {
    const raw = fs.readFileSync(getSettingsPath(), "utf-8");
    const parsed = JSON.parse(raw) as Partial<SettingsData>;
    const providerId = parsed.providerId === "google_unofficial" ? parsed.providerId : defaultSettings.providerId;
    return { providerId };
  } catch {
    return { ...defaultSettings };
  }
};

const writeSettings = (settings: SettingsData) => {
  fs.mkdirSync(app.getPath("userData"), { recursive: true });
  fs.writeFileSync(getSettingsPath(), JSON.stringify(settings, null, 2), "utf-8");
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
    return { providerId: settings.providerId };
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
