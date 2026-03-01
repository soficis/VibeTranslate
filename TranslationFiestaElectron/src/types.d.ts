interface TranslationFiestaBridge {
  settings: {
    load: () => Promise<{ providerId: string }>;
    setProvider: (providerId: string) => Promise<{ ok: boolean; error?: string }>;
  };
  files: {
    openFiles: (options?: { multiple?: boolean }) => Promise<{ files: Array<{ path: string; content: string }> }>;
    saveFile: (payload: { content: string; defaultPath?: string }) => Promise<{ ok: boolean; path?: string; error?: string }>;
  };
}

interface Window {
  translationFiesta?: TranslationFiestaBridge;
}
