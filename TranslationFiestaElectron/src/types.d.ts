type LocalTranslateRequest = {
  text: string;
  source_lang: string;
  target_lang: string;
};

type LocalTranslateResponse = {
  translatedText?: string;
  error?: string;
};

interface LocalServiceBridge {
  health: () => Promise<{ ok: boolean; error?: string }>;
  start: () => Promise<{ started: boolean; error?: string }>;
  modelsStatus: () => Promise<any>;
  modelsVerify: () => Promise<any>;
  modelsRemove: () => Promise<any>;
  modelsInstall: (payload?: { preset?: string }) => Promise<any>;
  translate: (request: LocalTranslateRequest) => Promise<LocalTranslateResponse>;
}

interface TranslationFiestaBridge {
  settings: {
    load: () => Promise<{ providerId: string; apiKey?: string }>;
    setProvider: (providerId: string) => Promise<{ ok: boolean; error?: string }>;
    setApiKey: (apiKey: string) => Promise<{ ok: boolean; error?: string }>;
    clearApiKey: () => Promise<{ ok: boolean; error?: string }>;
  };
  localService: LocalServiceBridge;
  files: {
    openFiles: (options?: { multiple?: boolean }) => Promise<{ files: Array<{ path: string; content: string }> }>;
    saveFile: (payload: { content: string; defaultPath?: string }) => Promise<{ ok: boolean; path?: string; error?: string }>;
  };
}

interface Window {
  translationFiesta?: TranslationFiestaBridge;
}
