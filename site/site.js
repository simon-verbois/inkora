/* Screenshot links remain usable when JavaScript is unavailable. */
const dialog = document.querySelector("#preview");
const image = document.querySelector("#preview-image");
const caption = document.querySelector("#preview-caption");
let opener;
if (typeof dialog?.showModal === "function") {
  document.querySelectorAll("[data-preview]").forEach((link) => {
    link.addEventListener("click", (event) => {
      if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey)
        return;
      event.preventDefault();
      opener = link;
      const thumbnail = link.querySelector("img");
      image.src = link.href;
      image.alt = thumbnail.alt;
      caption.textContent = thumbnail.alt;
      dialog.showModal();
    });
  });
  dialog
    .querySelector("button")
    .addEventListener("click", () => dialog.close());
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) {
      const bounds = dialog.getBoundingClientRect();
      if (
        event.clientX < bounds.left ||
        event.clientX > bounds.right ||
        event.clientY < bounds.top ||
        event.clientY > bounds.bottom
      )
        dialog.close();
    }
  });
  dialog.addEventListener("close", () => {
    image.removeAttribute("src");
    opener?.focus({ preventScroll: true });
  });
}
