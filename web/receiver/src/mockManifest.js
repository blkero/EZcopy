export const mockManifest = {
  app: "EZCopy",
  schemaVersion: 1,
  sessionId: "EZCopy_Mock_2026-05-19_1530",
  deviceName: "Liuyi's iPhone",
  createdAt: "2026-05-19T15:30:00+08:00",
  files: [
    {
      id: "mock-photo-001",
      originalName: "IMG_0012.HEIC",
      relativePath: "Photos/IMG_0012.HEIC",
      mediaType: "photo",
      mimeType: "image/heic",
      size: 51,
      createdAt: "2026-05-18T21:08:00+08:00",
      sourceMd5: "246ad8916afef520b2db52cf3a1f3c9f"
    },
    {
      id: "mock-video-001",
      originalName: "IMG_0014.MOV",
      relativePath: "Videos/IMG_0014.MOV",
      mediaType: "video",
      mimeType: "video/quicktime",
      size: 50,
      createdAt: "2026-05-18T21:10:03+08:00",
      sourceMd5: "8581b5e81ed580dcd912c0ca80176d14"
    }
  ]
};

export const mockFilePayloads = {
  "mock-photo-001": "EZCopy mock HEIC placeholder for foundation phase.\n",
  "mock-video-001": "EZCopy mock MOV placeholder for foundation phase.\n"
};
