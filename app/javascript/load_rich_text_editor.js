const EDITOR = "lexxy-editor"

export default function loadRichTextEditorOnDemand() {
  if (document.querySelector(EDITOR)) return import("lexxy")

  const observer = new MutationObserver(() => {
    if (!document.querySelector(EDITOR)) return
    observer.disconnect()
    import("lexxy")
  })
  observer.observe(document.documentElement, { childList: true, subtree: true })
}
