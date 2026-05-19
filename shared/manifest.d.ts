export type EZCopyMediaType = "photo" | "video";

export interface EZCopyTransferManifest {
  app: "EZCopy";
  schemaVersion: number;
  sessionId: string;
  deviceName: string;
  createdAt: string;
  files: EZCopyTransferFile[];
}

export interface EZCopyTransferFile {
  id: string;
  originalName: string;
  relativePath: `Photos/${string}` | `Videos/${string}`;
  mediaType: EZCopyMediaType;
  mimeType: string;
  size: number;
  createdAt: string | null;
  sourceMd5: string | null;
}
