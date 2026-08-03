(function () {
  var pageUrl = window.location.href.split("#")[0];
  var title =
    document.querySelector('meta[property="og:title"]')?.content ||
    document.title;
  var text =
    document.querySelector('meta[property="og:description"]')?.content ||
    title;
  var encodedUrl = encodeURIComponent(pageUrl);
  var encodedText = encodeURIComponent(text);
  var encodedTitle = encodeURIComponent(title);

  var urls = {
    facebook: "https://www.facebook.com/sharer/sharer.php?u=" + encodedUrl,
    x: "https://twitter.com/intent/tweet?url=" + encodedUrl + "&text=" + encodedTitle,
    whatsapp: "https://wa.me/?text=" + encodeURIComponent(title + "\n" + pageUrl),
    telegram: "https://t.me/share/url?url=" + encodedUrl + "&text=" + encodedTitle,
    linkedin: "https://www.linkedin.com/sharing/share-offsite/?url=" + encodedUrl,
  };

  var statusEl = document.getElementById("share-status");
  function setStatus(msg) {
    if (statusEl) statusEl.textContent = msg || "";
  }

  var nativeBtn = document.getElementById("share-native");
  if (nativeBtn && navigator.share) {
    nativeBtn.hidden = false;
  }

  document.querySelectorAll("[data-share]").forEach(function (el) {
    el.addEventListener("click", function (ev) {
      var kind = el.getAttribute("data-share");
      if (kind === "copy") {
        ev.preventDefault();
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(pageUrl).then(
            function () {
              setStatus("Link copiato / Link copied");
            },
            function () {
              setStatus("Copia non riuscita");
            }
          );
        } else {
          setStatus(pageUrl);
        }
        return;
      }
      if (kind === "native") {
        ev.preventDefault();
        navigator
          .share({ title: title, text: text, url: pageUrl })
          .catch(function () {});
        return;
      }
      if (urls[kind]) {
        ev.preventDefault();
        window.open(urls[kind], "_blank", "noopener,noreferrer,width=640,height=480");
      }
    });
  });

  // Prefill href for no-JS / middle-click
  document.querySelectorAll("a[data-share]").forEach(function (a) {
    var kind = a.getAttribute("data-share");
    if (urls[kind]) a.href = urls[kind];
  });
})();
