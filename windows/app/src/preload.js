const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("dreamSkin", {
  load: () => ipcRenderer.invoke("studio:load"),
  chooseBackground: () => ipcRenderer.invoke("studio:choose-background"),
  chooseAvatar: (role) => ipcRenderer.invoke("studio:choose-avatar", role),
  save: (draft, applyImmediately) => ipcRenderer.invoke("studio:save", draft, applyImmediately),
  apply: () => ipcRenderer.invoke("studio:apply"),
  openFolder: (kind) => ipcRenderer.invoke("studio:open-folder", kind),
});
