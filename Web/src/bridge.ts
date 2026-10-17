export interface EditorSettings {
  language: 'en' | 'zh-CN'
  theme: string; surface: string; text: string; muted: string; accent: string;
  font: string; fontSize: number; lineHeight: number; pageWidth: number;
  paperOpacity: number; spellcheck: boolean; showLineNumbers: boolean;
  focusMode: boolean; typewriterMode: boolean; customCSS: string
}

export interface DocumentPayload {
  id: string; markdown: string; directory: string; mode: 'rich' | 'source' | 'split'; settings: EditorSettings; startsInBody?: boolean
}

export type NativeMessage =
  | { type: 'ready' }
  | { type: 'change'; id: string; markdown: string }
  | { type: 'openURL'; url: string }
  | { type: 'openArticle'; path: string }
  | { type: 'asset'; id: string; data: string; name: string }
  | { type: 'unsupported' }
  | { type: 'action'; name: string }
  | { type: 'error' }

declare global {
  interface Window {
    webkit?: { messageHandlers: { mori: { postMessage: (message: NativeMessage) => void } } }
    Mori: {
      load: (payload: DocumentPayload) => void
      configure: (payload: Pick<DocumentPayload, 'mode' | 'settings'>) => void
      command: (name: string, payload?: Record<string, unknown>) => void
      flush: () => { id: string; markdown: string }
      exportHTML: (documentID: string) => Promise<string | null>
      metadata: (documentID: string) => Record<string, unknown> | null
    }
  }
}

export function post(message: NativeMessage): void { window.webkit?.messageHandlers.mori.postMessage(message) }
