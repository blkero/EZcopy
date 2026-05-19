import { mockManifest, mockFilePayloads } from "./mockManifest.js";

const supportBadge = document.querySelector("#supportBadge");
const unsupportedPanel = document.querySelector("#unsupportedPanel");
const receiverPanel = document.querySelector("#receiverPanel");
const chooseFolderButton = document.querySelector("#chooseFolderButton");
const deviceName = document.querySelector("#deviceName");
const fileCount = document.querySelector("#fileCount");
const totalSize = document.querySelector("#totalSize");
const fileRows = document.querySelector("#fileRows");

const state = {
  rowsById: new Map()
};

function isDesktopChromiumBrowser() {
  const hasDirectoryPicker = "showDirectoryPicker" in window;
  const userAgent = navigator.userAgent;
  const isEdge = /\bEdg\//.test(userAgent);
  const isChrome = /\bChrome\//.test(userAgent) && !/\bOPR\//.test(userAgent) && !isEdge;
  const isMobile = /Android|iPhone|iPad|iPod/i.test(userAgent);

  return hasDirectoryPicker && !isMobile && (isChrome || isEdge);
}

function formatBytes(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  const units = ["KB", "MB", "GB", "TB"];
  let value = bytes / 1024;
  let unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }

  return `${value.toFixed(value >= 10 ? 1 : 2)} ${units[unitIndex]}`;
}

function renderManifest(manifest) {
  deviceName.textContent = manifest.deviceName;
  fileCount.textContent = String(manifest.files.length);
  totalSize.textContent = formatBytes(manifest.files.reduce((sum, file) => sum + file.size, 0));
  fileRows.textContent = "";
  state.rowsById.clear();

  for (const file of manifest.files) {
    const row = document.createElement("tr");
    row.innerHTML = `
      <td>${file.originalName}</td>
      <td>${file.mediaType}</td>
      <td>${formatBytes(file.size)}</td>
      <td><span class="status pending">Pending</span></td>
    `;
    fileRows.append(row);
    state.rowsById.set(file.id, row);
  }
}

function setFileStatus(fileId, label, variant) {
  const row = state.rowsById.get(fileId);
  const status = row?.querySelector(".status");
  if (!status) return;

  status.className = `status ${variant}`;
  status.textContent = label;
}

async function getOrCreateDirectory(parent, name) {
  return parent.getDirectoryHandle(name, { create: true });
}

async function writeTextFile(directoryHandle, name, content, mimeType = "text/plain") {
  const fileHandle = await directoryHandle.getFileHandle(name, { create: true });
  const writable = await fileHandle.createWritable();
  await writable.write(new Blob([content], { type: mimeType }));
  await writable.close();
}

async function writeMockMediaFile(rootHandle, file) {
  setFileStatus(file.id, "Writing", "active");

  const [directoryName, fileName] = file.relativePath.split("/");
  const directory = await getOrCreateDirectory(rootHandle, directoryName);
  const fileHandle = await directory.getFileHandle(fileName, { create: true });
  const writable = await fileHandle.createWritable();
  const payload = mockFilePayloads[file.id] ?? "";

  await writable.write(new Blob([payload], { type: file.mimeType }));
  await writable.close();

  setFileStatus(file.id, "Mock copied", "success");
}

function buildReportHtml(manifest) {
  const rows = manifest.files.map((file) => `
    <tr>
      <td>${file.relativePath}</td>
      <td>${file.mediaType}</td>
      <td>${formatBytes(file.size)}</td>
      <td>${file.sourceMd5 ?? "mock-pending"}</td>
      <td>Mock copied</td>
    </tr>
  `).join("");

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>EZCopy Mock Transfer Report</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 32px; color: #172026; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border-bottom: 1px solid #d8dee4; padding: 10px; text-align: left; }
  </style>
</head>
<body>
  <h1>EZCopy Mock Transfer Report</h1>
  <p>Device: ${manifest.deviceName}</p>
  <p>Session: ${manifest.sessionId}</p>
  <p>Files: ${manifest.files.length}</p>
  <table>
    <thead>
      <tr>
        <th>Path</th>
        <th>Type</th>
        <th>Size</th>
        <th>Source MD5</th>
        <th>Status</th>
      </tr>
    </thead>
    <tbody>${rows}</tbody>
  </table>
</body>
</html>`;
}

function buildChecksums(manifest) {
  return manifest.files
    .map((file) => `${file.sourceMd5 ?? "00000000000000000000000000000000"}  ${file.relativePath}`)
    .join("\n") + "\n";
}

async function runMockCopy() {
  chooseFolderButton.disabled = true;
  chooseFolderButton.textContent = "Choose a destination folder...";

  try {
    const destinationHandle = await window.showDirectoryPicker({ mode: "readwrite" });
    const sessionHandle = await getOrCreateDirectory(destinationHandle, mockManifest.sessionId);
    await getOrCreateDirectory(sessionHandle, "Photos");
    await getOrCreateDirectory(sessionHandle, "Videos");

    chooseFolderButton.textContent = "Writing mock files...";

    for (const file of mockManifest.files) {
      await writeMockMediaFile(sessionHandle, file);
    }

    await writeTextFile(
      sessionHandle,
      "EZCopy_Manifest.json",
      JSON.stringify(mockManifest, null, 2),
      "application/json"
    );
    await writeTextFile(sessionHandle, "EZCopy_Checksums.md5", buildChecksums(mockManifest));
    await writeTextFile(sessionHandle, "EZCopy_Report.html", buildReportHtml(mockManifest), "text/html");

    chooseFolderButton.textContent = "Mock copy complete";
  } catch (error) {
    console.error(error);
    chooseFolderButton.disabled = false;
    chooseFolderButton.textContent = "Choose Folder and Run Mock Copy";
  }
}

function boot() {
  const supported = isDesktopChromiumBrowser();
  supportBadge.textContent = supported ? "Supported" : "Unsupported";
  supportBadge.classList.toggle("success", supported);
  supportBadge.classList.toggle("error", !supported);
  unsupportedPanel.classList.toggle("hidden", supported);
  receiverPanel.classList.toggle("hidden", !supported);
  chooseFolderButton.addEventListener("click", runMockCopy);
  renderManifest(mockManifest);
}

boot();
